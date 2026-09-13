# MATRICIA --- V4.1 UPGRADE PATCH POUR CODEX --- 2026-09-13

## 0. Règle absolue : patcher, ne pas reconstruire

Ce document complète le Gold Master V4 déjà développé. Il ne remplace V4
que sur les points explicitement corrigés ici.

Avant toute modification : 1. créer un checkpoint/tag Git de l'état V4 ;
2. exécuter et enregistrer tous les tests actuels ; 3. inventorier
migrations, schéma, RLS, routes, jobs, webhooks et écrans existants ; 4.
créer `docs/upgrades/V4_TO_V4_1_GAP_REPORT.md` avec PRESENT / PARTIAL /
MISSING / INCORRECT ; 5. travailler sur `upgrade/v4.1` ; 6. préférer ADD
TABLE / ADD COLUMN / ADD INDEX / ADD POLICY / ADD ADAPTER / ADD EVENT /
ADD TEST ; 7. ne jamais reset une base distante, supprimer des
migrations ou réécrire un module fonctionnel sans gap démontré ; 8.
ajouter un test avant chaque correction P0/P1 ; 9. refaire les tests
après chaque lot ; 10. produire `V4_1_MIGRATION_REPORT.md`.

Interdictions : reset destructif, suppression de données réelles,
mutation rétroactive d'une facture ou d'un contrat signé, secrets dans
logs/code/chat, accès production non explicitement autorisé.

## 1. P0 --- Trois flux financiers séparés

### A. Client → Sous-traitant

Le client paie DIRECTEMENT le sous-traitant pour la prestation. Matricia
ne reçoit, ne détient et ne reverse jamais le principal de cette
prestation. Corriger tout escrow ou transit de fonds qui contredit cette
règle.

Matricia conserve uniquement : montant contractuel, montant
déclaré/confirmé payé, date, mode, référence, preuve, contestation,
statut et audit nécessaires au calcul des commissions.

### B. Client → Matricia

Matricia encaisse uniquement ses revenus propres :
Premium/Gold/Platinum, crédits, Boxes/avantages payants et
produits/services Matricia.

### C. Sous-traitant → Matricia

Le sous-traitant paie les factures de commission Matricia et autres
montants contractuels valides.

Ledgers, rapports et rapprochements distincts. Le CA du sous-traitant ne
doit jamais apparaître comme encaissement bancaire Matricia.

## 2. P0 --- Signature électronique Maroc

Créer une abstraction `SignatureProvider` interchangeable.

Tables minimum : `signature_envelopes`, `signature_documents`,
`signature_signers`, `signature_signer_authorities`,
`signature_attempts`, `signature_provider_events`,
`signature_evidence_packages`, `signature_certificates`,
`trusted_timestamps`, `signature_provider_configs`.

Supporter SIMPLE / ADVANCED / QUALIFIED selon le type d'acte. Ne jamais
afficher « qualifiée » si le provider et la transaction n'ont pas
réellement utilisé ce niveau.

Avant signature : contrôler identité, organisation, permission
applicative et pouvoir juridique : représentant légal,
mandat/délégation, portée, plafond éventuel, dates, justificatif et
révocation.

Dossier de preuve immuable : version exacte du contrat, SHA-256 du PDF,
signataire, action/consentement, horodatage, provider, certificat/preuve
disponible, events, résultat de vérification et hash final.

Workflow : DRAFT → READY_FOR_SIGNATURE → SENT → PARTIALLY_SIGNED →
SIGNED avec DECLINED / EXPIRED / FAILED / VOIDED.

Toute modification après lancement de signature crée une nouvelle
version/enveloppe. Webhooks signés, idempotents et anti-replay. Mock en
dev, provider réel configurable.

## 3. P0 --- CNDP / Loi 09-08 / Data Governance

Créer : `processing_activities`, `processing_purposes`,
`data_categories`, `data_recipients`, `processors`,
`subprocessor_register`, `international_transfers`,
`retention_policies`, `privacy_notices`, `consent_records`,
`data_subject_requests`, `privacy_incidents`.

Pour chaque traitement : finalité, données, personnes, destinataires,
systèmes, pays/régions, durée, sous-traitants, statut de formalité CNDP
et références disponibles.

Inventorier les transferts vers Supabase, Vercel, Railway, OpenAI,
Resend, réseaux sociaux, paiement, signature et tout autre tiers.
Prévoir un gate production si une formalité obligatoire est
`REQUIRED_NOT_COMPLETED`.

Ajouter workflow droits des personnes : accès, rectification, opposition
et autres droits applicables ; vérification d'identité proportionnée ;
SLA ; export ; audit.

Chaque catégorie de données reçoit une politique de conservation.
Ajouter purge/anonymisation contrôlée et `LEGAL_HOLD`.

Consentements marketing versionnés ; désinscription ; aucun
témoignage/photo/cas client utilisé sans droit approprié. Prévoir
consentement cookies/trackers si nécessaire.

## 4. P0 --- Achats & dépenses internes Matricia

Ajouter `Matricia Procurement & Accounts Payable`.

Couvrir : fulfillment Boxes, achats volume, OpenAI/IA, Supabase, Vercel,
Railway, Resend, signature, marketing/pub, logiciels/licences,
consultants et autres dépenses.

Workflow : NEED → PURCHASE_REQUEST → APPROVAL → QUOTE/RFQ_OPTIONAL →
PURCHASE_ORDER/CONTRACT → RECEIVED/SERVICE_CONFIRMED → SUPPLIER_INVOICE
→ VALIDATED → PAYMENT_SCHEDULED → PAID → RECONCILED → CLOSED.

Supporter paiement partiel, prépaiement, récurrence, renouvellement,
avoir, contestation, devise et taxes.

Tables : `vendors`, `vendor_bank_accounts`, `purchase_requests`,
`purchase_request_lines`, `purchase_approvals`, `purchase_orders`,
`purchase_order_lines`, `goods_service_receipts`, `supplier_invoices`,
`supplier_invoice_lines`, `supplier_credit_notes`, `accounts_payable`,
`outbound_payments`, `outbound_payment_allocations`,
`expense_categories`, `expense_allocations`, `vendor_contracts`,
`vendor_subscriptions`.

Chaque coût est affectable à PLATFORM / BOX / BENEFIT / LIBRARY /
FRANCHISE / CLIENT / PROJECT / COST_CENTER / MARKETING_CAMPAIGN.

Séparation demandeur/approbateur/payeur selon seuil ; four-eyes pour
montants sensibles.

## 5. P0 --- AI Cost Ledger / FinOps

Créer `ai_usage_events`, `ai_price_versions`, `ai_budgets`,
`ai_cost_allocations`, `ai_provider_configs`.

Pour chaque appel IA : provider/model, feature, timestamp, unités/tokens
facturables disponibles, prix versionné, coût, devise,
organisation/bibliothèque/Box/projet/campagne si applicable, request_id,
succès/échec et latence.

Ne jamais journaliser inutilement des prompts sensibles ni des clés API.

Budgets global + fonctionnalité + plan + bibliothèque. Alertes
50/75/90/100 %, circuit breaker configurable et routing de modèles selon
coût/complexité.

Dashboard : coût IA/client, plan, Box, bibliothèque, fonctionnalité et
marge après IA. Prévoir rapprochement avec facture provider.

## 6. P0 --- Rentabilité réelle Boxes / avantages

Pour chaque consommation : revenu attribué, coût provider/pool, coût IA,
coût signature éventuel, frais de paiement propres Matricia, autres
coûts directs, remboursements/avoirs et marge contributive.

Créer `benefit_actual_costs`, `box_margin_snapshots`,
`plan_margin_snapshots`, `cost_allocation_rules`.

Afficher FORECAST vs ACTUAL, marge par plan/Box/avantage, coût si 100 %
consommé et alertes de marge. Les tarifs historiques restent snapshotés.

## 7. P0 --- Anti-fraude RIB / bénéficiaire

Versionner les comptes bancaires fournisseurs/franchisés/sous-traitants.

Tout changement sensible : step-up auth/MFA, notification sécurité,
four-eyes selon seuil, délai de refroidissement configurable,
justificatif, interdiction de changer le bénéficiaire sur simple
email/message, risk flag si changement proche d'un paiement important,
audit append-only.

Masquer les coordonnées bancaires aux rôles non autorisés.

## 8. P0 --- Paiements propres Matricia

Compléter les paiements abonnement/crédits/Boxes : webhook signé,
idempotence, échec/retry, renouvellement, annulation, upgrade/downgrade,
prorata configurable, remboursement total/partiel, avoir,
chargeback/dispute et rapprochement.

Créer/valider : `payment_refunds`, `payment_disputes`,
`payment_provider_events`, `payment_reconciliation_runs`,
`payment_reconciliation_items`.

Ne jamais mélanger avec client→sous-traitant.

## 9. P1 --- Trésorerie / budget / cash-flow Matricia

Dashboard : encaissements propres Matricia, décaissements, AP à venir,
abonnements récurrents, engagements volume, obligations Boxes/crédits,
taxes à isoler et prévision 30/60/90 jours.

Budgets mensuels/annuels par cost center/library/project avec variance
budget/réel.

## 10. P1 --- Factures fournisseurs & comptabilité analytique

Factures entrantes : HT, taxe par ligne, TTC, devise, référence
fournisseur, original, avoir, statut, période et affectation analytique.

Utiliser le moteur fiscal versionné V4. Si le traitement n'est pas
configuré : `ACCOUNTANT_REVIEW_REQUIRED`.

Prévoir exports/dossier comptable mensuel sans prétendre remplacer
l'expert-comptable.

## 11. P1 --- Registre des fournisseurs technologiques

Créer `third_party_services` : service, propriétaire, finalité, données
traitées, région, criticité, contrat, renouvellement, coût, SLA,
DPA/privacy, sécurité, noms de secrets uniquement, exit plan, provider
alternatif.

Couvrir Supabase, Vercel, Railway, OpenAI, Resend, CMI/PayPal, signature
et réseaux sociaux.

Alertes : renouvellement, hausse coût, quota, panne, certificat/token
expirant et dépendance critique sans alternative.

## 12. P1 --- Contrats : pouvoirs, obligations et cycle de vie

Ajouter authority check, date d'effet, annexes, ordre de priorité
documentaire, renouvellement, expiration, résiliation, suspension,
obligations, notices, legal hold et clauses versionnées.

Après signature : aucune mutation. Toute modification = avenant/nouvelle
version.

## 13. P1 --- Communications probantes

Pour avertissements, non-conformités, factures, mises en demeure et
résiliations : conserver template/version, destinataire, canal,
timestamp, provider message ID, delivery/bounce, document
hash/attachments, retries et preuve de consultation in-app si
disponible.

Ne jamais présenter un email ordinaire comme preuve qualifiée de remise
si ce niveau n'est pas atteint.

## 14. P1 --- Litiges / contradictoire / gel des preuves

À l'ouverture : snapshot contrat/devis/livraison/checklists/messages
pertinents, evidence hold, timeline, pièces des deux parties,
commentaires, décision motivée, reviewer et audit.

L'IA peut résumer/classer, jamais prononcer seule une sanction
contractuelle.

Ajouter gestion de conflit d'intérêts et review/appel interne
configurable.

## 15. P1 --- Sécurité renforcée

Ajouter : - MFA obligatoire avant production pour SUPER_ADMIN, finance,
litiges et opérations sensibles ; - session management + révocation ; -
step-up auth pour RIB, paiements, permissions et exports sensibles ; -
rotation secrets ; - dependency/SBOM scan ; - SAST + secret scan + tests
RLS ; - CSP stricte ; - protection SSRF sur URLs/imports ; -
antivirus/quarantaine uploads ; - chiffrement approprié des données
sensibles ; - audit append-only/tamper-evident ; - runbook incident
sécurité.

Threat cases : changement RIB frauduleux, takeover admin, replay
signature/payment webhook, prompt injection document, export massif et
privilege drift.

## 16. P1 --- Backup / PRA / continuité

Rendre l'exigence V4 exécutable : RPO/RTO par service, backup
DB/storage/config, test de restauration périodique, runbook panne
Supabase/Vercel/Railway, queue/retry/dead-letter et dégradation
contrôlée si IA/email/signature indisponible.

Un provider externe indisponible ne doit pas corrompre l'état métier.

## 17. P1 --- Observabilité / jobs / dead-letter

Ajouter corrélation request_id/event_id, métriques jobs/webhooks,
retries bornés, dead-letter queue, reprocessing admin idempotent,
alertes erreurs/latence/backlog/paiement/signature/facturation.

Aucune PII sensible dans logs.

## 18. P1 --- Export / réversibilité / sortie

Prévoir export organisation autorisé, contrats/factures/preuves,
fermeture compte, révocation sessions/tokens, archivage légal,
anonymisation/purge selon politique et export admin de configuration
critique.

Créer un exit plan pour chaque provider technologique critique.

## 19. P1 --- Qualité du catalogue 6000 questions

Ne pas régénérer les 6000 questions. Auditer : doublons, questions sans
service, règles cassées, anomalies sans recommandation, recommandations
sans opportunité, services sans formulaire devis, traductions manquantes
et questions juridiques/fiscales nécessitant validation experte.

Créer `CONTENT_REVIEW_REQUIRED`.

## 20. P1 --- Gouvernance franchisés

Conserver V4. Ajouter preuve objectifs/KPI, historique changements
questionnaire/service, conflits d'intérêts, contrôle favoritisme, plan
correctif versionné et séparation entre droit de proposer et droit
d'approuver les paramètres financiers/contractuels.

IT : Hatim Ahmitech ne paie aucun droit d'entrée ; bénéfice distribuable
IT 50 % Hatim / 50 % Jalil-NEOXA. Aucune ancienne règle 100 % NEOXA ne
doit survivre.

## 21. P1 --- Marketing Autopilot : sécurité et consentement

Conserver les 8 fonctions V4. Ajouter : consentement/brand
authorization, vérification certification/offre/prix, interdiction
PII/cas client sans droit, OAuth tokens chiffrés, scopes minimaux,
révocation sociale, rate limits, publication idempotente, journal du
contenu exact publié, kill switch global/per provider et attribution
campagne→lead→diagnostic→RFQ→contrat.

## 22. P1 --- Admin Command Center : nouveaux écrans

Ajouter : - Achats & dépenses ; - Fournisseurs Matricia ; - Factures
fournisseurs/AP ; - Paiements sortants ; - Budgets/trésorerie ; - Coûts
IA ; - Rentabilité Boxes ; - Signature électronique ; - Privacy/CNDP ; -
Tiers & dépendances ; - Sécurité/incidents ; - Réconciliation ; - Dead
letters/jobs.

Le bloc « À traiter aujourd'hui » intègre les exceptions de ces modules.

## 23. Tests E2E V4.1 obligatoires

1.  client paie provider directement ; Matricia ne touche pas le
    principal ;
2.  commission provider→Matricia générée après règle éligible ;
3.  abonnement client→Matricia + fiscalité configurée ;
4.  achat crédits + remboursement partiel ;
5.  Box consommée → coûts provider + IA → marge réelle ;
6.  facture fournisseur Matricia → approbation → paiement →
    rapprochement ;
7.  changement RIB → MFA/four-eyes/cooling period ;
8.  contrat → SignatureProvider → envelope → preuve → SIGNED ;
9.  modification contrat signé → avenant, jamais mutation ;
10. webhook signature rejoué → une seule transition ;
11. webhook paiement rejoué → une seule écriture ;
12. data subject request → export/rectification auditée ;
13. legal hold empêche purge ;
14. transfert international marqué non conforme → gate production ;
15. provider externe en panne → retry/DLQ sans corruption ;
16. restore test depuis backup ;
17. franchisé tente de modifier règle financière non autorisée → DENY ;
18. Marketing Autopilot sans consentement requis → publication bloquée ;
19. facture/ledger historique reste immuable ;
20. tenant A ne peut lire aucune donnée tenant B dans les nouveaux
    modules.

## 24. Gates de release V4.1

Ne déclarer V4.1 prête que si : - zéro gap P0 ouvert ; - zéro
Critical/High sécurité ouvert ; - tous les tests V4 auparavant verts
restent verts ; - nouveaux tests V4.1 verts ; - migrations applicables
sans reset ; - RLS sur toutes nouvelles tables exposées ; - aucun secret
dans Git/logs ; - flux financiers A/B/C vérifiés ; - abstraction
SignatureProvider fonctionnelle ; - achats/AP fonctionnels ; - AI cost
ledger et marge Boxes fonctionnels ; - data governance implémentée
techniquement ; - formalités externes restant à accomplir clairement
marquées sans fausse déclaration de conformité.

Produire : `V4_TO_V4_1_GAP_REPORT.md` `V4_1_MIGRATION_REPORT.md`
`V4_1_SECURITY_REPORT.md` `V4_1_FINANCE_RECONCILIATION_REPORT.md`
`V4_1_PRIVACY_REGISTER.md` `V4_1_RELEASE_CHECKLIST.md`

## 25. Instruction finale à Codex

Commence par auditer le CODE RÉEL déjà développé contre ce patch.
N'implémente que les gaps. Ne demande pas à l'utilisateur de redéfinir
une décision déjà fixée dans V4/V4.1. Pour toute valeur commerciale non
fixée, la rendre administrable/versionnée et utiliser une valeur de
démonstration cohérente.

Ne redémarre jamais Matricia depuis zéro. Préserve l'existant, les
données, les migrations et les tests.
