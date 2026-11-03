# Recette navigateur Franchisé — journal et provenance

## Préparation sur la version fusionnée

Source exacte : `df67da46f48def7cf804855ab985a28dec4aab6e`, arbre `apps/web` `ef4b62c67a4d8ad5a6403e6a4568bd9dc1774c75`. Base locale isolée réutilisée après contrôle des labels, du réseau interne et de l’absence de ports Docker publiés. Une sauvegarde privée avant mutation a été créée ; sa restauration n’est pas déclarée testée.

Deux nouveaux acteurs de test ont été créés via GoTrue, authentifiés par OTP puis TOTP AAL2, avec organisations créées par `create_or_request_organization`. Ils utilisent exclusivement des adresses `@example.invalid`. Aucun JWT utilisateur, rôle de franchise ou preuve de signature n’a été fabriqué. Les auteurs et réviseurs de gouvernance sont des acteurs natifs distincts déjà présents dans la cohorte de test.

La proposition du premier mandat et son approbation indépendante ont utilisé les commandes publiques. L’auto-approbation a été refusée avec `42501`. L’organisation étant encore `PENDING`, une tentative contractuelle renvoie l’erreur ambiguë `FRANCHISE_ACTIVATION_MFA_REQUIRED` malgré AAL2 ; la signature n’a pas été atteinte, ni certifiée. Cette cause a été transmise au propriétaire du code.

Absence de mandat : les captures FR et AR à 390 px montrent l’explication exacte, l’action de candidature, `lang/dir` corrects et aucun débordement. Les tentatives de navigation à froid en serveur de développement ont aussi dépassé le délai initial de 30 secondes : les résumés restent partiels/en échec, sans transformer ces tentatives en recette réussie ni en mesure de performance de production.

Les binaires Playwright gérés n’étaient pas installés ; les essais suivants utilisent le Chromium système existant `/usr/bin/chromium`. Les clés machine locales anon/service arrivaient à expiration au bout de huit heures et ont été renouvelées dans la seule cohorte possédée. Les utilisateurs ont conservé leur identité et leur MFA.

Preuves : [préparation](evidence/browser/preparation.json), [résumé partiel initial](evidence/browser/baseline/summary.json), [activation non exécutée et garde reproduite](evidence/browser/activation/first-summary.json). Les captures ne contiennent ni code privé d’invitation ni session.

Vérification des gardes des outils : `node --test tests/e2e/helpers/franchise-final-safety.test.mjs` : **3 tests PASS**. Une invocation production, une invocation sans coordination et une source implicite sont refusées.

## Recette finale

La recette du candidat intégré sera ajoutée avec son commit, son arbre applicatif et les migrations exactes. Ce journal de préparation ne certifie ni les intégrations hébergées, ni une signature juridique, ni le parcours complet.

## Candidat intermédiaire optimisé `79a97ad`

Le build complet, avec TypeScript actif, passe sur `79a97ad97220c5e4b61a9b8a3d889b1043ea6dba` (arbre applicatif `8fcc61239df657e3e16110acc09625418e7ed888`). Les 507 migrations historiques ont conservé leurs empreintes ; les 26 nouvelles migrations appliquées par l’intégration donnent 533 migrations. L’outil de recette a adopté le reçu vérifié sans rejouer le DDL. Ce contrôle n’est pas un rejeu vierge ni une recette hébergée.

L’organisation de test a été activée par une demande administrative sensible, deux approbateurs indépendants du demandeur et l’exécution native de la décision. L’auto-approbation est refusée. Cette opération ne certifie pas les identifiants légaux et ne signe aucun contrat.

La première activation de mandat a ensuite réussi dans la vraie interface, en mode **NON_CONTRACTUAL_DEMO** explicitement confirmé. Une tentative contractuelle AAL2 a été refusée pour absence de mandat signé. Le retour au workspace présente cependant un refus réel : le rôle Owner et le mandat Franchisé actifs ne disposent pas encore de la délégation `catalog_library_mandates` pour leur organisation. `franchise_catalog_scope` vaut vrai, mais le reader catalogue exige aussi `CATALOG_VIEW_DRAFT` et renvoie `42501`. Aucune ligne de permission n’a été insérée manuellement pour masquer cette précondition. Le résumé d’activation reste donc partiel, et la matrice principale attend le raccordement gouverné du catalogue.

Les contrôles indépendants de cette précondition passent : **huit pages globales**, Notifications, Organisation, Sécurité et Sessions, en FR/AR à 390 px ; navigation de retour Franchisé, `lang/dir` corrects, aucun débordement et aucune erreur JavaScript. Ces huit contrôles concernent rôle, navigation et disposition, sans mutation des facteurs ou des sessions.

Preuves : [build et empreinte du journal](evidence/browser/core-build/build.json), [schéma adopté](evidence/browser/core-build/schema-adoption.json), [activation partielle](evidence/browser/activation-core/first-summary.json), [cause de refus catalogue reproduite](evidence/browser/catalog-scope-reproduction.json), [huit pages globales](evidence/browser/global-core/summary.json).

Les outils disposent désormais de **quatre tests de garde PASS**, dont un refus d’arrêter le PostgREST possédé sans coordination supplémentaire explicite. Aucun arrêt de service de recette n’a encore été exécuté à cette étape.
