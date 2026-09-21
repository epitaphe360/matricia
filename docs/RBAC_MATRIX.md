# Matricia — matrice RBAC et périmètres

Date : 2026-09-15. Matrice dérivée du Gold Master, de `20260910000200_identity_and_rbac.sql`, `20260910000600_reference_data.sql`, des helpers `private.has_*` et des policies/RPC du schéma distant development.

## Principes communs

- L'identité est `auth.uid()`; aucune valeur d'URL ou champ formulaire n'accorde un droit.
- Une organisation peut cumuler plusieurs rôles, mais chaque rôle est porté par une membership **ACTIVE**, avec `revoked_at is null`.
- Les rôles plateforme sont séparés dans `platform_user_roles`; ils ne sont jamais déduits du cumul de rôles de plusieurs organisations.
- Les rôles Franchise ajoutent un scope `franchise_id`/`library_id`; le rôle seul ne donne pas un accès transversal.
- L'accès UI n'est qu'une aide. L'autorité est la policy RLS ou la RPC `SECURITY DEFINER` qui recalcule acteur, tenant, état et rôle.

## Rôles plateforme

| Rôle | Lecture autorisée | Mutations autorisées | DENY structurel |
|---|---|---|---|
| `SUPER_ADMIN` | Vue globale selon les projections admin | Gouvernance/exceptions critiques avec audit, AAL2 et approbations | Ne contourne pas ledgers, signatures, immutabilité ni règles économiques. |
| `MATRICIA_ADMIN` | Exploitation globale | Pilotage, conformité, opérations, configuration autorisée | Aucun secret brut, aucune suppression d'audit, aucun bypass financier. |
| `COMPLIANCE_MANAGER` | Organisations, documents, anomalies, conformité | Revue et décisions de conformité | Aucun changement de revenu/paiement. |
| `FINANCE_MANAGER` | Plans, factures, paiements, rapprochements, reporting | Approbations et opérations financières prévues | Aucun contenu/questionnaire/qualification métier. |
| `DISPUTE_MANAGER` | Dossiers, preuves, décisions, réaffectations | Médiation et décision avec séparation des rôles | Aucune réécriture de règle économique historique. |
| `LIBRARY_MANAGER` | Catalogue, services, questionnaires, règles | Construction, validation/publication selon mandat | Aucun paiement ni décision financière. |
| `SUPPORT_AGENT` | Lecture minimale et dossiers assignés | Assistance non financière, accès temporaire/cas-scopé | Aucune mutation financière/contractuelle ni lecture globale implicite. |
| `READ_ONLY_AUDITOR` | Lecture globale/pseudonymisée par projection | Aucune | Toute RPC mutante; secrets; données brutes non nécessaires. |

## Rôles Client

| Rôle | Capacités principales | Limites |
|---|---|---|
| `CLIENT_OWNER` | Organisation/utilisateurs, onboarding, diagnostic, demandes, sélection, contrats/signatures, abonnement, approbations | Seulement son organisation; règles financières et historique immuables. |
| `CLIENT_ADMIN` | Opérations Client, demandes, missions, documents et gestion interne | Aucun transfert de propriété; actions Owner explicites exclues. |
| `CLIENT_BUYER` | Besoins, consultations, devis, comparaison et sélection dans ses limites | Pas d'administration générale ni mutation comptable sans permission. |
| `CLIENT_ACCOUNTING` | Factures, paiements, budgets, centres de coûts | Ne choisit pas un Provider sans droit Buyer/approbation. |
| `CLIENT_MEMBER` | Diagnostics, brouillons, questionnaires et tâches assignées | Pas de signature, sélection ou finance sensible. |
| `CLIENT_VIEWER` | Lecture autorisée | Aucune mutation métier. |

## Rôles Prestataire

| Rôle | Capacités principales | Limites |
|---|---|---|
| `PROVIDER_OWNER` | Profil, partenariat, utilisateurs, qualification, devis, contrats et décisions majeures | Seulement son organisation et les consultations explicitement reçues. |
| `PROVIDER_MANAGER` | Missions, capacité, équipes, réponses et livraisons | Pas d'acte réservé Owner/Accounting. |
| `PROVIDER_SALES` | Consultations, questions et devis | Aucun devis concurrent; pas de validation technique/finance hors scope. |
| `PROVIDER_TECHNICIAN` | Jalons, checklists, preuves et livrables assignés | Pas de prix, contrat ou facturation. |
| `PROVIDER_ACCOUNTING` | Factures Matricia, commissions, paiements et rapprochements autorisés | Pas de qualification, devis ou mission opérationnelle. |
| `PROVIDER_VIEWER` | Lecture limitée | Aucune mutation. |

## Rôles Franchise

Tous exigent la franchise active et le périmètre bibliothèque/territoire correspondant.

| Rôle | Capacités principales | Limites |
|---|---|---|
| `FRANCHISE_OWNER` | Gouvernance, utilisateurs, mandat/contrat, performance de son périmètre | Aucune autre franchise/bibliothèque; invariants financiers intacts. |
| `FRANCHISE_MANAGER` | CRM, pipeline, relances, digest et activité | Pas de gouvernance/finance réservée. |
| `FRANCHISE_EXPERT` | Contenu métier, questions, anomalies et recommandations mandatées | Aucun paiement ni extension de mandat. |
| `FRANCHISE_PROVIDER_MANAGER` | Réseau Provider et qualification métier dans le scope | Aucun accès Provider hors périmètre ou devis concurrent. |
| `FRANCHISE_ACCOUNTING` | Revenus, part, droit d'entrée et relevés | Aucune mutation catalogue/qualification. |
| `FRANCHISE_VIEWER` | Lecture du périmètre | Aucune mutation. |

## Matrice ressources × périmètres

| Ressource | Client | Provider | Franchise | Plateforme | Preuve serveur |
|---|---|---|---|---|---|
| Organisation/memberships | propre organisation selon rôle | propre organisation selon rôle | propre organisation/franchise | rôles centraux limités | `is_active_org_member`, `has_org_role`, `has_platform_role` + RLS. |
| Diagnostic/questionnaire | organisation Client | seulement contexte partagé/qualification | bibliothèque mandatée | conformité/bibliothèque selon rôle | `organization_id`, version, policy/RPC. |
| Demande/RFQ | propriétaire de la demande | invitation explicite seulement | scope de franchise si fonction prévue | administration autorisée | request→RFQ→provider FKs; tests same-org et concurrent. |
| Devis | Client destinataire | auteur uniquement | aucune lecture générale | rôle autorisé via projection | policies et RPC de version/comparaison; aucune vue concurrente. |
| Contrat/mission | partie Client | partie Provider | seulement lien/scoping explicite | litige/admin autorisé | parties/version/signature + RPC par rôle. |
| Documents | objets propres/partagés explicitement | objets propres/partagés explicitement | aucune transversalité | conformité selon besoin | buckets privés, bindings, signed URL et recalcul d'accès. |
| Finance/crédits | livres de l'organisation selon Accounting/Owner | payables propres | livres franchise propres | Finance Manager | RPC transactionnelle, ledger append-only, RLS. |
| Catalogue | lecture de la projection publiée | lecture utile à qualification | mandat bibliothèque | Library Manager | tables de versions/releases et mandats. |
| Audit/Outbox | audit expurgé propre | audit expurgé propre | audit limité au scope | projections selon rôle | `organization_audit_activity`; Outbox jamais lisible par utilisateurs. |

## Preuves ALLOW/DENY existantes

- `0002_tenant_isolation.test.sql` : tenant propre contre tenant tiers.
- `0006_security_invariants.test.sql` : audit expurgé ALLOW, audit brut/Outbox/écritures directes DENY.
- `0007_p03_rls_matrix.test.sql` : organisations, finance, crédits et audit propre/tiers/plateforme.
- `0010_p04_identity_workflows.test.sql` : invitation, membership, rôle et insertion directe refusée.
- `0057_p08_credit_wallet_client_admin_rls.test.sql`, `0063_p10_franchise_crm_security_hardening.test.sql`, `0089_franchise_digest_scope_hardening.test.sql`, `0094_questionnaire_document_reference_scope.test.sql`, `0096_admin_operations_projection_security.test.sql`, `0108_v41_finance_boundaries_procurement_rib.test.sql`, `0119_secure_client_document_reuse.test.sql` : scopes spécialisés.

Écart d'assurance : `RPC_SECURITY_TEST_MATRIX.md` rapproche les 311 RPC `SECURITY DEFINER` exécutables par `authenticated` des tests SQL. Trente signatures n'ont pas encore d'indice négatif détecté; elles exigent une revue ciblée avant que le critère « chaque permission critique a un ALLOW et un DENY » soit déclaré exhaustif. C'est un gap de preuve P1, pas une élévation reproduite.
