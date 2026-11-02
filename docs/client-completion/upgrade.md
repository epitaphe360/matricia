# Client C11 — changement immédiat financé

Le mode `FULL_NEW_CYCLE` est implémenté, sans règle commerciale publiée par migration. Deux responsables Finance distincts doivent proposer/approuver une règle versionnée FR/AR, liée aux versions source/cible, à une périodicité et à un délai de validité. Le Client reçoit un calcul exact, accepte son empreinte et les conditions, puis utilise le checkout PSP durable existant.

Ce mode redémarre une période entière au prix intégral de la version cible. Il n’applique aucun remboursement ou prorata implicite du temps restant. Les crédits déjà payés gardent leurs échéances et leur validité ; la nouvelle période entièrement payée produit ses propres crédits. Ces conséquences sont visibles avant acceptation. Aucun tarif, quota, règle commerciale ou compte externe n’est créé par ce lot.

Les capacités transactionnelles de préparation restent privées à PostgreSQL. Le navigateur ne peut ni ouvrir le contrôle `ACTIVE`, ni choisir un autre plan/montant, ni fabriquer une preuve. Le webhook/capture vérifié doit correspondre exactement à la source, à la préparation, à la version et aux conditions acceptées. Les anciens paiements/cycles et les ledgers restent immuables. Le nouveau cycle suit le validateur canonique et les exécuteurs de crédits existants ; un incident ou une source périmée reste dans le rapprochement existant.

## Vérifications réalisées

- Migration `20261102031000` appliquée dans la seule base jetable `client_upgrade_verify_20261102`, copie locale du candidat isolé. Aucune migration sur le Supabase partagé/distant.
- `0331_governed_immediate_subscription_upgrade.test.sql` : **29 assertions réussies**. Le scénario crée un paiement source canonique, publie une règle par deux acteurs, refuse AAL1, l’auto-approbation, l’absence de consentement et un hash divergent ; prépare un intent SANDBOX, exécute la capture SQL de test, applique le paiement vérifié, puis vérifie le rejeu et les droits. Les deux allocations de crédits réellement payées (10 +20) sont produites par le worker natif sans doublon.
- Tests unitaires ciblés (API, devis de changement, formatage monétaire) : **19 réussis**. Cas JPY/KWD, négatif et montant supérieur à `2^53`, refus avant PSP et cible prise dans la réponse serveur.
- Lint ciblé exécuté ; le build/typecheck consolidé appartient à l’intégrateur.

Cette preuve SQL utilise des identités synthétiques, des rôles/sessions SQL de laboratoire, le port de paiement DEV/SANDBOX et une transaction annulée. Elle ne certifie ni un webhook reçu sur un PSP externe, ni la délivrabilité, ni une recette navigateur de paiement réel.

## Réserve de portée

Le paiement différentiel `PROPORTIONAL_REMAINING` n’est pas implémenté par ce mode. Il exige une politique approuvée et un modèle de financement composé reliant paiement initial et complément, avec calendrier de crédits et allocations économiques proportionnels. Ouvrir simplement le statut ACTIVE ou remplacer le plan sans ces preuves serait incorrect. Le mode de redémarrage intégral ne doit donc pas être présenté comme la clôture de tous les changements au prorata de C11.
