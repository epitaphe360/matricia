# Contrats, missions et livraisons Sous-traitant

Base : `7e01276`, lot Client préservé ; branche `codex/provider-delivery-20261102`.

| Constat | Modification | Vérification et limite |
| --- | --- | --- |
| D4 — Réception impossible après rejet de V1 | Réceptions distinctes par version de livraison ; décisions antérieures immuables ; formulaire Client lié à la version effectivement examinée ; reprise des corrections déjà soumises avant migration | Cycle SQL natif V1 rejetée → V2 soumise → réception V2 et maintien du rejet V1 vérifié dans le premier replay ; extensions ultérieures à rejouer après intégration |
| D5 — Jalon rejeté non resoumettable | Commande corrective motivée, instantané du jalon rejeté, historique immuable, audit/outbox, nouvelle soumission et contrôle de version | Soumission, rejet Client, correction Technician affecté et rejeu idempotent : premier replay réussi |
| D6 — Dossier contractuel incomplet avant signature | Routes liste/détail Contrats ; parties, clauses, demande/devis figés, livrables, exclusions, paiement, critères, corrections, pénalités, historique et preuves de signature réellement enregistrées | Tests de projection avant signature et 1 001 lignes contractuelles réussis ; fournisseur de signature réel toujours à configurer et recetter |
| D7 — Avenants seulement en lecture | Proposition Owner/Manager AAL2 contre version/hash exacts ; monnaie dérivée du contrat ; prix exact ; livrables supplémentaires structurés ; brouillons et motif/périmètre visibles ; commission dérivée de la version gouvernée | Actions positives/négatives FR/AR et devise TND à trois décimales vérifiées. **Exécution des livrables supplémentaires dans la mission après signature encore à compléter dans le lot suivant ; D7 reste ouvert** |
| D9 — Technician non limité aux affectations | Affectations persistées gérées par Owner/Manager ; RLS des missions/contrats/relations et commandes/preuves Storage utilisent cette affectation ; révocation immédiate | Deux techniciens de même organisation : lectures, soumission par ID connu et auto-affectation refusées ; affectation, rejeu et révocation autorisés : premier replay réussi |
| D10 — Commentaires et preuves non consultables | Critères et commentaires par version, originaux privés uniquement CLEAN, historique des décisions et corrections de jalon | Route de téléchargement : 5 tests de droits, panne, quarantaine et URL limitée ; projection historique SQL ajoutée après le premier replay, à rejouer |
| D12 — Relations et détails tronqués | Transport paginé et listes d’identifiants bornées ; détail contractuel direct au-delà de la première page ; recherche de missions avant pagination ; compteurs agrégés sous RLS | 1 001 relations et 101e contrat testés ; recherche/compteurs SQL ajoutés au test natif étendu, à rejouer |

## Résultats réellement exécutés

- `APP_ENV=development node scripts/validate-local-migration-replay.mjs --test=0348_provider_versioned_receipts_assignments.test.sql` : **459 migrations, 1 fichier SQL, 62 assertions PASS, nettoyage PASS**. Preuve : [delivery-initial-replay.json](evidence/delivery-initial-replay.json). Ce reçu contient les empreintes de la première version de `41000` et du test avant extension. Il ne certifie pas les modifications postérieures, ni `41200`/`41300`/`41400`.
- `pnpm --filter @matricia/web exec vitest run modules/provider/data/missions modules/provider/screens/missions modules/shared/lib/contracts-missions modules/client/screens/missions 'app/api/provider/delivery-proofs/[proofId]/route.test.ts' --maxWorkers=2` : **24 fichiers, 121 tests PASS**. Journal local : `/tmp/provider-delivery-final-unit.log`.
- `git diff --check` : PASS.
- `pnpm --filter @matricia/web typecheck` : lancé ; résultat global encore en attente au point de sauvegarde. Il n’est pas déclaré réussi.

Les nouveaux scénarios SQL étendus doivent être rejoués sur la branche intégrée. La matrice navigateur et le build intégrés restent à effectuer. Aucune base distante ni production n’a été modifiée. Aucun mock n’est présenté comme une signature contractuelle ou un verdict antivirus réel.
