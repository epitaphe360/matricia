# Sous-traitant — entrée, qualification et pièces

Base préservée : `7e01276`. Autorité : AGENTS.md et Gold Master V4 FINAL §§15/17, MAT-FUNC-020/027/028/055. Aucun accès à une base distante, aucune approbation ni donnée commerciale publiée créée.

## Résultat

- Questionnaire Provider réel via `/[locale]/sous-traitant/questionnaires`, utilisant les sessions, sauvegardes et soumissions versionnées existantes. Bibliothèques limitées aux services demandés, audience vérifiée aux commandes Provider, rôles de lecture/édition conservés. Le moteur et l’éditeur Client gardent leurs paramètres par défaut.
- Réutilisation des justificatifs Provider propres, privés et du même tenant dans les questions documentaires ; aucune preuve en quarantaine proposée.
- Éligibilité calculée avec la version documentaire courante par famille. Les obligations de service historiques restent applicables à un renouvellement qui omettrait son lien. Les autres contrôles d’identité, de finance, de décision humaine et de scan demeurent.
- Capacité et délai lus depuis le même choix effectif service/global que l’éligibilité SQL. Motifs, conditions, expiration et version de qualification visibles.
- Coffre filtré avant pagination sur familles courantes, certifications/références paginées, historique immuable accessible depuis chaque pièce. Complétude fondée sur les pièces légales, fiscales et assurance vérifiées et propres.
- Upload rejouable : clé stable, réservation et chemin conservés, hash lié à la réservation, aucun remplacement d’objet lié.
- Rayon et taille de missions déclarés dans un historique immuable avec CAS, idempotence, audit et outbox. Ces déclarations ne donnent aucune approbation et ne changent pas les règles de matching.
- Liens qualification vers identité commune (autre lot) et questionnaire ; ancres document/capacité restaurées ; lecteurs sans contrôles de mutation actifs.

## Migrations et recette

`20261102038000_provider_entry_evidence_and_replay.sql`, `20261102038100_provider_questionnaire_evidence.sql`, `20261102038200_provider_work_scope_declarations.sql`.

`supabase/tests/0345_provider_entry_acceptance.test.sql` est transactionnel et autonome. Les commandes utilisent SET ROLE : questionnaire Provider complet, réservation/hash/rejeu, scan synthétique explicite via claim/complete, revue humaine AAL2, reprise des justificatifs historiques, portée par service, lecteur/étranger, RLS, immutabilité et CAS. Aucun trigger désactivé. Un verdict de fixture SQL n’est pas une certification d’antivirus externe.

## Vérifications à la remise initiale

- 17 fichiers / 97 tests ciblés réussis (qualification, moteur et UI questionnaires Client, pages de lecture et boards).
- Après les derniers ajouts : 3 fichiers / 22 tests réussis, incluant les liens Provider FR/AR et la lecture seule. Ces nombres se recouvrent et ne doivent pas être additionnés.
- `git diff --check` réussi.
- Typecheck complet et lint lancés ; résultats en attente lors du premier commit demandé pour intégration. Root coordonne le replay SQL canonique ; aucun Docker supplémentaire lancé par ce lot.

## Prérequis réels

Des questionnaires Provider publiés et approuvés dans les bibliothèques concernées doivent exister. En leur absence, l’interface donne l’état explicite et renvoie vers l’équipe de qualification. La qualification, les pièces et l’identité restent des décisions humaines selon leurs permissions/MFA ; ce lot ne les fabrique pas. La publication d’identité commune est livrée séparément par le propriétaire du lot identité.
