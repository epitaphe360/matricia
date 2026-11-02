# Revue indépendante — Sous-traitant

Auteur : `/root/client_browser_finish`, 2 novembre 2026, lecture seule. Aucun test SQL ou navigateur de ces lots exécuté par le réviseur. Sources figées : litiges `78fedaf6f62f9ac855835966bcf41c76376bc4e0`, entrée `a350abaac0a109de2dcaa445b5024acbdfbca0e9`.

Empreintes des jeux relus : `359061925fe9807d0ca77fea3028160eb016556484492374df651a14c7d80439` (litiges, 9 fichiers) et `473de1bdb8687801f8444d5db7c6e3320b9000abba955328ecc107461affe94d` (entrée, 6 fichiers).

| Référence | Constat indépendant | Correction en cours / condition de clôture |
|---|---|---|
| R01 P1 | ActionPanel omet contexte/locale : sélecteurs de preuves jamais rendus | Branchement `35e469f` ; 3 tests de composant FR/AR exécutés par l'auteur contexte. Recette native intégrée attendue. |
| R02 P1 | Appel d'un acteur membre des deux parties attribué au Client malgré sélection explicite Provider | Primitive legacy corrigée pour reprendre la partie canonique. Test composite natif encore attendu. |
| R03 P2 | Rejeu d'une réponse dépend de l'éligibilité mutable du document avant lecture du reçu | Enveloppe d'idempotence liée à l'acteur et au dossier, avant résolution des nouvelles sources. Test après expiration/quarantaine attendu. |
| R04 P2 | Calendrier invalide ou durée >3650 acceptés à l'ouverture puis réponse impossible | Validation prospective de la proposition de modèle et de la politique à l'ouverture ; calendrier résolu figé. Rejeu natif des refus attendu. |
| R05 P2 | Formulaire d'appel présenté aux rôles Viewer/Accounting refusés au serveur | Capacité alignée sur Owner/Admin/Manager ; nouveaux tests des quatre rôles non gestionnaires à exécuter. |
| R06 P1 | Renouvellement d'une famille documentaire lié à B peut valider A sans lien courant vers A | Migration forward-only38300 (`fa42486`) exige le lien d'applicabilité explicite. Test A/B ajouté à0345, rejeu attendu. |
| R07 P2 | Policy work_scope appelle un helper privé non exécutable par les rôles API | Migration38300 conserve la séparation des droits via prédicat plateforme autorisé. Test Admin non membre/Provider étranger ajouté à0345, rejeu attendu. |

Le réviseur n'a démontré aucune fuite directe interparties par les chemins canoniques de téléchargement : AAL2 et visibilité précèdent les grants, les buckets/MIME/tailles sont bornés et l'empreinte des octets téléchargés est recalculée. Cette appréciation statique ne vaut pas certification de sécurité globale. Les corrections ne seront closes qu'après les contre-tests correspondants.

Contre-vérification par l'auteur du lot litiges : [69 assertions SQL](evidence/disputes/reviewed-69-receipt.json) avec rôles SQL natifs, sources Provider réellement déposées/scannées/revues dans la fixture de test, message envoyé dans un nouveau fil après contrat, livraison versionnée, expiration par franchissement réel de date civile, rejeu du reçu et appel d'un acteur membre des deux parties. Les empreintes avant/après sont identiques et aucun COMMIT n'a été envoyé. Le reçu lie les versions exactes des fichiers ; le premier reçu56 reste une preuve d'étape antérieure. Les checks de calendrier purs incluent vendredi→mardi, fermeture explicite et DST. Les nouveaux refus prospectifs de modèle et la lecture des litiges par Technician après affectation restent à étendre en recette native.

Contre-tests UI/action : 5 fichiers, 30 tests réussis (`/tmp/provider-root-disputes-reviewed-unit.log`), dont ActionPanel FR/AR avec véritables sélecteurs/partie cachée/consentement, quatre rôles non gestionnaires sans appel proposé, incident auth distingué d'une déconnexion et téléchargement exact contrôlé. Ce sont des tests de composants et de commandes, pas la recette navigateur finale.
