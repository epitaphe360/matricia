# Matricia — matrice de tests

État établi sur l'arbre local audité, dérivé du SHA déployé `b4050fc3a122d1f61b86f819831991be7d3d5c1a` mais comprenant des corrections non committées et les migrations 205–206. PASS signifie que la commande a été exécutée pendant cet audit sur l'état alors présent; l'arbre n'étant pas figé, tous les gates devront être rejoués sur le commit candidat final. REPÉRÉ signifie seulement que le test existe.

| Domaine | Niveau | État | Commande / preuve | Reste à prouver |
|---|---|---:|---|---|
| Monorepo | types | PASS | `corepack pnpm typecheck`; Web relancé après les derniers correctifs | aucune régression observée |
| Monorepo | lint | PASS | `corepack pnpm lint`; Web relancé après les derniers correctifs | aucune régression observée |
| Web | unit/intégration | PASS | `corepack pnpm test`: 755 tests Web | parcours externes distants |
| Worker | unit/intégration | PASS | même commande: 54 tests | validation distante worker |
| Packages | unit/intégration | PASS | même commande: 101 tests | aucune régression observée |
| PostgreSQL/RLS | SQL | PARTIEL FINAL | 154 fichiers et 3 590 assertions PASS; 311/311 RPC référencées avec indice DENY; 0154/0155 ciblés + 4 concurrences PASS avec preuves machine; replay complet Outbox perturbé par un worker development concurrent | rejouer le gate complet sans consommateur externe |
| Migrations | remote dry-run | PASS | migrations 205–206 appliquées en development; dry-run final `upToDate=true` | production non touchée |
| Public FR/AR | E2E | PASS | Playwright public: 34/34; axe, RTL et responsive | audit manuel lecteur d'écran/zoom |
| Messagerie/comparaison/matching | E2E authentifié | PASS | runner autonome 3/3; MAT-FUNC-007/013/018/019, isolation étrangère et cleanup confirmés | extension aux autres parcours verticaux |
| Capacité prestataire | E2E authentifié | FAIL | scénario MAT-FUNC-020 provisionné pour AVAILABLE/LIMITED/FULL/PAUSED; dernier run rouge, fixture neutralisée; deux défauts produit corrigés pendant le diagnostic | obtenir un run 4/4 vert puis visa indépendant |
| Routes authentifiées FR/AR | E2E | NON EXÉCUTÉ | 16 scénarios collectés, typecheck PASS; intégration au runner 54 faite mais lancement Playwright échoué avant le premier scénario, cleanup confirmé | corriger le lancement et rejouer une seule fixture isolée |
| Parcours critiques | E2E | PASS historique à reconfirmer | runner critique annoncé à 24/24; commande et artefact exacts non consignés dans cette matrice | rejouer sur le HEAD figé et enregistrer la preuve reproductible |
| Auth/RBAC | négatif | PASS DENY | 311 RPC inventoriées et référencées; zéro sans indice DENY; 160 avec indices positifs et négatifs, 151 sans preuve ALLOW atomique | compléter les preuves ALLOW atomiques et parcours multi-organisation |
| Paiements | sandbox | REPÉRÉ | suites unitaires/webhook existantes | preuve sandbox CMI/PayPal, replay et double capture |
| Upload/antivirus | intégration | REPÉRÉ | tests scanners présents | preuve ClamAV/scan distant et URLs privées |
| Accessibilité | automatisé + manuel | PARTIEL | axe public vert; H1, clavier radio/menu, RTL et overflow corrigés sur 34 E2E | lecteur d'écran et zoom 200 % manuel |
| Performance | navigateur | PARTIEL | audit navigation 48 vues: 241–3428 ms, moyenne 416 ms | Web Vitals instrumentés, bundle et requêtes avant/après |
| Interactions | AST + E2E | PARTIEL | 107 routes, 183 actions et 614 interactions classées; check PASS | 336 validations runtime motivées restent à exécuter |

## Règle de fermeture

Chaque P0/P1 corrigée doit avoir au minimum un test négatif pertinent et un test de non-régression. Les suites complètes typecheck, lint, tests, SQL, build et E2E critiques sont relancées avant signature de release.
