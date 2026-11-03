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
