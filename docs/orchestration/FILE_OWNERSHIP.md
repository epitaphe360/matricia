# File ownership — règles de collaboration

## Règle absolue

Un fichier, une migration ou un artefact partagé ne possède qu’un seul propriétaire en écriture à un instant donné. Les autres agents travaillent en lecture seule et transmettent leurs propositions au propriétaire. Tout transfert est consigné avant modification.

Les agents de sécurité, qualité, finance et tests auditent indépendamment le code et ouvrent des findings avec preuves ; ils ne corrigent pas directement le périmètre audité.

## Périmètres recommandés

| Propriétaire | Écriture exclusive |
|---|---|
| Integrator | Racine, workspace, lockfile, CI, `PROJECT_STATE.md`, registre d’ownership |
| Database architect | `supabase/migrations/**`, conventions et plan du schéma |
| RLS/RBAC agent | Policies et tests SQL/RLS dédiés, après réservation des fichiers |
| Event/workflow architect | Outbox, workers, retries et idempotence |
| Domain agents | Un module dédié sous `packages/domain`, `application`, `contracts` et tests correspondants |
| Infrastructure agents | Adaptateurs dédiés sous `packages/infrastructure` et fonctions Supabase attribuées |
| Web/UI agents | Routes ou composants explicitement assignés sous `apps/web` et `packages/ui/forms` |
| Seed/catalog agent | `supabase/seed/**`, import catalogue et validateurs de manifeste |
| Documentation owner | ADR, specs et registres explicitement attribués |
| Auditors | Rapports/findings seulement ; code audité en lecture seule |

## Protocole

1. Avant une vague, inscrire agent, chemins, mode, dépendances et ordre d’intégration dans la carte CSV d’orchestration.
2. Réserver des chemins étroits ; éviter les globs couvrant tout le dépôt.
3. Une migration appartient intégralement à un agent. Les ajouts d’un autre domaine utilisent une nouvelle migration.
4. Les fichiers partagés sont modifiés par l’intégrateur à partir de patchs ou handoffs des agents.
5. Chaque handoff liste fichiers, migrations, tests, décisions, risques et dépendances restantes.
6. Intégrer dans l’ordre des dépendances, puis exécuter les gates sur l’état combiné.
7. Libérer explicitement le périmètre à la fin de la vague.

## Prévention des conflits

- Une branche/worktree par périmètre indépendant lorsqu’un dépôt Git sain est disponible.
- Aucun reformatage global, renommage transversal ou mise à jour de lockfile par un agent de domaine.
- Aucun amendement silencieux d’une migration déjà appliquée ; créer une migration corrective.
- Aucun agent ne restaure, écrase ou supprime les modifications d’un autre.
- Une collision détectée suspend uniquement le fichier concerné et remonte à l’intégrateur ; les autres travaux indépendants continuent.

