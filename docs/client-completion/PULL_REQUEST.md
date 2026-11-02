Les parcours Client perdaient des brouillons ou du contexte, ne permettaient pas de reprendre exactement une opération approuvée et exposaient des avantages Box sans commandes adaptées aux membres. Ce lot raccorde ces parcours aux commandes métier, aux droits et aux sources immuables existantes.

- Questionnaires conditionnels, reprise et sauvegarde après perte de réseau ; filtres et requêtes par organisation ; projets/tâches, cibles et historiques complets.
- Comparaison de devis et mission dérivée du contrat, litiges et preuves privées ; montants exacts par devise, y compris au-delà de `2^53`.
- Approbations indépendantes et reprise de l’intention exacte, achats de crédits, renouvellement et changements payés gouvernés.
- Enveloppes Buyer, Box acquise exacte, exécution réelle/RFQ, attente/expiration, réception et retours de crédits avec contrepassations et attribution comptable exactes.
- Parrainage consenti, décision distincte de l’émission Finance, ROI/économies et notifications ; FR/AR, RTL, erreurs précises et menus utilisables sur mobile/tablette.
- Corrections communes de concurrence audit/quota et de récursion RLS des réservations, sans élargir les habilitations.

Vérification locale : types, lint et build avec tous les contrôles activés ; 2 639 tests Web hors PDF, 10 tests PDF vérifiés séparément, 137 tests packages, 102 worker, 3 intégration et 31 tooling. Les derniers changements disposent de groupes ciblés supplémentaires, dont les décomptes se recouvrent. Rejeu intégral **457 migrations / 33 fichiers SQL / 873 assertions**, RLS actif sur les 623 tables publiques, pgTAP fermé aux rôles API, nettoyage réussi. Trois cohortes natives simultanées confirment le refus de quota sans interblocage ni double création.

La [traçabilité C01–C26](REPORT.md), les [commandes et limites de recette](VALIDATION.md), la [revue indépendante](independent-review.md) et les [preuves](evidence/) précisent le périmètre de chaque résultat. Les fixtures et intégrations DEMO/SANDBOX restent exclusivement locales et synthétiques.

La contre-recette navigateur sur le clone canonique, le parcours Buyer positif et les contrôles axe-core restent en cours ; la PR reste en brouillon jusqu’à leur résultat.

La signature distante nécessite toujours un fournisseur et des niveaux retenus. Les conditions commerciales, textes légaux et traductions approuvées ne sont pas inventés ; aucune règle commerciale n’est publiée automatiquement. La certification Supabase/Vercel/worker/PSP/email/scanner hébergée et le certificat global Gold Master restent ouverts. Le validateur de livraison globale demeure bloquant. Aucun déploiement de production ni fusion n’est inclus.
