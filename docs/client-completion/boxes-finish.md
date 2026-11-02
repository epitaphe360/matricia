# C13–C17 — enveloppes et réalisation des avantages

Branche de domaine : `codex/client-boxes-finish-20261102`, base `f389886`.
Aucune intervention distante ni donnée de production. Les recettes SQL sont transactionnelles et annulées.

## Corrections livrées

- `30000` : lecture des seules enveloppes personnelles et réservation/libération par un membre Buyer. Une capacité interne liée au PID, à la transaction, à l’acteur, au dossier et à la corrélation traverse le moteur FEFO existant. Le rôle Buyer ne reçoit aucun accès général au portefeuille, aux autres membres ou aux données financières.
- `30010` : gel du moteur/configuration natifs dans la promesse avant le premier appel PSP puis dans la réservation. L’exécution conserve A après publication de B. Les droits, la session et AAL2 sont revérifiés après les attentes de verrous. Une offre avec avantage non configuré bloque le checkout avant PSP.
- `30030` : écran FR/AR des listes d’attente, confirmation de place, annulation, expiration avec restitution exacte des lots et lancement des effets natifs. Un Buyer ne peut lancer l’avantage d’un autre membre. La demande RFQ reprend le formulaire métier normal ; le serveur dérive la source catalogue et crée un vrai dossier `INFORMATION_REQUIRED` lorsque le questionnaire reste à compléter.
- `30040` : après activation réelle d’une fonction, l’interface opérationnelle donne accès au compte rendu puis à la réception indépendante. Le simple effet technique ne vaut pas réception ni consommation.
- `31110` : une montée en gamme au prorata conserve la Box et le budget de l’ancêtre réellement payé intégralement. Aucun budget, crédit, sélection ou moteur cible n’est accordé par le seul paiement différentiel. Dépend de `31100` du domaine Abonnements.

Les remboursements consommés sont réalisés dans le domaine indépendant `30020`, documenté dans `refunds.md` : demande, politique explicitement approuvée, décision Finance indépendante et contrepassation exacte des crédits et allocations/P&L.

## Vérifications exécutées

| Recette | Résultat observé | Preuve |
| --- | --- | --- |
| 0256 configuration financée (ordre des approbations réparé) | 38 assertions réussies | Clone isolé piloté par l’intégrateur |
| 0330 membres / séparation du portefeuille | Recette en cours de confirmation finale | L’assertion privée est exécutée par le propriétaire de fixture ; aucun droit de schéma privé ajouté au navigateur |
| 0331 achat de A puis publication de B | 16 assertions réussies | Clone isolé piloté par l’intégrateur |
| 0333 capacité, attente, expiration Buyer, reprise | 28 assertions réussies | `/tmp/matricia-refunds0332/parent0333.log` |
| 0334 RFQ natif, vrai dossier, source catalogue et isolation | 18 assertions réussies | `/tmp/matricia-refunds0332/parent0334.log` |
| 0335 activation A → compte rendu → réception indépendante → consommation | 27 assertions réussies | `/tmp/matricia-refunds0332/parent0335.log` |
| 0336 Box acquise après montée en gamme au prorata | En cours | Clone isolé, aucun changement du conteneur de l’intégrateur |
| Actions et rendu FR/AR, menu/recherche, formulaire RFQ existant | 40 tests réussis, 9 fichiers | `/tmp/client-boxes-all-unit.log` |
| TypeScript Web | Réussi | `/tmp/client-boxes-tsc.log` |
| ESLint ciblé | Réussi | `/tmp/client-boxes-final-lint.log` |

## Limites de certification

Les identités/JWT des fixtures SQL et le PSP DEMO/SANDBOX sont synthétiques ; ces tests prouvent les commandes, l’isolation et les effets transactionnels, pas l’identité d’un utilisateur réel ni une signature PSP distante. La recette visuelle navigateur et la revue indépendante sont intégrées séparément avant clôture. Aucun tarif, texte contractuel, règle de remboursement ou montée en gamme de production n’est publié par ces migrations. Les conditions commerciales doivent être approuvées via leur workflow avant vente.
