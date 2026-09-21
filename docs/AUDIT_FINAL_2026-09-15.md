# Audit final Matricia — 2026-09-15

## Périmètre réconcilié

- Déploiement contrôlé : `matricia-jd3dfqz66-epitaphemarket-5584s-projects.vercel.app`.
- Projet Vercel : `matricia`; cible `production`; état observé `READY`.
- Branche de production observée : `codex/bootstrap-foundation`.
- SHA déployé : `b4050fc3a122d1f61b86f819831991be7d3d5c1a`.
- Branche d'audit : `codex/audit-final-2026-09-15`, créée depuis ce SHA sans reset.
- Le SHA déployé contient la fusion de `646193a`; aucune différence de fichier n'existe entre ces deux points.
- Racine Vercel : `apps/web`; framework Next.js; commandes build/install auto-détectées.
- Projet Supabase lié : `nbqtuybebrhkqmtonhsd` (development). Les migrations additives 205 et 206 ont été appliquées; le dry-run final confirme `upToDate=true`.
- Audit SQL distant en transaction lecture seule : PostgreSQL 17.6; 438 tables publiques avec RLS, 419 policies, 394 fonctions `SECURITY DEFINER` toutes avec `search_path` fixé, 3 buckets privés.

Aucune valeur de secret n'a été affichée, copiée dans ces documents ou ajoutée à Git. Les variables nécessaires sont inventoriées par leur nom uniquement dans `INTEGRATION_MATRIX.md`.

## Inventaire réel

- 74 pages, 19 route handlers, 3 sorties metadata, 4 écrans d'erreur et 7 écrans de chargement.
- 183 actions serveur exportées.
- 614 interactions JSX détectées par le scanner AST, toutes classées; 336 gardent une dette de validation runtime.
- 204 fichiers de migrations SQL et 154 fichiers de tests SQL après durcissements additifs.
- 182 fichiers de tests web, 11 fichiers de tests worker et 23 spécifications E2E.
- Catalogue validé structurellement : 10 bibliothèques, 200 services, 6 000 questions.

## Gates exécutés sur le HEAD local audité

Le HEAD Git reste dérivé du SHA déployé `b4050fc3a122d1f61b86f819831991be7d3d5c1a`, mais les résultats ci-dessous incluent les corrections locales non committées et les migrations 205–206. L'arbre n'est pas figé : ces PASS devront être rejoués après gel du commit candidat à la release.

| Gate | Résultat | Preuve synthétique |
|---|---:|---|
| TypeScript | PASS | `pnpm typecheck` |
| Lint | PASS | `pnpm lint` |
| Tests unitaires/intégration | PASS | web 755, worker 54, packages 101; total 910 |
| Build production | PASS | Next.js 16.3.3 |
| Tests SQL/RLS | PARTIEL FINAL | 154 fichiers et 3 590 assertions PASS; 311/311 RPC référencées avec indice DENY; les tests ciblés 0154/0155 et leurs 4 scénarios de concurrence sont prouvés par rapports machine; le replay complet du premier scénario Outbox a subi la consommation de l'événement par un worker development concurrent |
| E2E public FR/AR | PASS | 34/34, mobile et desktop; largeurs 360, 390, 768 et 1440 couvertes par axe/runtime |
| E2E authentifié ciblé | PARTIEL | 3/3 historiques PASS : messagerie, comparaison et matching; scénario capacité MAT-FUNC-020 écrit mais dernier run FAIL avec cleanup; smoke authentifié 16 scénarios collectés mais run 54 interrompu avant exécution |
| Parcours critiques | PASS | 24/24, protections anonymes et refus cross-role inclus |
| Validation release structurelle | PARTIEL | structure valide; P01 ouverte; traçabilité indépendante actuelle 5/76 VERIFIED, dont 5/68 MAT-FUNC V1 |
| Routes publiques distantes | PASS limité | FR, AR, diagnostic, besoin, fournisseur, abonnements, contact, health et readiness répondent HTTP 200 |
| SEO public distant | PASS structurel | canonical et hreflang FR/AR corrects; robots index/follow; sitemap 16 URL |
| Responsive public live | PARTIEL | 48 vues aux largeurs 360/390/412/768/1024/1440; un état de chargement diagnostic sans H1 identifié et corrigé localement |

## Conclusion intermédiaire

L'arbre local audité et la base development liée ont passé les gates consignés, mais l'arbre n'est ni figé ni un commit de release. Aucun P0 exploitable n'a été reproduit dans l'audit DB/RLS. Les écarts P1 corrigés couvrent taxonomie publique, continuité Besoin, qualification, explication du matching, comparaison, stockage privé des preuves de paiement et accessibilité/responsive public. La release reste non signable tant que le HEAD final n'est pas gelé et retesté, et tant que les intégrations externes, la traçabilité 76/76 et la dette runtime des matrices ne sont pas prouvées. Aucun contrôle n'est fermé par simple présence de code ou d'une variable.
