# Matricia — modèle de données audité

Date d'audit : 2026-09-15  
Branche / HEAD : `codex/audit-final-2026-09-15` / `b4050fc3a122d1f61b86f819831991be7d3d5c1a`  
Cible inspectée : Supabase **development**, audit SQL `READ ONLY`.

## Verdict de réconciliation

- Les versions de migration répertoriées par la CLI sont identiques en local et sur la cible development distante jusqu'à `20260915020600`. Les numéros volontairement absents ne constituent pas un drift lorsqu'aucune version locale correspondante n'existe.
- PostgreSQL distant : `17.6` ; `supabase/config.toml` cible PostgreSQL majeur `17`.
- Inventaire distant : **438 tables**, **8 vues**, **396 fonctions**, **412 triggers**, **1 376 index** dans `public`.
- Contraintes : **438 PK**, **1 228 FK**, **540 uniques**, **2 457 CHECK**, **1 exclusion** et 10 contraintes-trigger.
- Colonnes de périmètre explicites : `organization_id` sur 183 tables, `franchise_id` sur 23 et `library_id` sur 39. L'absence de ces colonnes sur les tables enfants impose le scope par FK/RPC, pas par donnée navigateur.
- Les migrations sont additives et historiques. Aucun reset, dump importé ou migration appliquée pendant cet audit.

Limite : l'alignement de l'historique ne prouve pas à lui seul l'absence de DDL manuel. La comparaison exhaustive par dump canonique n'a pas été exécutée afin de respecter le mandat strictement read-only et l'absence d'un shadow Docker dans cette passe.

## Carte des agrégats et relations

| Domaine | Tables racines et historiques | Relations / invariants principaux |
|---|---|---|
| Identité et RBAC | `user_profiles`, `organizations`, `organization_identifiers`, `organization_memberships`, `organization_member_roles`, `platform_user_roles`, invitations et demandes d'accès | UUID vers `auth.users`; une membership active par `(organization_id,user_id)`; rôles révoqués conservés; ICE actif/validé unique. |
| Catalogue | `catalog_libraries/categories/subcategories/services`, tables `*_versions`, `catalog_releases`, approbations, imports, mandats | Publication versionnée; `current_published_version_id`; provenance et validation; bibliothèque/franchise explicites. |
| Questionnaires | `question_bank_questions`, `questionnaires`, `questionnaire_versions`, sections, règles, sessions, réponses, révisions, snapshots et événements d'état | Version publiée figée dans la session; autosave avec révision; réponses et évaluations historisées. |
| Client / conformité | profils, sites, projets, tâches, budgets, centres de coûts, documents, exigences, preuves, anomalies, essais | Organisation obligatoire; versions de profil/projet/site; documents privés et décisions séparées du dépôt. |
| Diagnostic / assistance | `diagnostic_runs`, sous-scores, anomalies, recommandations, opportunités, solutions, suggestions IA et décisions humaines | Résultats/suggestions versionnés; décision humaine distincte; opportunité rattachée à l'organisation. |
| Demandes / matching / devis | `service_requests`, `service_request_versions`, `rfqs`, `rfq_providers`, `matching_runs/candidates`, `quotes`, `quote_versions/items/options`, comparaisons | Client et provider séparés; interdiction same-org; devis soumis non réécrit; montants exacts en mineur; comparaison snapshot. |
| Contrats / missions | `contracts`, `contract_versions/parties/items/signatures`, avenants, missions, jalons, livrables, preuves, checklists et feedback | Snapshot signé immuable; avenant active une nouvelle version; preuves et scan; transitions auditées. |
| Provider | profils, services, capacités, documents/réservations, qualifications/décisions, restrictions, réputation/badges, factures et règlements | Qualification par service/version; capacité versionnée; document réservé puis contrôlé; aucun accès aux devis concurrents. |
| Finance / fiscalité | `financial_accounts/journals/entries`, taxes versionnées, comptes fournisseurs, achats, paiements sortants, rapprochements, remboursements | `bigint` + devise; journaux équilibrés et append-only; fiscalité datée; mutations par RPC idempotentes. |
| Abonnements / crédits / Boxes | plans et versions, abonnements/cycles/états, intentions/événements paiement, wallets/ledger/lots, Box et bénéfices | Ledger immuable; solde dérivé; événements fournisseur dédupliqués; droits activés par transition serveur. |
| Franchise | franchises, territoires/mandats, gouvernance, CRM/pipeline, performance, relances/digest, P&L, distributions | Périmètre franchise + bibliothèque; règles économiques versionnées; livres et distributions immuables. |
| Litiges | dossiers, snapshots d'ouverture, réponses, preuves, décisions, appels, conflits, conséquences et réaffectations | Contradictoire; séparation des rôles; décision/version; conséquences financières non réécrites. |
| Marketing | kits de marque, consentements, campagnes, contenus/versions, calendriers, connexions, publications, attribution et tendances | Consentement/autorisation/kill switch; jobs loués et rejouables; publication et résultat historisés. |
| Audit / Outbox / opérations | `audit_events`, `event_outbox`, jobs/tentatives, DLQ, security evidence/incidents, restore evidence | Chaîne d'audit et historique immuables; outbox claimée avec verrou; reprise bornée; preuves opérationnelles. |
| Vie privée | traitements, finalités, catégories, destinataires, sous-traitants, transferts, consentements, DSR, rétention et legal holds | Formalités CNDP; références pseudonymisées; historique immuable; gate de préparation explicite. |

## RLS, ACL et vues

- **438/438 tables `public` ont RLS activée.**
- 419 policies sont présentes. Vingt-et-une tables ont RLS sans policy : `abuse_signal_events`, `assistance_input_purge_attempts`, `assistance_input_purge_jobs`, `catalog_command_keys`, `catalog_import_chunk_rows`, `catalog_import_chunks`, `catalog_publish_retry_policies`, `catalog_source_files`, `client_trials`, `diagnostic_reevaluation_queue`, `domain_automation_run_pages`, `domain_automation_runs`, `idempotency_keys`, `notification_mandatory_policy_versions`, `notification_retry_policy_versions`, `platform_user_roles`, `public_contact_requests`, `questionnaire_abandonment_policy_versions`, `service_checklist_templates`, `subscription_payment_events`, `subscription_payment_intents`.
- Cette absence signifie deny-by-default. L'audit des grants ne trouve aucun accès `anon`/`authenticated` à ces tables; seul `service_role` possède `SELECT` sur `subscription_payment_events`.
- Aucune table `public` n'est accordée à `anon`. `authenticated` possède au moins un grant sur 421 tables et reste filtré par RLS. `service_role` a des grants directs sur 4 tables.
- Vues `security_invoker=true` : `accounts_payable_balances`, `client_central_calendar`, `credit_wallet_balances`, `marketing_campaign_performance`, `marketing_performance_dimensions_v1`, `outbound_payment_status_v41`, `provider_invoice_balances`.
- `organization_audit_activity` est renforcée par la migration additive `20260915020500` avec `security_barrier=true` et `security_invoker=true`, sans changer ses sept colonnes ni ses grants. Une fonction privée minimale `organization_audit_activity_rows()` conserve la projection expurgée et filtre explicitement par `private.is_active_org_member(organization_id)` sans ouvrir la table brute. Les tests `0006`, `0007` et `0148_security_view_event_trigger_hardening` couvrent la lecture propre, le DENY cross-tenant et le DENY brut.

## Fonctions, triggers et immutabilité

- 394 fonctions `SECURITY DEFINER`; toutes ont un `search_path` fixé sur la cible auditée.
- 311 sont exécutables par `authenticated`; elles constituent l'API métier et doivent conserver un test ALLOW/DENY par permission sensible.
- Surface anonyme produit : `get_public_subscription_plans()` uniquement; projection bornée aux plans actifs publiables. La migration `20260915020500` révoque les grants hérités `PUBLIC/anon/authenticated` de la fonction de plateforme `rls_auto_enable()` uniquement lorsque l'event trigger actif `ensure_rls` existe et que la fonction appartient à l'utilisateur de migration. L'event trigger reste actif et inchangé.
- Triggers d'immutabilité sur audit, ledgers, signatures, versions, preuves et décisions; outbox avec claim/lease/retry; mise à jour optimistic-lock via `row_version` sur les objets éditables.

## Storage

| Bucket | Public | Usage | Protection constatée |
|---|---:|---|---|
| `client-compliance` | non | conformité Client | policies objet + réservation/scan/version |
| `provider-qualification` | non | pièces Provider | policies objet + réservation upload + MIME/signature/taille |
| `delivery-proofs` | non | preuves de livraison | policies objet + scan fiable + liaison mission |

Neuf policies ciblent `storage.objects`. Toute URL de consultation doit rester signée et temporaire; aucun bucket public n'a été trouvé.

## Index et points de contrôle

- 1 376 index pour 1 228 FK et les accès métier. Les migrations contiennent des index composites/partiels pour memberships actifs, versions publiées, files Outbox, statuts et échéances.
- Vingt-trois tables n'ont qu'un index apparent (souvent la PK), notamment `admin_work_item_events`, `change_requests`, `expense_allocations`, `marketing_exceptions`, `platform_user_roles`, `provider_profiles`, `restore_test_evidence` et `session_revocation_batches`. Ce n'est pas une erreur démontrée; les plans des requêtes de charge doivent décider d'un ajout.
- Le seed est déclaré uniquement pour local/test. Aucune donnée de seed n'a été chargée pendant l'audit.

## Sources de preuve

- `supabase/migrations/*.sql` : 204 fichiers présents après les migrations additives 205–207, avec les versions suivies par Supabase et les fichiers auxiliaires.
- `supabase/tests/*.test.sql` : 154 fichiers et 3 590 assertions PASS après migration 207, fermeture de la couverture RPC négative et ajout des preuves fonctionnelles messagerie/comparaison/rotation. Les tests ciblés 0154/0155 et leurs 4 scénarios de concurrence sont PASS; le replay complet Outbox reste perturbé par un worker development concurrent.
- `docs/corrections-public-dashboards/ACCEPTANCE_REPORT.md` conserve la baseline complète antérieure; les preuves additives 207 et RPC sont détaillées dans l'audit final.
- Migrations 205 et 206 appliquées uniquement sur development après revue et dry-run; dry-run final `upToDate=true`. `provider_payment_proof_uploads` et `provider_payment_proofs` lient désormais un objet privé, immuable et tenant-safe à chaque paiement prestataire.
