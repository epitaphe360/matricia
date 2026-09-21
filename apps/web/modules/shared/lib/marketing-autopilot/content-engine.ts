import { createHash } from "node:crypto";
import { z } from "zod";
import { formatMinor } from "./model";

export const marketingTemplateKey = z.enum([
  "PROBLEM_SOLUTION", "EXPERT_TIP", "PROVIDER_INTRO", "BEFORE_AFTER", "SERVICE_OF_MONTH", "SUCCESS_CASE",
]);
export const marketingChannel = z.enum(["LINKEDIN", "FACEBOOK", "REEL"]);

export const serviceContentInput = z.object({
  campaignId: z.string().uuid(), serviceId: z.string().uuid(), libraryId: z.string().uuid(),
  organizationId: z.string().uuid(), language: z.enum(["FR", "AR"]), serviceName: z.string().trim().min(2).max(160),
  valueProposition: z.string().trim().min(3).max(500), primaryCta: z.string().trim().min(2).max(120),
  trackedUrl: z.string().url().refine((value) => value.startsWith("https://")),
  approvedHashtags: z.array(z.string().regex(/^#[\p{L}\p{N}_-]+$/u)).max(12),
  approvedClaims:z.array(z.object({id:z.string().uuid(),key:z.string().min(2).max(120),textFr:z.string(),textAr:z.string(),evidenceHash:z.string().regex(/^[0-9a-f]{64}$/)}).strict()).max(50).default([]),
  templateKey: marketingTemplateKey.default("PROBLEM_SOLUTION"), sourceHash: z.string().regex(/^[0-9a-f]{64}$/),
  providerIdempotencyKey: z.string().trim().min(8).max(200).optional(),
  offer:z.object({quoteVersionId:z.string().uuid(),totalMinor:z.string().regex(/^\d+$/),currency:z.string().regex(/^[A-Z]{3}$/),displayAmount:z.string().min(5).max(80).optional()}).optional(),
});

export type GeneratedServiceContent = {
  channel: z.infer<typeof marketingChannel>; titleInternal: string; hook: string; body: string; cta: string;
  hashtags: string[]; landingUrl: string; riskScore: number; contentHash: string; durationSeconds: number | null;
  claimIds: string[];
};
export const generatedServiceContentSchema=z.object({channel:marketingChannel,titleInternal:z.string().min(3).max(300),hook:z.string().min(2).max(2000),body:z.string().min(3).max(8000),cta:z.string().min(2).max(300),hashtags:z.array(z.string().regex(/^#[\p{L}\p{N}_-]+$/u)).max(12),landingUrl:z.string().url().refine(value=>value.startsWith("https://")),riskScore:z.number().int().min(0).max(100),contentHash:z.string().regex(/^[0-9a-f]{64}$/),durationSeconds:z.number().int().min(20).max(30).nullable(),claimIds:z.array(z.string().trim().min(1).max(120)).max(20)}).strict();

function normalizedLandingUrl(input: z.infer<typeof serviceContentInput>, channel: z.infer<typeof marketingChannel>) {
  const url = new URL(input.trackedUrl);
  url.searchParams.set("campaign_id", input.campaignId);
  url.searchParams.set("content_source", "matricia");
  url.searchParams.set("library_id", input.libraryId);
  url.searchParams.set("service_id", input.serviceId);
  url.searchParams.set("utm_campaign", input.campaignId);
  url.searchParams.set("utm_medium", "social");
  url.searchParams.set("utm_source", channel === "LINKEDIN" ? "linkedin" : channel === "FACEBOOK" ? "meta" : "instagram_reel");
  return url.toString();
}

function templateFrame(input:z.infer<typeof serviceContentInput>){const ar=input.language==="AR";switch(input.templateKey){case"EXPERT_TIP":return{lead:ar?"نصيحة خبير قابلة للتطبيق":"Conseil d’expert directement applicable",proof:ar?"خطوة عملية مرتبطة بمصدر موثق":"Une étape concrète reliée à une source vérifiable"};case"PROVIDER_INTRO":return{lead:ar?"تعرّفوا على خبرة مقدم الخدمة":"Découvrez l’expertise du prestataire",proof:ar?"منهج واضح ونطاق خدمة محدد":"Une méthode claire et un périmètre de service explicite"};case"BEFORE_AFTER":return{lead:ar?"من وضع قائم إلى نتيجة قابلة للقياس":"D’une situation initiale à un progrès mesurable",proof:ar?"المقارنة لا تستخدم إلا أدلة معتمدة":"La comparaison repose uniquement sur des preuves approuvées"};case"SERVICE_OF_MONTH":return{lead:ar?"خدمة الشهر المختارة":"Le service du mois à découvrir",proof:ar?"اختيار مرتبط باحتياج مهني موثق":"Une sélection reliée à un besoin professionnel documenté"};case"SUCCESS_CASE":return{lead:ar?"حالة نجاح موثقة دون بيانات شخصية":"Un cas de réussite documenté sans donnée personnelle",proof:ar?"النتائج المنشورة تستند إلى أدلة صالحة":"Les résultats cités reposent sur des preuves valides"};default:return{lead:ar?"مشكلة واضحة وحل مهني":"Un problème clair, une réponse professionnelle",proof:ar?"الحل مرتبط بحاجة ومصدر موثقين":"La réponse reste liée à un besoin et une source vérifiables"}}}
function copy(input: z.infer<typeof serviceContentInput>, channel: z.infer<typeof marketingChannel>) {
  const ar = input.language === "AR";
  const frame=templateFrame(input);
  const offer=input.offer?` ${ar?"العرض الموثق":"Offre vérifiée"}: ${formatMinor(input.offer.totalMinor,input.offer.currency,ar?"ar":"fr")}.`:"";
  if (channel === "LINKEDIN") return {
    hook: `${frame.lead} — ${input.serviceName}`,
    body: `${input.valueProposition}\n${frame.proof}.${offer}`,
  };
  if (channel === "FACEBOOK") return {
    hook: ar ? `${frame.lead}: ${input.serviceName}.` : `${frame.lead} : ${input.serviceName}.`,
    body: (ar ? `${input.valueProposition}\n${frame.proof}. اكتشفوا المسار المناسب.` : `${input.valueProposition}\n${frame.proof}. Découvrez le parcours adapté.`)+offer,
  };
  return {
    hook: `${frame.lead}. ${input.serviceName}.`,
    body: (ar ? `0–5 ث: ${frame.lead}. 5–18 ث: ${input.valueProposition}. 18–25 ث: ${input.primaryCta}.` : `0–5 s : ${frame.lead}. 5–18 s : ${input.valueProposition}. 18–25 s : ${input.primaryCta}.`)+offer,
  };
}

function assertSafeSource(input:z.infer<typeof serviceContentInput>){
  const text=`${input.serviceName} ${input.valueProposition} ${input.primaryCta}`;
  if(/[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}/u.test(text)||/(?:\+?212|0)[5-7]\d{8}/u.test(text))throw new Error("MARKETING_PRIVACY_CHECK_FAILED");
  if(/(?:100\s*%|garanti(?:e)?|résultat certain|نتيجة مضمونة)/iu.test(text))throw new Error("MARKETING_CLAIMS_CHECK_FAILED");
  if(/\d/u.test(input.valueProposition))throw new Error("MARKETING_SOURCE_CHECK_FAILED");
}

export function generateServiceContent(raw: z.input<typeof serviceContentInput>): GeneratedServiceContent[] {
  const input = serviceContentInput.parse(raw);
  assertSafeSource(input);
  return marketingChannel.options.map((channel) => {
    const value = copy(input, channel), landingUrl = normalizedLandingUrl(input, channel);
    const canonical = JSON.stringify({ channel, language: input.language, templateKey: input.templateKey, serviceId: input.serviceId, hook: value.hook, body: value.body, cta: input.primaryCta, hashtags: input.approvedHashtags, landingUrl, sourceHash: input.sourceHash });
    return { channel, titleInternal: `${input.templateKey}:${input.serviceName}:${channel}`, ...value, cta: input.primaryCta, hashtags: input.approvedHashtags, landingUrl, riskScore: 0, contentHash: createHash("sha256").update(canonical).digest("hex"), durationSeconds: channel === "REEL" ? 25 : null, claimIds: [] };
  });
}
