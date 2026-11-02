# Finance Sous-traitant — lot fonctionnel et recette en cours

Source : `7e01276`, branche `codex/provider-finance-20261102`. Aucun déploiement ni modification de base distante. Ce lot sépare les encaissements Client vers Prestataire et les règlements de commissions à Matricia.

## Changements

- Déclarations privées avec justificatif réellement analysé ; aucune écriture de cash ou extinction de dette avant validation Finance AAL2 indépendante. Les encaissements exigent aussi la confirmation ou contestation du Client, sans membre de la société Provider parmi les confirmateurs.
- Pré-relevés ligne par ligne, fenêtre contradictoire, report des contestations, clôture automatique, numérotation gouvernée et documents distincts relevé/facture. Politique de clôture validée par deux acteurs ; identité juridique, fiscalité et séries approuvées requises, sans données inventées.
- Rappels durables et échéanciers dont seules les échéances respectées couvrent l'exigible. Les paiements partiels ne déplacent jamais l'échéance originale.
- Historiques transportés intégralement, pagination UI, montants exacts et devise du contrat/de la facture déterminée côté serveur. Formulaires FR/AR, navigation vers la console Finance indépendante et état de PDF distinct de son émission métier.
- Bridge des conséquences définitives de litige, exclusion avant finalité/appel, compensation par avoir gouverné après émission. La revue indépendante a demandé de renforcer l'attribution du bénéficiaire et la version contractuelle d'origine avant clôture finale.

## Vérifications réellement exécutées du premier lot40000–40400

Tests séparés, chacun dans une unique transaction entièrement annulée sur une cible locale explicitement possédée, schéma de base458. Aucun COMMIT envoyé. Les empreintes de schéma avant/après sont identiques.

| Fichier | Résultat | Preuve |
|---|---|---|
|0347_provider_independent_finance|27/27 PASS|[Reçu](evidence/finance/independent-initial-27.json)|
|0347_provider_monthly_closing|37/37 PASS|[Reçu](evidence/finance/monthly-initial-37.json)|
|0168_provider_credit_notes_collection|16/16 PASS|[Reçu](evidence/finance/legacy0168-initial-16.json)|
|0210_provider_durable_payment_intents|13/13 PASS|[Reçu](evidence/finance/legacy0210-initial-13.json)|

Commandes : `APP_ENV=development node /workspace/provider-identity/work/identity-proof/run-rollback.mjs --browser-root=/workspace/client-browser-verification --migration=<40000…40400> --test=<un seul fichier> --output=<work/run>`. Le runner partagé de l'intégration permet la même vérification avec garde de token explicite. Ces reçus ne remplacent pas le rejeu intégral sur base neuve.

Unitaires au redémarrage : quatre fichiers actions Provider/Admin, console et workspace, **20 tests PASS** (`pnpm --filter @matricia/web exec vitest run ... --maxWorkers=2`). Worker et PDF avaient passé respectivement2 et6 tests sur la version précédente ; ils seront rejoués au gel du lot. Le contrôle TypeScript intégré, le build et les recettes navigateur restent à exécuter.

## Contre-revue en cours

Les migrations40500+ et contre-tests ferment les chemins legacy révélés par la revue indépendante : échéancier auto-approuvé ou sans MFA, avoir auto-émis, collection qui ignore un plan respecté, allocation partielle impossible à compléter, émission manuelle contournant la fenêtre contradictoire, décisions contradictoires produisant un faux audit, références/devises hors première page et reprise équitable du scheduler sous panne. Aucun de ces points n'est déclaré clos par les seuls reçus ci-dessus.

Intégrations réelles non certifiées : scanner de production, éditeur/numérotation et paramètres fiscaux approuvés, transport email, exécution hébergée des workers. Les données et signatures synthétiques des fixtures sont explicitement de test.
