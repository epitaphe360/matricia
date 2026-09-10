# Threat model initial — Matricia V1

## Portée et invariants

Ce modèle couvre les fonctions V1 `MAT-FUNC-001` à `MAT-FUNC-068`, les applications Web/Worker, Supabase Auth/PostgreSQL/Storage, les fonctions serveur, les fournisseurs externes et les traitements planifiés. Les fonctions `069` à `090` restent hors périmètre V1.

Invariants non négociables : aucune fuite inter-organisation, inter-franchise ou entre fournisseurs concurrents ; aucune mutation financière directe ; aucun secret côté client ou dans les logs ; aucun déploiement ou changement de production sans autorisation explicite.

## Actifs critiques

- Identités, sessions, memberships, rôles et permissions.
- Données juridiques, documents, preuves, coordonnées et réponses de diagnostic.
- RFQ, devis concurrents, contrats, signatures, missions et litiges.
- Factures, paiements, commissions, pénalités, crédits, ledgers et règles fiscales.
- Droits économiques des franchises, dont la règle IT 50/50 Hatim–Jalil/NEOXA.
- Secrets Supabase, paiement, email, OAuth social et clés de signature.
- Audit append-only, Event Outbox, webhooks et sauvegardes.

## Frontières de confiance

1. Navigateur non fiable → application Web.
2. Web → API/use cases serveur autorisés.
3. Serveur/Worker → Supabase avec privilèges minimaux.
4. Supabase Auth → memberships et permissions relus en base pour les actions sensibles.
5. Storage privé → URL signée courte après contrôle d’accès.
6. Fournisseurs externes → webhooks signés, dédupliqués et rejouables.
7. Development/staging → production, séparés par projets, secrets et autorisations.

## Menaces, contrôles et preuves attendues

| Menace | Contrôles obligatoires | Preuve de gate |
|---|---|---|
| Tenant escape / IDOR | `organization_id` explicite, FK composites, RLS deny-by-default, membership actif relu en base | Tests SQL croisés sur deux organisations |
| Escalade horizontale/verticale | RBAC + scope, aucune confiance dans un rôle fourni par le client, RPC sensibles autorisées explicitement | Tests rôle forgé et matrice ALLOW/DENY |
| Fournisseur voyant un concurrent | Policies RFQ/devis asymétriques, vues sûres sans coordonnées ni prix concurrents | Test Provider A contre Quote B |
| Franchisé voyant une autre bibliothèque | Vérification séparée `franchise_id` + `library_id`; une référence commerciale ne confère aucun accès | Tests inter-franchises et referral |
| Accès direct aux documents | Buckets privés, ACL métier, signed URL courte, contrôle MIME/taille, quarantaine antivirus abstraite | Tests Storage directs et URL expirée |
| Manipulation de prix/taux/score | Valeurs critiques recalculées serveur depuis règles versionnées ; montants `bigint`, taux exacts | Tests de falsification de payload |
| Double paiement/crédit/pénalité | Clé d’idempotence + hash de requête, verrou transactionnel, contraintes uniques | Tests retry et concurrence |
| Déséquilibre financier | Ledger append-only, écriture double équilibrée par devise avant commit | Tests propriété/mutation du ledger |
| Falsification/rejeu webhook | Signature fournisseur, timestamp, identifiant externe unique, journal de réception | Tests signature invalide et replay |
| Réutilisation/brute force OTP | Expiration, invalidation du précédent code, limite compte/IP, compteur de tentatives | Tests expiration, rotation et rate limit |
| Injection SQL/XSS/PDF/email | Paramétrage, validation Zod serveur, encodage contextualisé, CSP, sanitation des contenus générés | Tests injection aux frontières |
| Upload malveillant | Allowlist MIME/extension, taille configurable, nom serveur, scan/quarantaine | Corpus de fichiers hostiles |
| Contournement de suspension | Guards serveur sur nouvelles opportunités ; accès maintenu aux obligations existantes | E2E fournisseur restreint |
| Fuite de secret/PII | Configuration centralisée, redaction structurée, audit minimal, `.env.local` ignoré | Scan Git, logs et bundle client |
| Compromission `SECURITY DEFINER` | Fonctions minimales, objets qualifiés, `search_path` fermé, `EXECUTE` révoqué puis accordé précisément | Audit SQL des fonctions et grants |
| Publication marketing risquée | Claims/privacy/certification/promotion checks, seuil k-anonymity, blocage par exception | Tests non-publication des cas à risque |
| Changement de production accidentel | Identification explicite de l’environnement et allowlist du project ref ; autorisation humaine obligatoire | Gate de déploiement et journal d’approbation |

## Journalisation et réponse

Les actions sensibles écrivent dans la même transaction l’état métier, un audit minimal redacted et un événement Outbox. Les alertes utilisent un identifiant de corrélation, jamais un secret ou un document brut. Les événements impossibles à traiter passent en dead-letter sans bloquer les autres tenants. Un finding Critical ou High bloque la release ; un Medium sur une surface sensible exige correction ou acceptation formelle avec mitigation et propriétaire.

## Risques résiduels encadrés

- La configuration fiscale Maroc en production doit être validée par un expert-comptable ; le taux 20 % reste une donnée de démonstration versionnée.
- Les registres officiels, paiements, antivirus et réseaux sociaux utilisent des ports et adaptateurs ; un mode Demo ne doit jamais prétendre effectuer une vérification réelle.
- Les claims JWT peuvent être périmés : les décisions sensibles relisent toujours l’autorité en base.
- La restauration et la rotation des secrets doivent être testées avant toute ouverture production.

