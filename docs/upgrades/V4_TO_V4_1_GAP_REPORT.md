# Matricia — rapport d’écart V4 vers V4.1

Date d’audit : 2026-09-13

Baseline : `32a9c321e228491ea2d9b1d23c912913c27ee804` (`v4-baseline-before-v4.1-2026-09-13`)

Branche : `upgrade/v4.1`
Autorités : Gold Master V4 FINAL, complété uniquement sur les points explicites par `Matricia_V4_1_UPGRADE_PATCH_CODEX_2026-09-13.md`.

## Verdict

V4.1 n’est pas prête. Le baseline V4 compile et ses gates actuels sont verts, mais les huit domaines P0 du patch ont encore au moins un gap ouvert. Ce rapport est un audit du code réel; il ne constitue ni une déclaration de conformité juridique, ni une autorisation de production.

Légende : `PRESENT` = exigence réellement implémentée et prouvée; `PARTIAL` = fondation réutilisable mais livrable incomplet; `MISSING` = artefacts requis absents; `INCORRECT` = comportement existant contredit le patch.

## Baseline et gates enregistrés

| Gate | Résultat exact |
|---|---|
| `pnpm lint` | PASS, 13/14 projets du workspace |
| `pnpm typecheck` | PASS, 13/14 projets |
| `pnpm test` | PASS; Web 127 fichiers / 487 tests, Worker 11 / 54, packages verts |
| `pnpm build` | PASS; build Next.js et Worker verts |
| `pnpm spec:validate` | PASS; 68 fonctions + 8 exigences marketing; P01 annoncée ouverte |
| `pnpm traceability:validate` | PASS structurel; seulement 1/76 exigences marquée VERIFIED |
| `pnpm release:validate` | PASS structurel; catalogue 10 bibliothèques / 200 services / 6000 questions, aucun marqueur incomplet détecté |
| `pnpm test:db` | PASS; 107 fichiers, 2639 assertions, 4 scénarios de concurrence |
| `supabase db push --dry-run --linked` | PASS; `upToDate=true`, aucune migration en attente |

Le validator de release est explicitement structurel : son succès ne ferme aucun gap V4.1 et ne vaut pas promotion.

## Inventaire du baseline

- Base : 156 fichiers de migration, 320 déclarations `CREATE TABLE`, 238 déclarations `CREATE POLICY`. RLS, ACL, fonctions à chemin fixe, audit et Event Outbox sont déjà des primitives transversales (`supabase/migrations/20260910000300_idempotency_audit_outbox.sql`, `20260910000400_financial_ledger.sql:1-72`, `20260910001000_outbox_dispatch_protocol.sql:4-93`).
- Finance existante : ledger général et crédits immuables; facturation/commissions Provider; abonnements; crédits/Boxes; fiscalité Maroc; finance franchise (`20260910000400_financial_ledger.sql`, `20260910000500_credit_ledger.sql`, `20260912006300_provider_billing_reconciliation.sql`, `20260912007000_subscription_plans_cycles.sql`, `20260912007300_boxes_credits_security.sql`, `20260912008000_morocco_tax_engine.sql`, `20260912013100_subscription_payment_activation.sql`, `20260912014300_real_payment_gateways.sql`).
- Routes/API : 71 pages/routes applicatives et 7 routes API. Paiements : `apps/web/app/api/payments/intents/route.ts`, `paypal/capture/route.ts`, webhooks CMI/PayPal/Demo. Écrans existants : Administration Finance, Fiscalité Maroc, Achats groupés, Marketing, Opérations; Client Abonnement/Crédits; Sous-traitant Facturation.
- Jobs : Worker Outbox, antivirus documentaire et relances franchise (`apps/worker/src/outbox-repository.ts`, `worker-cycle.ts`, `client-compliance/processor.ts`, `franchise-followups.ts`). Backoff et dead-letter Outbox existent en SQL (`20260910001000_outbox_dispatch_protocol.sql:69-93`).
- Contrats/litiges : versions, signatures V4 internes, avenants, missions, preuves, décisions humaines et appels (`20260912006100_contracts_missions_core.sql:3-55`, `20260912006400_disputes_reassignment.sql:180-227`).
- Marketing : consentements append-only, Brand Kits, campagnes, contenu, publication idempotente, attribution et RLS (`20260912007800_marketing_autopilot.sql:2-42`, `20260912008600_marketing_authorization_hardening.sql:2-10`, `20260913015800_marketing_v1_completeness.sql:2-300`).
- Absence confirmée par recherche exacte dans `apps`, `packages`, `supabase`, `tests`, `docs` des noms de tables minimum V4.1 pour signature, CNDP, achats/AP, FinOps IA, coûts réels, remboursements/disputes de paiement et tiers technologiques.

## Matrice des gaps

| § | Priorité | Statut | Constat et preuves |
|---|---|---|---|
| 1 — Trois flux financiers | P0 | PARTIAL | Le principal Client→Provider n’est pas comptabilisé comme cash Matricia : l’événement conserve brut, preuve et commission (`20260912006300_provider_billing_reconciliation.sql:4-26,161-184`). Client→Matricia est prouvé pour l’abonnement (`20260912014300_real_payment_gateways.sql:101-237`). Provider→Matricia a factures, paiements et rapprochement (`20260912006300_provider_billing_reconciliation.sql:65-130,206-264`). Gap : les ledgers/rapports bancaires A/B/C ne sont pas explicitement séparés; les journaux Provider sont tenantés à l’organisation Provider (`:217,236`) et aucune trésorerie Matricia distincte ne prouve l’absence de mélange. |
| 2 — Signature électronique Maroc | P0 | MISSING | V4 possède `contract_signatures` et `sign_contract`, preuve JSON immuable (`20260912006100_contracts_missions_core.sql:21,43,53-55`), mais aucune abstraction `SignatureProvider`, aucune des dix tables minimum, aucun niveau SIMPLE/ADVANCED/QUALIFIED, autorité juridique, certificat, timestamp, envelope/provider event ou webhook anti-replay. |
| 3 — CNDP / Loi 09-08 | P0 | PARTIAL | Consentement marketing versionné (`20260912007800_marketing_autopilot.sql:2`, `20260912008600_marketing_authorization_hardening.sql:6`) et purge ciblée IA (`20260912012100_assistance_retention_and_pii_hardening.sql`) existent. Les onze registres minimum, DSR, transferts internationaux, gate `REQUIRED_NOT_COMPLETED`, rétention globale et `LEGAL_HOLD` sont absents. |
| 4 — Procurement & AP | P0 | MISSING | Aucun des vendors, purchase requests/orders, receipts, supplier invoices, AP, outbound payments, allocations, contrats/abonnements fournisseur demandés. Le module « achats groupés » est l’achat volume Client (`20260912006600_volume_procurement_pools.sql`), pas les dépenses internes Matricia. |
| 5 — AI Cost Ledger | P0 | MISSING | Aucune table `ai_usage_events`, `ai_price_versions`, `ai_budgets`, `ai_cost_allocations`, `ai_provider_configs`; aucun prix versionné, budget/seuil/circuit breaker/routing ni rapprochement facture IA. Les logs génériques sont expurgés (`packages/observability/src/logger.ts:102-103`) mais ne constituent pas FinOps. |
| 6 — Marge Boxes/avantages | P0 | PARTIAL | Offres et coûts prévisionnels snapshotés (`20260912007300_boxes_credits_security.sql:10-36`), consommations et remboursements de crédits immuables (`:47-65,73-79`) existent. Manquent `benefit_actual_costs`, snapshots de marge Box/plan, règles d’allocation, coûts provider/IA/signature/paiement réels, FORECAST vs ACTUAL et alertes. |
| 7 — Anti-fraude RIB | P0 | MISSING | Aucun registre bancaire fournisseur/franchisé/provider versionné; aucun changement RIB avec MFA, four-eyes, cooling period, notification, justificatif ou risk flag. Les contrôles AAL2 génériques ne couvrent pas ce flux. |
| 8 — Paiements propres Matricia | P0 | PARTIAL | Intentions et events immuables, CMI/PayPal/Demo, vérification/rejeu idempotent, journal exact, audit/outbox (`20260912013100_subscription_payment_activation.sql:3-240`, `20260912014300_real_payment_gateways.sql:24-255`; `supabase/tests/0097_real_payment_gateways.test.sql`). Seul `PAYMENT_SUCCEEDED` est modélisé. Manquent paiements crédits/Boxes complets, échec/retry métier, renouvellement/annulation/prorata, remboursements total/partiel, avoir, chargeback/dispute et reconciliation provider demandée. |
| 9 — Trésorerie/budget/cash-flow | P1 | MISSING | L’écran Finance actuel supervise abonnements et rapprochement Provider (`apps/web/app/[locale]/administration/finance/messages.ts:2-3`, `apps/web/lib/admin-finance/model.ts:11-19`), sans cash-flow Matricia 30/60/90, AP, engagements, taxes isolées ni variance budget/réel. Les budgets projets Client ne satisfont pas cette exigence. |
| 10 — Factures fournisseurs | P1 | MISSING | Les `provider_invoices` sont les commissions dues par le sous-traitant à Matricia, pas des factures entrantes de fournisseurs (`20260912006300_provider_billing_reconciliation.sql:65-82`). Aucun original, ligne HT/taxe/TTC, avoir, allocation analytique ou dossier comptable mensuel; aucun statut `ACCOUNTANT_REVIEW_REQUIRED`. |
| 11 — Tiers technologiques | P1 | MISSING | Aucune table `third_party_services`, registre coûts/SLA/DPA/région/exit plan/alternative ni alertes de renouvellement/quota/token. Les adapters existants ne remplacent pas ce registre. |
| 12 — Cycle de vie contrats | P1 | PARTIAL | Contrats/versions/parties/items/signatures/avenants immuables (`20260912006100_contracts_missions_core.sql:3-45`) et états jusqu’à TERMINATED. Manquent autorité juridique complète, date d’effet structurée, annexes/priorité, obligations/notices, renouvellement/expiration/suspension et legal hold; activation signée d’un avenant n’est pas prouvée (`docs/evidence/atomic/mat-func-024-045.md:24`). |
| 13 — Communications probantes | P1 | PARTIAL | Notifications, tentatives et résultats existent, ainsi qu’audit/outbox, mais aucune enveloppe probante uniforme liant template/version, destinataire, hash du document/pièces, delivery/bounce et consultation in-app pour avertissement/facture/mise en demeure/résiliation. Aucun niveau qualifié n’est revendiqué. |
| 14 — Litiges/gel des preuves | P1 | PARTIAL | Preuves, réponses, décisions motivées humaines, appels, timeline, immutabilité, RLS, audit/outbox sont présents (`20260912006400_disputes_reassignment.sql:180-227`). Manquent snapshot automatique exhaustif à l’ouverture, evidence/legal hold explicite et contrôle de conflit d’intérêts/reviewer indépendant configurable. L’IA ne décide pas dans le flux actuel. |
| 15 — Sécurité renforcée | P1 | PARTIAL | Sessions/révocation (`20260911001400_identity_workflows.sql:314-359`), politiques MFA/AAL2 (`20260911002500_identity_security_hardening.sql:26-74`), CSP stricte (`apps/web/next.config.ts:16-50`), antivirus ClamAV et logs expurgés sont présents. Manquent enforcement MFA exhaustif avant production pour tous rôles sensibles, step-up RIB/paiements/exports, rotation prouvée, SBOM/SAST/secret scan de release, protection SSRF globale, chiffrement des nouveaux champs sensibles et runbook incident complet. |
| 16 — Backup/PRA | P1 | MISSING | Aucun RPO/RTO versionné, job/test de backup-restauration, runbook panne Supabase/Vercel/Railway ou preuve de restauration. L’Outbox évite certaines corruptions mais ne prouve pas le PRA. |
| 17 — Observabilité/DLQ | P1 | PARTIAL | request/correlation IDs, latence/readiness, retry borné, dead-letter Outbox et vue Opérations en lecture seule (`20260910001000_outbox_dispatch_protocol.sql:4-93`; `packages/observability/src/logger.ts:19-20,102-103`; `apps/web/app/[locale]/administration/operations/operations-dashboard.tsx:8-22`). Manquent reprocessing admin idempotent/four-eyes, métriques exhaustives webhooks/jobs et alerting opérationnel; l’écran déclare explicitement le replay absent (`operations/messages.ts:6`). |
| 18 — Export/réversibilité | P1 | MISSING | Aucun export organisation autorisé complet, fermeture compte, révocation globale tokens, archivage légal, purge/anonymisation transverse ou export de configuration critique; aucun exit plan provider. |
| 19 — Qualité catalogue | P1 | PARTIAL | Le validator prouve structure et cardinalités; release confirme 10/200/6000 sans régénération. Il ne couvre pas toute la matrice doublons/orphelins/règles/recommandations/opportunités/formulaires/traductions/revue experte et aucun `CONTENT_REVIEW_REQUIRED` n’existe (`scripts/validate-catalog.ts`, `scripts/validate-release.ts`). |
| 20 — Gouvernance franchise | P1 | PARTIAL | V4 protège l’exception IT et le 50/50 Hatim/Jalil, les règles versionnées, maker-checker et RLS (`supabase/tests/0050_p13_franchise_governance.test.sql:20-31`; `0051_p15_franchise_finance.test.sql:14-34`). Manquent preuves KPI/objectifs versionnées, historique questionnaire/service dédié, conflits d’intérêts/favoritisme et plan correctif versionné. Aucune règle 100 % NEOXA active n’a été trouvée. |
| 21 — Marketing sécurité/consentement | P1 | PARTIAL | Consentement owner-only, retrait, Brand Kit/claims/certifications, contrôle PII agrégé, scopes, révocation connexion, fréquence, publication idempotente, contenu exact versionné et attribution jusqu’au contrat existent (`20260912007800_marketing_autopilot.sql:2-42`; `20260912008600_marketing_authorization_hardening.sql:2-10`; `20260913015800_marketing_v1_completeness.sql:2-300`). Manquent preuve de chiffrement OAuth au repos, scopes minimaux par provider validés, kill switch global/per-provider explicite et adapters sociaux réels testés. |
| 22 — Admin Command Center | P1 | PARTIAL | Finance, fiscalité, marketing, opérations, conformité, providers et achat volume ont des écrans. Manquent les nouveaux écrans dédiés Procurement, fournisseurs Matricia, supplier AP, paiements sortants, trésorerie, coûts IA, marges Boxes, signature, Privacy/CNDP, tiers, incidents, réconciliation V4.1 et reprocessing DLQ; « À traiter aujourd’hui » ne peut agréger des exceptions de modules absents. |

## Tests E2E V4.1

Les 20 scénarios du §23 sont `MISSING` comme suite V4.1 dédiée. Des briques V4 couvrent partiellement commission, abonnement, replay paiement, marketing sans consentement, immutabilité et isolation tenant, mais aucune promotion ne doit les assimiler aux scénarios complets. Chaque lot ci-dessous doit ajouter ses tests avant correction P0/P1, puis conserver tous les gates baseline verts.

## Plan de lots additifs

1. **F01 — frontières financières A/B/C** : types de flux, comptes Matricia explicites, rapports/rapprochements séparés et tests principal jamais encaissé.
2. **F02 — Procurement/AP/RIB** : vendors, demandes/approbations/PO/réceptions/factures/AP/paiements sortants, allocations analytiques, bank versions, AAL2/four-eyes/cooling.
3. **F03 — paiements propres** : moteur générique abonnement/crédits/Boxes, refunds/disputes/chargebacks/reconciliation et webhooks anti-replay.
4. **F04 — FinOps/marges/trésorerie** : prix et usage IA versionnés, budgets/circuit breaker, coûts réels Box/plan, cash-flow 30/60/90 et exports comptables.
5. **L01 — SignatureProvider** : adapter mock dev + provider configurable, envelopes/signers/authorities/evidence/certificats/timestamps et webhooks.
6. **P01 — Privacy/CNDP** : registres, transferts, rétention, DSR, legal hold, purge et gate production.
7. **G01 — tiers/PRA/export** : registre providers et exit plans, backup/restore testé, RPO/RTO, réversibilité organisation.
8. **S01 — sécurité/observabilité** : MFA/step-up exhaustif, scans/SBOM, SSRF/uploads, incident runbook, DLQ reprocessing four-eyes et alertes.
9. **C01 — contrats/litiges/communications** : autorités, obligations, lifecycle, holds, snapshots contradictoires et preuves de communication.
10. **M01/A01/CAT01** : gaps Marketing, nouveaux écrans Admin et audit sémantique catalogue avec `CONTENT_REVIEW_REQUIRED`.

Ordre recommandé : F01, F02, L01 et P01 en parallèle sur migrations réservées distinctes; puis F03/F04; ensuite G01/S01/C01; enfin M01/A01/CAT01 et les 20 E2E. Toujours additif, jamais de reset ni réécriture d’une migration appliquée.

## Gates de fermeture V4.1

- Zéro P0 ouvert et zéro Critical/High sécurité.
- RLS + ACL + ALLOW/DENY deux tenants sur toute nouvelle table exposée.
- Montants exacts, historique immuable, idempotence, audit et Outbox sur toute mutation sensible.
- 20 E2E V4.1 verts, baseline V4 intégralement vert, migration replay/clean clone et dry-run linked `upToDate` après application development.
- Rapports requis encore à produire : `V4_1_MIGRATION_REPORT.md`, `V4_1_SECURITY_REPORT.md`, `V4_1_FINANCE_RECONCILIATION_REPORT.md`, `V4_1_PRIVACY_REGISTER.md`, `V4_1_RELEASE_CHECKLIST.md`.
- Toute formalité externe restant humaine doit être marquée `REQUIRED_NOT_COMPLETED`; aucune fausse déclaration de conformité et aucune production sans autorisation explicite.

## Closure delta - 2026-09-13

All P0 code gaps and the prioritized P1 code gaps listed above were implemented with
additive migrations 16300 through 17000, including corrective migration 16901.
The full evidence is recorded in the five V4.1 reports beside this file.

- Technical status: PRESENT for sections 1 through 22.
- E2E status: PRESENT, 20/20 scenarios PASS.
- Database non-regression: PASS, 116 files and 2915 assertions.
- Catalogue content status: CONTENT_REVIEW_REQUIRED; no catalogue data was regenerated.
- External legal, CNDP, signature certification, restore and production evidence:
  REQUIRED_NOT_COMPLETED.
- Production deployment: NOT_AUTHORIZED.
