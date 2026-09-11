import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import postgres from 'postgres';

function parseEnv(source) {
  return Object.fromEntries(source.split(/\r?\n/).flatMap((line) => {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$/);
    return match ? [[match[1], match[2].replace(/^(['"])(.*)\1$/, '$2')]] : [];
  }));
}

async function resolveDatabaseUrl(env, metadata) {
  const configured = env.SUPABASE_DB_POOLER_URL || env.DIRECT_URL;
  if (!configured?.startsWith('postgres')) throw new Error('A PostgreSQL DIRECT_URL is required');
  const direct = new URL(configured);
  const directHost = `db.${metadata.project_ref}.supabase.co`;
  const poolerHost = `aws-0-${metadata.region}.pooler.supabase.com`;
  if (direct.hostname === directHost && direct.username === 'postgres') {
    direct.hostname = poolerHost;
    direct.port = '5432';
    direct.username = `postgres.${metadata.project_ref}`;
    direct.searchParams.set('sslmode', 'require');
    return direct.toString();
  }
  if (direct.hostname === poolerHost && direct.username === `postgres.${metadata.project_ref}`) {
    return configured;
  }
  throw new Error('Database host or project reference is not the expected Supabase development project');
}

function deferred() {
  let resolvePromise;
  let rejectPromise;
  const promise = new Promise((resolveValue, rejectValue) => {
    resolvePromise = resolveValue;
    rejectPromise = rejectValue;
  });
  return { promise, resolve: resolvePromise, reject: rejectPromise };
}

async function assertBlocked(promise, label) {
  let settled = false;
  promise.finally(() => { settled = true; }).catch(() => {});
  await new Promise((resolveWait) => setTimeout(resolveWait, 300));
  if (settled) throw new Error(`${label} did not overlap the first transaction`);
}

const root = resolve(import.meta.dirname, '..');
const fileEnv = parseEnv(await readFile(resolve(root, '.env.local'), 'utf8'));
const env = { ...fileEnv, ...process.env };
const metadata = JSON.parse(await readFile(resolve(root, 'supabase', 'project-metadata.json'), 'utf8'));
if (env.APP_ENV !== 'development' || metadata.environment !== 'development') {
  throw new Error('P05 concurrency tests require the explicitly configured development project');
}
const publicUrl = new URL(env.NEXT_PUBLIC_SUPABASE_URL);
if (publicUrl.protocol !== 'https:' || publicUrl.hostname !== `${metadata.project_ref}.supabase.co`) {
  throw new Error('NEXT_PUBLIC_SUPABASE_URL does not match the expected development project reference');
}
const databaseUrl = await resolveDatabaseUrl(env, metadata);
const admin = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15 });
const workerA = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15 });
const workerB = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 15 });
const fixture = {
  ownerId: randomUUID(), centralId: randomUUID(), organizationId: randomUUID(),
  membershipId: randomUUID(), caseId: randomUUID(), documentA: randomUUID(),
  documentB: randomUUID(), anomalyId: randomUUID(), correlationA: randomUUID(),
  correlationB: randomUUID(), questionCorrelationA: randomUUID(),
  questionCorrelationB: randomUUID(), hashA: 'a'.repeat(64), hashB: 'b'.repeat(64),
  reviewKeyA: `p05-review-${randomUUID()}`, reviewKeyB: `p05-review-${randomUUID()}`,
  questionKeyA: `p05-question-${randomUUID()}`, questionKeyB: `p05-question-${randomUUID()}`,
};

async function authenticatedCentral(transaction) {
  await transaction.unsafe('set local role authenticated');
  await transaction`select set_config('request.jwt.claim.sub',${fixture.centralId},true)`;
  await transaction`select set_config('request.jwt.claims',${JSON.stringify({ sub: fixture.centralId, role: 'authenticated', aal: 'aal2' })},true)`;
}

try {
  await admin`update public.event_outbox
    set published_at=clock_timestamp(),locked_at=null,locked_by=null,last_error_code=null
    where published_at is null and organization_id in (
      select id from public.organizations
      where legal_name='P05 Concurrency SARL' and display_name='P05 Concurrency'
        and status='ARCHIVED'
    )`;
  await admin`delete from public.organization_member_roles member_role
    using public.organization_memberships membership,public.organizations organization
    where member_role.membership_id=membership.id
      and membership.organization_id=organization.id
      and organization.legal_name='P05 Concurrency SARL'
      and organization.display_name='P05 Concurrency' and organization.status='ARCHIVED'`;
  await admin`delete from public.organization_memberships membership
    using public.organizations organization
    where membership.organization_id=organization.id
      and organization.legal_name='P05 Concurrency SARL'
      and organization.display_name='P05 Concurrency' and organization.status='ARCHIVED'`;
  await admin`delete from public.platform_user_roles platform_role
    where platform_role.role_code='COMPLIANCE_MANAGER' and platform_role.user_id in (
      select distinct audit.actor_user_id from public.audit_events audit
      join public.organizations organization on organization.id=audit.organization_id
      where organization.legal_name='P05 Concurrency SARL'
        and organization.display_name='P05 Concurrency' and organization.status='ARCHIVED'
        and audit.actor_user_id is not null
    )`;
  await admin.begin(async (transaction) => {
    await transaction`insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
      (${fixture.ownerId}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p05-owner-${fixture.ownerId}@example.invalid`},'',now(),'{}','{}',now(),now()),
      (${fixture.centralId}::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',${`p05-central-${fixture.centralId}@example.invalid`},'',now(),'{}','{}',now(),now())`;
    await transaction`insert into public.organizations(id,legal_name,display_name,status,created_by) values(${fixture.organizationId}::uuid,'P05 Concurrency SARL','P05 Concurrency','PENDING',${fixture.ownerId}::uuid)`;
    await transaction`insert into public.organization_memberships(id,organization_id,user_id,status,activated_at) values(${fixture.membershipId}::uuid,${fixture.organizationId}::uuid,${fixture.ownerId}::uuid,'ACTIVE',now())`;
    await transaction`insert into public.organization_member_roles(membership_id,role_code) values(${fixture.membershipId}::uuid,'CLIENT_OWNER')`;
    await transaction`insert into public.platform_user_roles(user_id,role_code) values(${fixture.centralId}::uuid,'COMPLIANCE_MANAGER')`;
    await transaction`insert into public.client_compliance_cases(id,organization_id,status,created_by) values(${fixture.caseId}::uuid,${fixture.organizationId}::uuid,'PROFILE_IN_PROGRESS',${fixture.ownerId}::uuid)`;
    await transaction`insert into public.client_profile_versions(compliance_case_id,organization_id,version,profile_data,organization_snapshot,source_organization_row_version,created_by) values(${fixture.caseId}::uuid,${fixture.organizationId}::uuid,1,'{}','{}',1,${fixture.ownerId}::uuid)`;
    await transaction`update public.client_compliance_cases set current_profile_version=1 where id=${fixture.caseId}::uuid`;
    const policy = await transaction`select id from public.client_document_policy_versions where document_type='REGISTRATION_DOCUMENT' and status='ACTIVE'`;
    for (const [documentId, version, hash] of [[fixture.documentA, 1, fixture.hashA], [fixture.documentB, 2, fixture.hashB]]) {
      const path = `${fixture.organizationId}/${fixture.caseId}/${documentId}.pdf`;
      await transaction`insert into public.client_compliance_documents(id,compliance_case_id,organization_id,document_type,version,policy_version_id,document_number,issuer,issued_on,expires_on,original_file_name,file_extension,declared_mime_type,declared_size_bytes,declared_sha256,storage_object_path,detected_mime_type,detected_size_bytes,status,uploaded_at,created_by) values(${documentId}::uuid,${fixture.caseId}::uuid,${fixture.organizationId}::uuid,'REGISTRATION_DOCUMENT',${version},${policy[0].id}::uuid,${`RC-${version}`} ,'Tribunal',current_date-1,current_date+365,${`version-${version}.pdf`},'pdf','application/pdf',128,${hash},${path},'application/pdf',128,'PENDING_REVIEW',clock_timestamp(),${fixture.ownerId}::uuid)`;
      const scanId = randomUUID();
      await transaction`insert into private.client_document_scan_results(id,document_id,organization_id,sequence,result,engine_code,engine_version,computed_sha256,detected_mime_type,detected_size_bytes,observed_claims,recorded_by,scanner_principal,correlation_id) values(${scanId}::uuid,${documentId}::uuid,${fixture.organizationId}::uuid,1,'CLEAN','DEMO_SCANNER','1.0',${hash},'application/pdf',128,'{}',null,'SUPABASE_SERVICE_ROLE',${randomUUID()}::uuid)`;
      await transaction`update public.client_compliance_documents set current_scan_result_id=${scanId}::uuid,scan_status='CLEAN',scanned_at=clock_timestamp() where id=${documentId}::uuid`;
    }
  });

  const firstReady = deferred();
  const releaseFirst = deferred();
  const firstReview = workerA.begin(async (transaction) => {
    try {
      await authenticatedCentral(transaction);
      const rows = await transaction`select public.review_client_compliance_document(${fixture.documentA}::uuid,'VERIFIED',${fixture.hashA},null,'Concurrency scan',${fixture.reviewKeyA},${fixture.correlationA}::uuid) as result`;
      firstReady.resolve(rows);
      await releaseFirst.promise;
      return rows;
    } catch (error) {
      firstReady.reject(error);
      throw error;
    }
  });
  await firstReady.promise;
  const secondReview = workerB.begin(async (transaction) => {
    await authenticatedCentral(transaction);
    return transaction`select public.review_client_compliance_document(${fixture.documentB}::uuid,'VERIFIED',${fixture.hashB},null,'Concurrency scan',${fixture.reviewKeyB},${fixture.correlationB}::uuid) as result`;
  });
  try { await assertBlocked(secondReview, 'document review serialization'); } finally { releaseFirst.resolve(); }
  await Promise.all([firstReview, secondReview]);
  const reviewEvidence = await admin`select
    count(*) filter(where status='VERIFIED')::integer as verified,
    count(*) filter(where status='SUPERSEDED')::integer as superseded
    from public.client_compliance_documents where compliance_case_id=${fixture.caseId}::uuid and document_type='REGISTRATION_DOCUMENT'`;
  if (reviewEvidence[0].verified !== 1 || reviewEvidence[0].superseded !== 1) {
    throw new Error('concurrent reviews did not leave exactly one VERIFIED version');
  }
  console.log('PASS p05_document_review_concurrency (2 connections)');

  await admin`insert into public.client_administrative_anomalies(id,compliance_case_id,organization_id,anomaly_code,field_path,severity,blocking,client_message_fr,client_message_ar,detected_by) values(${fixture.anomalyId}::uuid,${fixture.caseId}::uuid,${fixture.organizationId}::uuid,'MANUAL_REVIEW_REQUIRED','profile','CRITICAL',true,'Question requise','السؤال مطلوب','COMPLIANCE_REVIEWER')`;
  const questionReady = deferred();
  const releaseQuestion = deferred();
  const firstQuestion = workerA.begin(async (transaction) => {
    try {
      await authenticatedCentral(transaction);
      const rows = await transaction`select public.create_client_compliance_question(${fixture.anomalyId}::uuid,'Veuillez clarifier la situation.','يرجى توضيح الوضع.',null,clock_timestamp()+interval '1 day',${fixture.questionKeyA},${fixture.questionCorrelationA}::uuid) as id`;
      questionReady.resolve(rows);
      await releaseQuestion.promise;
      return rows;
    } catch (error) {
      questionReady.reject(error);
      throw error;
    }
  });
  await questionReady.promise;
  const secondQuestion = workerB.begin(async (transaction) => {
    await authenticatedCentral(transaction);
    return transaction`select public.create_client_compliance_question(${fixture.anomalyId}::uuid,'Autre question simultanée.','سؤال متزامن آخر.',null,clock_timestamp()+interval '1 day',${fixture.questionKeyB},${fixture.questionCorrelationB}::uuid) as id`;
  });
  try { await assertBlocked(secondQuestion, 'question creation serialization'); } finally { releaseQuestion.resolve(); }
  await firstQuestion;
  let duplicateDenied = false;
  try { await secondQuestion; } catch (error) { duplicateDenied = error.message.includes('ACTIVE_COMPLIANCE_QUESTION_EXISTS'); }
  if (!duplicateDenied) throw new Error('concurrent question creation did not reject the duplicate active question');
  const questionCount = await admin`select count(*)::integer as count from public.client_compliance_questions where anomaly_id=${fixture.anomalyId}::uuid`;
  if (questionCount[0].count !== 1) throw new Error('concurrent question creation produced a duplicate');
  console.log('PASS p05_question_creation_concurrency (2 connections)');
  await admin.begin(async (transaction) => {
    await transaction`update public.event_outbox
      set published_at=clock_timestamp(),locked_at=null,locked_by=null,last_error_code=null
      where organization_id=${fixture.organizationId}::uuid and published_at is null`;
    await transaction`update public.organizations set status='ARCHIVED' where id=${fixture.organizationId}::uuid`;
    await transaction`delete from public.organization_member_roles where membership_id=${fixture.membershipId}::uuid`;
    await transaction`delete from public.organization_memberships where id=${fixture.membershipId}::uuid`;
    await transaction`delete from public.platform_user_roles where user_id=${fixture.centralId}::uuid and role_code='COMPLIANCE_MANAGER'`;
  });
  console.log(`INFO retained immutable archived P05 evidence fixture organization=${fixture.organizationId}`);
} finally {
  await Promise.allSettled([workerA.end(), workerB.end()]);
  await admin.end({ timeout: 2 });
}
