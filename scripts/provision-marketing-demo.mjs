import { createHash, randomBytes } from "node:crypto";
import { createRequire } from "node:module";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import postgres from "postgres";
import { parseEnv, resolveExpectedDatabaseUrl } from "./p05-e2e/environment.mjs";

/**
 * Démo Marketing : 10 Brand Kits franchisés, 20 Brand Kits prestataires, 50 campagnes,
 * 300 contenus, 100 publications programmées, avec cas réussis, échoués et bloqués.
 * Déterministe et idempotent ; restreint development/staging ; simulation sans `--apply`.
 * Aucune connexion sociale n'a de credential : rien ne peut être publié sur un vrai réseau.
 * Les identifiants du compte démo sont stockés dans .env.local (ignoré par Git), jamais affichés.
 */
const root = resolve(import.meta.dirname, "..");
const requireFromWeb = createRequire(resolve(root, "apps", "web", "package.json"));
const { createClient } = requireFromWeb("@supabase/supabase-js");
const apply = process.argv.includes("--apply");

const FRANCHISES = 10;
const PROVIDERS = 20;
const CAMPAIGNS = 50;
const CONTENTS_PER_CAMPAIGN = 6;
const SCHEDULED_ITEMS = 100;
const CHANNELS = ["LINKEDIN", "FACEBOOK", "INSTAGRAM", "REEL"];
const TEMPLATE_KEYS = ["PROBLEM_SOLUTION", "EXPERT_TIP", "PROVIDER_INTRO", "BEFORE_AFTER", "SERVICE_OF_MONTH", "SUCCESS_CASE"];
const MODES = ["AUTOPILOT", "ASSISTED", "MANUAL"];
const TONES = ["PROFESSIONAL", "PREMIUM", "DIRECT", "WARM"];
const COLORS = ["#121D58", "#0F766E", "#9A3412", "#1D4ED8", "#6D28D9"];
const CITIES = [["Casablanca", "الدار البيضاء"], ["Rabat", "الرباط"], ["Marrakech", "مراكش"], ["Tanger", "طنجة"], ["Agadir", "أكادير"], ["Fès", "فاس"]];
const PASS = { source: "PASS", brand: "PASS", claims: "PASS", privacy: "PASS", certification: "PASS", promotion: "PASS", duplicate: "PASS" };

const id = (seed) => {
  const chars = createHash("sha256").update(seed).digest("hex").slice(0, 32).split("");
  chars[12] = "4";
  chars[16] = ((Number.parseInt(chars[16], 16) & 3) | 8).toString(16);
  return `${chars.slice(0, 8).join("")}-${chars.slice(8, 12).join("")}-${chars.slice(12, 16).join("")}-${chars.slice(16, 20).join("")}-${chars.slice(20).join("")}`;
};
const digest = (value) => createHash("sha256").update(typeof value === "string" ? value : JSON.stringify(value)).digest("hex");
const required = (value, name) => {
  if (typeof value !== "string" || !value.trim()) throw new Error(`${name} is required`);
  return value.trim();
};
const secret = () => `${randomBytes(24).toString("base64url")}aA7!`;
const pad = (value) => String(value).padStart(2, "0");

/** Pure plan: every row the demo needs, derived only from the project ref and the catalogue. */
export function buildMarketingDemoPlan({ projectRef, services, templates }) {
  const orgs = [];
  for (let i = 0; i < FRANCHISES + PROVIDERS; i++) {
    const franchise = i < FRANCHISES;
    const n = franchise ? i + 1 : i - FRANCHISES + 1;
    const [cityFr, cityAr] = CITIES[i % CITIES.length];
    const name = franchise ? `Franchise ${cityFr} ${pad(n)} · Démo Marketing` : `Prestataire ${cityFr} ${pad(n)} · Démo Marketing`;
    const org = id(`${projectRef}:demo:marketing:org:${i}`);
    orgs.push({
      index: i, kind: franchise ? "FRANCHISE" : "PROVIDER", id: org, name, cityAr,
      membership: id(`${org}:membership`), franchise: franchise ? id(`${org}:franchise`) : null, territory: `DEMO_MKT_${pad(n)}`,
      brandKit: id(`${org}:brand-kit`), brandVersion: id(`${org}:brand-kit:v1`),
      connection: id(`${org}:social:linkedin`), account: id(`${org}:social:linkedin:account`),
      rule: id(`${org}:schedule-rule:v1`), calendarPast: id(`${org}:calendar:2026-09`), calendar: id(`${org}:calendar:2026-10`),
      analyticsWithdrawn: i % 10 === 9,
      payload: {
        legal_name: name, trade_name: name.split(" · ")[0], primary_colors: [COLORS[i % COLORS.length]], tone: [TONES[i % TONES.length]], languages: ["FR", "AR"],
        primary_cta: i % 3 === 0 ? "CONTACT" : "DIAGNOSTIC", tracked_url: "https://matricia.ma/fr/diagnostic", allowed_url_hosts: ["matricia.ma"],
        logo_assets: [], asset_restrictions: [], required_mentions: [], forbidden_terms: ["garanti à 100 %", "gratuit"],
        approved_hashtags: [`#${name.split(" · ")[0].replace(/[^\p{L}\p{N}]+/gu, "")}`, "#Matricia"],
      },
    });
  }
  const campaigns = [];
  const contents = [];
  const metrics = [];
  const exceptions = [];
  for (let c = 0; c < CAMPAIGNS; c++) {
    const org = orgs[c % orgs.length];
    const mode = MODES[c % MODES.length];
    const failed = c % 10 === 4;
    const blocked = c % 10 === 7;
    const status = blocked ? "VALIDATED_BY_RULES" : failed ? "FAILED" : c % 5 === 0 ? "PUBLISHED" : "SCHEDULED";
    const campaign = { id: id(`${org.id}:campaign:${c}`), org, mode, status, approved: status === "PUBLISHED" || status === "SCHEDULED", titleFr: `Campagne ${pad(c + 1)} · ${org.payload.trade_name}`, titleAr: `حملة ${pad(c + 1)} · ${org.cityAr}`, frequency: 4 + (c % 5) };
    campaigns.push(campaign);
    for (let k = 0; k < CONTENTS_PER_CAMPAIGN; k++) {
      const service = services[(c * CONTENTS_PER_CAMPAIGN + k) % services.length];
      const template = templates[k % templates.length];
      const content = id(`${campaign.id}:content:${k}`);
      const isBlocked = blocked && k === 0;
      const version = { id: id(`${content}:v1:FR`), status: isBlocked ? "BLOCKED" : campaign.approved ? "APPROVED" : "VALIDATED_BY_RULES", checks: isBlocked ? { ...PASS, certification: "BLOCKED" } : PASS, risk: isBlocked ? 72 : 8 + ((c + k) % 12) };
      contents.push({ id: content, campaign, channel: CHANNELS[k % CHANNELS.length], template: template.versionId, templateKey: template.key, service, version, k });
      if (isBlocked) exceptions.push({ id: id(`${content}:exception`), campaign, contentVersion: version.id, reason: "Certification citée sans preuve vérifiée : publication bloquée jusqu’à la revue centrale." });
      if (campaign.approved && !failed) {
        const source = `content:${version.id}`;
        const clicks = mode === "AUTOPILOT" && c % 4 === 0 ? 24 : 3 + ((c + k) % 6);
        metrics.push({ campaign, metric: "IMPRESSION", quantity: 180 + c * 7 + k * 11, source });
        metrics.push({ campaign, metric: "CLICK", quantity: clicks, source });
        if (k === 0) {
          metrics.push({ campaign, metric: "LEAD", quantity: 2 + (c % 3), source });
          metrics.push({ campaign, metric: "DIAGNOSTIC", quantity: 1 + (c % 2), source });
          if (c % 3 === 0) metrics.push({ campaign, metric: "OPPORTUNITY", quantity: 1, source });
          if (c % 6 === 0) metrics.push({ campaign, metric: "RFQ", quantity: 1, source });
          if (c % 15 === 0) metrics.push({ campaign, metric: "CONTRACT", quantity: 1, source });
        }
      }
      if (failed && k === 0) metrics.push({ campaign, metric: "FAILED", quantity: 1, source: `content:${version.id}` });
    }
  }
  const schedulable = contents.filter((value) => value.campaign.approved || value.campaign.status === "FAILED");
  const items = [];
  for (let s = 0; s < SCHEDULED_ITEMS; s++) {
    const content = schedulable[s % schedulable.length];
    const status = content.campaign.status === "FAILED" ? "FAILED" : content.campaign.status === "PUBLISHED" ? "PUBLISHED" : s % 20 === 13 ? "SKIPPED" : "SCHEDULED";
    const past = status !== "SCHEDULED";
    const day = past ? 1 + (s % 25) : 1 + (s % 28);
    items.push({ id: id(`${content.version.id}:calendar-item:${s}`), content, past, scheduledAt: `2026-${past ? "09" : "10"}-${pad(day)}T${pad(8 + (s % 9))}:${s % 2 ? "30" : "00"}:00+01:00`, status });
  }
  return { orgs, campaigns, contents, metrics, exceptions, items };
}

async function saveLocalEnvironment(source, values) {
  let result = source;
  for (const [key, value] of Object.entries(values)) {
    const line = `${key}=${value}`;
    const pattern = new RegExp(`^${key}=.*$`, "m");
    result = pattern.test(result) ? result.replace(pattern, line) : `${result.trimEnd()}\n${line}\n`;
  }
  await writeFile(resolve(root, ".env.local"), result, { encoding: "utf8", mode: 0o600 });
}

async function upsertUser(admin, database, userId, email, password) {
  const rows = await database`select id from auth.users where lower(email)=lower(${email}) limit 1`;
  const attributes = { email, password, email_confirm: true, user_metadata: { full_name: "Marketing Démo Matricia", preferred_locale: "fr-MA" }, app_metadata: { matricia_demo: true, demo_persona: "marketing" } };
  if (rows.length) {
    const { data, error } = await admin.auth.admin.updateUserById(rows[0].id, attributes);
    if (error) throw new Error("Demo marketing identity update failed");
    return data.user;
  }
  const { data, error } = await admin.auth.admin.createUser({ id: userId, ...attributes });
  if (error) throw new Error("Demo marketing identity creation failed");
  return data.user;
}

async function provision(tx, plan, userId, library) {
  const decidedAt = "2026-09-01T09:00:00Z";
  for (const org of plan.orgs) {
    await tx`insert into public.organizations(id,legal_name,display_name,country_code,status,created_by) values(${org.id}::uuid,${org.name},${org.name},'MA','ACTIVE',${userId}::uuid)
      on conflict(id) do update set display_name=excluded.display_name,status='ACTIVE'`;
    await tx`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(${org.membership}::uuid,${org.id}::uuid,${userId}::uuid,'ACTIVE',clock_timestamp())
      on conflict(id) do update set status='ACTIVE'`;
    if (org.kind === "FRANCHISE") {
      await tx`insert into public.franchises(id,library_id,operator_organization_id,franchise_type,operator_code,territory_code,status,created_by) values(${org.franchise}::uuid,${library}::uuid,${org.id}::uuid,'STANDARD','FRANCHISEE',${org.territory},'CONTRACT_PENDING',${userId}::uuid)
        on conflict(id) do nothing`;
      await tx`insert into public.organization_member_roles(membership_id,role_code,franchise_id,granted_by,revoked_at) values(${org.membership}::uuid,'FRANCHISE_OWNER',${org.franchise}::uuid,${userId}::uuid,null)
        on conflict(membership_id,role_code) do update set revoked_at=null`;
    } else {
      await tx`insert into public.organization_member_roles(membership_id,role_code,granted_by,revoked_at) values(${org.membership}::uuid,'PROVIDER_OWNER',${userId}::uuid,null)
        on conflict(membership_id,role_code) do update set revoked_at=null`;
      await tx`insert into public.provider_profiles(provider_organization_id,activity_summary,team_size,years_experience,created_by) values(${org.id}::uuid,${`${org.payload.trade_name} : prestataire de démonstration marketing.`},6,5,${userId}::uuid)
        on conflict(provider_organization_id) do nothing`;
    }
    for (const purpose of ["SOCIAL_PUBLISHING", "MARKETING_ANALYTICS"]) {
      const decision = purpose === "MARKETING_ANALYTICS" && org.analyticsWithdrawn ? "WITHDRAWN" : "GRANTED";
      await tx`insert into public.marketing_consents(organization_id,purpose,decision,policy_version,evidence_hash,decided_by,decided_at) values(${org.id}::uuid,${purpose},${decision},'MARKETING-CONSENT-V1',${digest(`${org.id}:${purpose}:${decision}`)},${userId}::uuid,${decidedAt}::timestamptz)
        on conflict do nothing`;
    }
    await tx`insert into public.brand_kits(id,organization_id,status,created_by) values(${org.brandKit}::uuid,${org.id}::uuid,'DRAFT',${userId}::uuid) on conflict do nothing`;
    await tx`insert into public.brand_kit_versions(id,brand_kit_id,version,payload,content_hash,change_reason,created_by) values(${org.brandVersion}::uuid,${org.brandKit}::uuid,1,${tx.json(org.payload)},${digest(org.payload)},'Brand Kit initial de démonstration',${userId}::uuid)
      on conflict do nothing`;
    await tx`update public.brand_kits set status='READY',current_version_id=${org.brandVersion}::uuid where id=${org.brandKit}::uuid and current_version_id is distinct from ${org.brandVersion}::uuid`;
    await tx`insert into public.social_connections(id,organization_id,provider,status,scopes,credential_reference,connected_by) values(${org.connection}::uuid,${org.id}::uuid,'LINKEDIN','ACTIVE',array['w_organization_social'],${`demo-sandbox:linkedin:${org.index}`},${userId}::uuid)
      on conflict do nothing`;
    await tx`insert into public.social_accounts(id,organization_id,connection_id,provider_account_reference,display_name,status) values(${org.account}::uuid,${org.id}::uuid,${org.connection}::uuid,${`demo-page-${org.index}`},${`${org.payload.trade_name} · LinkedIn`},'ACTIVE')
      on conflict do nothing`;
    const slots = [{ dayOfMonth: 5, time: "09:00" }, { dayOfMonth: 15, time: "11:30" }, { dayOfMonth: 25, time: "16:00" }];
    await tx`insert into public.marketing_schedule_rules(id,organization_id,social_account_id,version,status,timezone,posts_per_month,reels_per_month,generation_day,allowed_slots,max_service_repetition,privacy_minimum_aggregate,content_hash,created_by)
      values(${org.rule}::uuid,${org.id}::uuid,${org.account}::uuid,1,'ACTIVE','Africa/Casablanca',8,4,25,${tx.json(slots)},2,10,${digest({ org: org.id, slots })},${userId}::uuid) on conflict do nothing`;
    await tx`insert into public.marketing_schedule_rule_heads(organization_id,social_account_id,current_rule_id,updated_by) values(${org.id}::uuid,${org.account}::uuid,${org.rule}::uuid,${userId}::uuid) on conflict do nothing`;
    await tx`insert into public.marketing_calendars(id,organization_id,schedule_rule_id,month_start,status,generated_at,approved_by,approved_at) values(${org.calendarPast}::uuid,${org.id}::uuid,${org.rule}::uuid,date '2026-09-01','PUBLISHED','2026-08-25T09:00:00Z',${userId}::uuid,'2026-08-26T10:00:00Z')
      on conflict do nothing`;
    await tx`insert into public.marketing_calendars(id,organization_id,schedule_rule_id,month_start,status,generated_at,approved_by,approved_at) values(${org.calendar}::uuid,${org.id}::uuid,${org.rule}::uuid,date '2026-10-01','SCHEDULED','2026-09-25T09:00:00Z',${userId}::uuid,'2026-09-26T10:00:00Z')
      on conflict do nothing`;
  }
  for (const campaign of plan.campaigns) {
    await tx`insert into public.marketing_campaigns(id,organization_id,brand_kit_version_id,mode,title_fr,title_ar,status,frequency_max_weekly,risk_threshold,audience_snapshot,source_snapshot,approved_by,approved_at,created_by)
      values(${campaign.id}::uuid,${campaign.org.id}::uuid,${campaign.org.brandVersion}::uuid,${campaign.mode},${campaign.titleFr},${campaign.titleAr},${campaign.status},${campaign.frequency},20,${tx.json({ segment: "ALL_CONSENTED" })},${tx.json({ source: "SERVICE_REFERENTIAL" })},
        ${campaign.approved ? userId : null}::uuid,${campaign.approved ? "2026-09-20T10:00:00Z" : null}::timestamptz,${userId}::uuid)
      on conflict(id) do nothing`;
  }
  for (const content of plan.contents) {
    const hashtags = content.campaign.org.payload.approved_hashtags;
    const body = { hook: `${content.templateKey} · ${content.campaign.org.payload.trade_name}`, body: "Un diagnostic guidé, sans engagement, pour cadrer votre besoin avant la consultation des prestataires qualifiés.", cta: "Démarrer le diagnostic" };
    await tx`insert into public.marketing_content(id,campaign_id,channel,template_version_id,service_id,library_id) values(${content.id}::uuid,${content.campaign.id}::uuid,${content.channel},${content.template}::uuid,${content.service.id}::uuid,${content.service.libraryId}::uuid)
      on conflict do nothing`;
    await tx`insert into public.marketing_content_versions(id,content_id,version,language,title_internal,hook,body,cta,hashtags,landing_url,compliance_checks,risk_score,status,content_hash,created_by)
      values(${content.version.id}::uuid,${content.id}::uuid,1,'FR',${`${content.campaign.titleFr} · ${content.k + 1}`},${body.hook},${body.body},${body.cta},${hashtags},'https://matricia.ma/fr/diagnostic',${tx.json(content.version.checks)},${content.version.risk},${content.version.status},${digest({ id: content.version.id, body })},${userId}::uuid)
      on conflict do nothing`;
    await tx`update public.marketing_content set current_version_id=${content.version.id}::uuid where id=${content.id}::uuid and current_version_id is null`;
  }
  for (const exception of plan.exceptions) {
    await tx`insert into public.marketing_exceptions(id,organization_id,campaign_id,content_version_id,exception_type,severity,reason,automatic_resolution_possible,status)
      values(${exception.id}::uuid,${exception.campaign.org.id}::uuid,${exception.campaign.id}::uuid,${exception.contentVersion}::uuid,'CERTIFICATION','BLOCKING',${exception.reason},false,'OPEN') on conflict(id) do nothing`;
  }
  for (const item of plan.items) {
    await tx`insert into public.marketing_calendar_items(id,calendar_id,campaign_id,content_version_id,social_connection_id,scheduled_at,status)
      values(${item.id}::uuid,${item.past ? item.content.campaign.org.calendarPast : item.content.campaign.org.calendar}::uuid,${item.content.campaign.id}::uuid,${item.content.version.id}::uuid,${item.content.campaign.org.connection}::uuid,${item.scheduledAt}::timestamptz,${item.status})
      on conflict do nothing`;
  }
  for (const metric of plan.metrics) {
    await tx`insert into public.marketing_metric_events(organization_id,campaign_id,metric,quantity,source_event_id,occurred_at)
      values(${metric.campaign.org.id}::uuid,${metric.campaign.id}::uuid,${metric.metric},${metric.quantity},${metric.source},'2026-09-22T12:00:00Z') on conflict do nothing`;
  }
}

async function main() {
  const [source, metadataSource] = await Promise.all([readFile(resolve(root, ".env.local"), "utf8"), readFile(resolve(root, "supabase", "project-metadata.json"), "utf8")]);
  const env = { ...parseEnv(source), ...process.env };
  const metadata = JSON.parse(metadataSource);
  if (!new Set(["development", "staging"]).has(metadata.environment) || env.APP_ENV !== metadata.environment) throw new Error("Demo provisioning is restricted to development/staging");
  const projectRef = required(metadata.project_ref, "SUPABASE_PROJECT_REF");
  const url = required(env.NEXT_PUBLIC_SUPABASE_URL, "NEXT_PUBLIC_SUPABASE_URL");
  if (new URL(url).hostname !== `${projectRef}.supabase.co`) throw new Error("Supabase project mismatch");
  const database = postgres(resolveExpectedDatabaseUrl({ databaseUrl: required(env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL, "DIRECT_URL"), projectRef, region: required(metadata.region, "SUPABASE_REGION") }), { max: 1, prepare: false, connect_timeout: 15 });
  try {
    const templates = (await database`select template_key as key, current_version_id as "versionId" from public.marketing_templates where status='ACTIVE' and current_version_id is not null order by template_key`)
      .filter((value) => TEMPLATE_KEYS.includes(value.key));
    if (templates.length !== TEMPLATE_KEYS.length) throw new Error("Initialise the six standard marketing templates from the marketing administration first");
    const services = await database`select id, library_id as "libraryId" from public.catalog_services where status='PUBLISHED' and current_published_version_id is not null order by code limit 30`;
    if (services.length < 6) throw new Error("At least six published catalogue services are required");
    const plan = buildMarketingDemoPlan({ projectRef, services, templates });
    const summary = { brandKits: { franchise: plan.orgs.filter((v) => v.kind === "FRANCHISE").length, provider: plan.orgs.filter((v) => v.kind === "PROVIDER").length }, campaigns: plan.campaigns.length, contents: plan.contents.length, scheduled: plan.items.length, published: plan.items.filter((v) => v.status === "PUBLISHED").length, failed: plan.items.filter((v) => v.status === "FAILED").length, blockedContents: plan.contents.filter((v) => v.version.status === "BLOCKED").length, analyticsConsentWithdrawn: plan.orgs.filter((v) => v.analyticsWithdrawn).length };
    if (!apply) {
      console.log(JSON.stringify({ mode: "DRY_RUN", environment: metadata.environment, ...summary }));
      return;
    }
    const admin = createClient(url, required(env.SUPABASE_SERVICE_ROLE_KEY, "SUPABASE_SERVICE_ROLE_KEY"), { auth: { autoRefreshToken: false, persistSession: false } });
    const credentials = { MATRICIA_DEMO_MARKETING_EMAIL: env.MATRICIA_DEMO_MARKETING_EMAIL || "demo.marketing@matricia.test", MATRICIA_DEMO_MARKETING_PASSWORD: env.MATRICIA_DEMO_MARKETING_PASSWORD || secret() };
    const user = await upsertUser(admin, database, id(`${projectRef}:demo:marketing-user`), credentials.MATRICIA_DEMO_MARKETING_EMAIL, credentials.MATRICIA_DEMO_MARKETING_PASSWORD);
    await database.begin((tx) => provision(tx, plan, user.id, services[0].libraryId));
    await saveLocalEnvironment(source, credentials);
    console.log(JSON.stringify({ mode: "APPLIED", environment: metadata.environment, ...summary, credentials: "stored in .env.local" }));
  } finally {
    await database.end({ timeout: 5 });
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : "Marketing demo provisioning failed");
    process.exitCode = 1;
  });
}
