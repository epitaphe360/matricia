# Franchisé : périmètre opérationnel et intégrité financière

Source : `df67da4`, fusion des lots Client et Sous-traitant. Travail isolé sur `codex/franchise-operations-20261103` ; aucune production modifiée.

## Causes corrigées

| Constat | Cause reproduite dans le code | Correction et preuve |
|---|---|---|
| FA02/FA03 | Une panne Auth retournait un tableau opérationnel vide ; listes bornées silencieusement à 50/100/200 lignes | Incident explicite avant toute requête métier ; pages serveur ordonnées de 100 lignes, filtres parent bornés à 80 identifiants, aucune première page conservée si une suivante échoue. Tests DAL et collecte. |
| FA03 | Missions chargées sans bibliothèque, documents chargés globalement, capacités historiques plutôt que courantes | Projection de missions limitée au mandat choisi, contrôle des identifiants de bibliothèque/franchise reçus ; documents/capacités/qualifications issus des dossiers natifs du mandat. Les autres mandats lisibles ne doivent pas se mélanger au contexte sélectionné ; les RLS générales ne sont pas élargies. |
| FA03 | Urgence de demande dérivée d'une version historique arbitraire | Projection de `current_version_id` et résolution de cette version exacte. Test où une ancienne version arrive après la courante. |
| Coffre | Les références textuelles d'activité CRM étaient présentées comme documents du coffre | Seuls les documents natifs entrent dans le coffre. Les références CRM restent consultables dans la chronologie du dossier. Une panne CRM ne masque pas les documents natifs disponibles ; une panne documentaire ne devient pas « aucun document ». |
| FA04 | La prochaine version générée entrait dans l'identité de la commande de clôture | Hash de commande stable fondé sur l'intention ; hash du contenu clôturé et historique immuable conservés ; compatibilité explicite des clés déjà terminées ; protections de rapprochement crédit conservées. |
| FA04 | Un rejeu de paiement vérifiait le solde déjà consommé avant de retrouver son reçu ; même journal réutilisable avec autre clé | Rejeu du reçu avant le contrôle du solde ; verrou de journal et contrôle anti-réutilisation global, écriture native de versement exacte et revue indépendante du comptabilisateur. |
| FA04 | Montants, sources et catégories P&L sans rapprochement réel avec les écritures | Journal de charge net exact, date civile réelle, référence canonique, classification par un autre acteur Finance AAL2 ; journal consommé une fois ; correction append-only avec catégorie et montant d'origine. La TVA comptabilisée séparément sur un compte d'actif n'est pas une charge. |
| FA04 | Un journal générique pouvait être présenté comme preuve d'encaissement HT acquis | Refus explicite du revenu legacy non rapproché. Le chantier de rapprochement natif du crédit est distinct (`45220+`, test `0364`) ; ce refus seul ne certifie pas sa réalisation ni un profit distribuable positif. |
| Finance UI | Dernier relevé déjà clôturé nommé « Pré-relevé » ; montants systématiquement divisés par 100 | Tous les relevés clôturés restent des relevés. Présentation monétaire exacte partagée avec exposants ISO (JPY/TND/KWD), signes et grandes valeurs, FR/AR. Colonne nommée « Montant ». |
| États partiels | Zéro alerte présenté pendant une panne CRM ; finance bloquée si seule la supervision métier échouait | Alertes non disponibles au lieu de zéro rassurant ; finances disponibles si leur source gouvernance est chargée ; propositions volume dépendantes de la supervision métier. |

## Vérification de ce lot

- 29 tests ciblés réussis dans cinq fichiers (DAL, collecte, monnaie, projection et composants), dernier contrôle avant le changement limité de l'en-tête « Montant ».
- Lint ciblé réussi ; contrôle TypeScript lancé mais son résultat final doit être lu dans le reçu d'intégration du parent.
- Test SQL `0362` ajouté : vrais acteurs de test, book ouvert par RPC, journal de charge par commande native, revue indépendante, montant HT/TVA séparé, duplication refusée, clôture historique d'une perte réelle, rejeu exact et AAL2. Aucun ledger injecté, aucun trigger désactivé. **À exécuter sur la base jetable d'intégration ; aucun succès SQL local revendiqué à ce stade.**
- Le test de perte n'est pas une preuve de profit positif ni de versement positif. Ceux-ci appartiennent à la recette native de rapprochement `0364`.

## Contraintes préservées

MFA/AAL2, habilitations serveur, isolation RLS, journaux et allocations immuables, audit/outbox, règles IT Hatim 50 % / NEOXA 50 % / Asma 0 % avec droit d'entrée nul. Pas de taux ni de prix fiscal inventé. Aucune date de production déplacée pour faire aboutir une clôture.

La recette navigateur et les contrôles SQL d'intégration devront citer leur candidat exact. Ce rapport ne certifie pas les intégrations hébergées, les conditions légales ou une mise en production.

## Extension des listes et états natifs d’invitation

Le CRM, les relances, le digest et les plans correctifs utilisent également une collecte ordonnée par pages. Le plan correctif accepte le `franchiseId` du mandat sélectionné avant la pagination ; le chargeur de page doit transmettre cette valeur. Les rejets de transport sont contenus en incident technique ; une réponse Auth 503 n’est pas transformée en déconnexion. Les relances exposées sont limitées aux prospects réellement chargés dans ce périmètre.

Les dossiers CRM présentent maintenant le dernier état de la vraie invitation (`QUEUED`, acquittement du service d’envoi, ouverture, inscription, expiration, révocation) et son mode. Un test non contractuel reste explicitement marqué ; un prospect sans invitation n’implique aucun envoi. Cette projection nécessite la migration du lot Invitations `45300+` et ne lit aucun token privé.

Preuves complémentaires : six tests de lecteurs (301 prospects, échec de seconde page, Auth 503/401/rejet, deux périmètres de plans), quatre tests de libellés d’invitation et reprise du groupe opérationnel. Le reçu SQL final de `0362` doit provenir de l’intégration : le premier passage avait correctement exclu une charge créée après une coupure historique trop ancienne ; le correctif de fixture fige maintenant la coupure après la commande native, sans modifier les dates de création.
