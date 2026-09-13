# V4.1 — Export, réversibilité et fermeture d’organisation

1. Vérifier l’autorité tenant et AAL2; figer le périmètre d’export et la politique de conservation.
2. Vérifier les legal holds. Un hold bloque anonymisation et purge.
3. Produire séparément données d’organisation, contrats, factures, preuves et configuration autorisée; enregistrer SHA-256, taille et rétention.
4. Faire contrôler l’export par un second acteur. Remettre via un canal temporaire contrôlé.
5. Révoquer sessions et tokens avec preuve externe; archiver les pièces légales; anonymiser/purger uniquement après échéance et validation.
6. Conserver les audit events, preuves légales et ledgers immuables selon leur base de conservation.

Les exports ne contiennent jamais de secrets de plateforme ni de données d’un autre tenant. Toute exécution Auth/storage externe non prouvée reste `REQUIRED_NOT_COMPLETED`.
