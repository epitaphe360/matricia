import { createHash, randomBytes, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import postgres from "postgres";
import { parseEnv, resolveExpectedDatabaseUrl } from "./p05-e2e/environment.mjs";

const root = resolve(import.meta.dirname, "..");
const requireFromWeb = createRequire(resolve(root, "apps", "web", "package.json"));
const { createClient } = requireFromWeb("@supabase/supabase-js");

function required(value, name) {
  if (typeof value !== "string" || value.trim() === "") throw new Error(`${name} is required`);
  return value.trim();
}

function deterministicUuid(seed) {
  const value = createHash("sha256").update(seed).digest("hex").slice(0, 32).split("");
  value[12] = "4";
  value[16] = ((Number.parseInt(value[16], 16) & 3) | 8).toString(16);
  return `${value.slice(0, 8).join("")}-${value.slice(8, 12).join("")}-${value.slice(12, 16).join("")}-${value.slice(16, 20).join("")}-${value.slice(20).join("")}`;
}

function aliasEmail(baseEmail, section) {
  const match = baseEmail.toLowerCase().match(/^([^@+]+)(?:\+[^@]*)?@gmail\.com$/);
  if (!match) throw new Error("MATRICIA_VALIDATION_EMAIL must be a Gmail address so aliases reach the same controlled inbox");
  return `${match[1]}+matricia-${section}@gmail.com`;
}

function password() {
  return `${randomBytes(24).toString("base64url")}aA7!`;
}

async function checked(operation, message) {
  const result = await operation;
  if (result.error) {
    const status = typeof result.error.status === "number" ? ` status=${result.error.status}` : "";
    const code = typeof result.error.code === "string" && /^[A-Z0-9_-]{1,80}$/i.test(result.error.code) ? ` code=${result.error.code}` : "";
    throw new Error(`${message}${status}${code}`);
  }
  return result.data;
}

async function findUser(admin, database, email) {
  const rows = await database`select id from auth.users where lower(email)=lower(${email}) limit 1`;
  if (rows.length === 0) return null;
  const data = await checked(admin.auth.admin.getUserById(rows[0].id), "Unable to inspect a validation identity");
  return data.user;
}

async function upsertUser(admin, database, section, email, secret) {
  const metadata = { full_name: `Matricia Validation ${section}`, preferred_locale: "fr-MA" };
  const appMetadata = { matricia_validation_access: true, access_section: section };
  const existing = await findUser(admin, database, email);
  if (existing) {
    const data = await checked(admin.auth.admin.updateUserById(existing.id, {
      password: secret,
      email_confirm: true,
      user_metadata: metadata,
      app_metadata: { ...existing.app_metadata, ...appMetadata },
    }), "Unable to update a validation identity");
    return data.user;
  }
  const data = await checked(admin.auth.admin.createUser({
    email,
    password: secret,
    email_confirm: true,
    user_metadata: metadata,
    app_metadata: appMetadata,
  }), "Unable to create a validation identity");
  return data.user;
}

async function recordProvisioning(database, userId, organizationId, section) {
  const correlationId = deterministicUuid(`validation-access:${userId}:${section}`);
  const existingAudit = await database`select id from public.audit_events where correlation_id=${correlationId}::uuid limit 1`;
  if (existingAudit.length === 0) {
    await database`insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,event_hash)
      values(${organizationId}::uuid,${userId}::uuid,'SYSTEM','identity.validation_access.provisioned','auth_user',${userId},${correlationId}::uuid,
      ${database.json({ section, environment: "development-staging", credential_delivery: "local_clipboard" })},
      ${createHash("sha256").update(`${userId}:${section}:provisioned`).digest("hex")})`;
  }
  await database`insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload)
    values(${organizationId}::uuid,'validation_access',${userId},'ValidationAccessProvisionedV1',${correlationId}::uuid,${database.json({ user_id: userId, section })})
    on conflict do nothing`;
}

async function provisionOrganization(database, projectRef, user, section, roleCode) {
  const organizationId = deterministicUuid(`${projectRef}:validation:${section}:organization`);
  const membershipId = deterministicUuid(`${projectRef}:validation:${section}:membership`);
  await database.begin(async (transaction) => {
    await transaction`insert into public.organizations(id,legal_name,display_name,country_code,status,created_by)
      values(${organizationId}::uuid,${`Matricia Validation ${section}`},${`Validation ${section}`},'MA','ACTIVE',${user.id}::uuid)
      on conflict(id) do update set legal_name=excluded.legal_name,display_name=excluded.display_name,status='ACTIVE'`;
    await transaction`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at)
      values(${membershipId}::uuid,${organizationId}::uuid,${user.id}::uuid,'ACTIVE',clock_timestamp())
      on conflict(id) do update set user_id=excluded.user_id,status='ACTIVE',activated_at=coalesce(public.organization_memberships.activated_at,clock_timestamp())`;
    await transaction`insert into public.organization_member_roles(membership_id,role_code,granted_by,revoked_at)
      values(${membershipId}::uuid,${roleCode},${user.id}::uuid,null)
      on conflict(membership_id,role_code) do update set granted_by=excluded.granted_by,revoked_at=null`;
  });
  return { organizationId, membershipId };
}

async function verifyAccess(adminFactory, database, user, email, secret, roleCode) {
  const client = adminFactory();
  const signedIn = await checked(client.auth.signInWithPassword({ email, password: secret }), "Unable to authenticate a provisioned validation identity");
  if (signedIn.user?.id !== user.id || !signedIn.session) throw new Error("Provisioned validation identity did not establish the expected session");
  const assignments = roleCode === "SUPER_ADMIN"
    ? await database`select 1 from public.platform_user_roles where user_id=${user.id}::uuid and role_code=${roleCode} and revoked_at is null`
    : await database`select 1 from public.organization_memberships membership join public.organization_member_roles role on role.membership_id=membership.id
        where membership.user_id=${user.id}::uuid and membership.status='ACTIVE' and role.role_code=${roleCode} and role.revoked_at is null`;
  if (assignments.length !== 1) throw new Error("Provisioned validation role could not be verified");
  await client.auth.signOut();
}

async function provision() {
  const [envSource, metadataSource] = await Promise.all([
    readFile(resolve(root, ".env.local"), "utf8"),
    readFile(resolve(root, "supabase", "project-metadata.json"), "utf8"),
  ]);
  const env = { ...parseEnv(envSource), ...process.env };
  const metadata = JSON.parse(metadataSource);
  if (!new Set(["development", "staging"]).has(metadata.environment) || env.APP_ENV !== metadata.environment) {
    throw new Error("Validation logins are restricted to the configured development/staging Supabase project");
  }
  const projectRef = required(metadata.project_ref, "Supabase project reference");
  const supabaseUrl = required(env.NEXT_PUBLIC_SUPABASE_URL, "NEXT_PUBLIC_SUPABASE_URL");
  if (new URL(supabaseUrl).hostname !== `${projectRef}.supabase.co`) throw new Error("Supabase URL does not match project metadata");
  const admin = createClient(supabaseUrl, required(env.SUPABASE_SERVICE_ROLE_KEY, "SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const publishableKey = required(env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY");
  const validationClient = () => createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const database = postgres(resolveExpectedDatabaseUrl({
    databaseUrl: required(env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL, "DIRECT_URL"),
    projectRef,
    region: required(metadata.region, "Supabase region"),
  }), { max: 1, prepare: false, connect_timeout: 15 });
  const baseEmail = required(process.env.MATRICIA_VALIDATION_EMAIL, "MATRICIA_VALIDATION_EMAIL");
  const definitions = [
    { section: "admin", label: "Administration", role: "SUPER_ADMIN" },
    { section: "client", label: "Client", role: "CLIENT_OWNER" },
    { section: "prestataire", label: "Sous-traitant", role: "PROVIDER_OWNER" },
    { section: "franchise", label: "Franchisé", role: "FRANCHISE_OWNER" },
  ];
  const credentials = [];
  try {
    for (const definition of definitions) {
      const email = aliasEmail(baseEmail, definition.section);
      const secret = password();
      const user = await upsertUser(admin, database, definition.section, email, secret);
      let organizationId = null;
      if (definition.role === "SUPER_ADMIN") {
        await database`insert into public.platform_user_roles(user_id,role_code,granted_by,revoked_at)
          values(${user.id}::uuid,${definition.role},${user.id}::uuid,null)
          on conflict(user_id,role_code) do update set granted_by=excluded.granted_by,revoked_at=null`;
      } else {
        ({ organizationId } = await provisionOrganization(database, projectRef, user, definition.section, definition.role));
      }
      await recordProvisioning(database, user.id, organizationId, definition.section);
      await verifyAccess(validationClient, database, user, email, secret, definition.role);
      credentials.push(`${definition.label}\t${email}\t${secret}`);
    }
  } finally {
    await database.end({ timeout: 2 });
  }
  if (process.platform !== "win32") throw new Error("Secure clipboard delivery is only configured on the Windows validation host");
  const clipboard = spawnSync("clip.exe", { input: `Section\tLogin\tMot de passe temporaire\n${credentials.join("\n")}\n`, encoding: "utf8", windowsHide: true });
  if (clipboard.status !== 0) throw new Error("Unable to deliver credentials to the local clipboard");
  console.log("PASS four isolated validation logins were provisioned; credentials were copied only to the local clipboard");
}

try {
  await provision();
} catch (error) {
  console.error(`FAIL ${error instanceof Error ? error.message : "validation access provisioning failed"}; no credential was printed`);
  process.exitCode = 1;
}
