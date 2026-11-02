# Contexte, messagerie et équipe Sous-traitant

Base : lot Client `7e01276`, branche dédiée `codex/provider-context-20261102`.

Les constats D13/D17/D18 sont reproduits dans le code de cette base : le parcours
Provider appelle le lecteur historique limité à 300 messages et la boîte limitée
à 100 fils, ignore les pièces jointes, reconstruit la langue depuis une entrée de
menu et affiche les memberships de toutes les organisations autorisées. Une panne
de lecture des sessions ou rôles devient un tableau vide. Les tests ajoutés
exercent les contrats corrigés ; ils ne sont pas une observation du staging.

- La messagerie utilise la recherche serveur paginée (25 fils), l’historique par
  tuple horodatage/identifiant (50 messages), les pièces jointes, les brouillons,
  scans et téléchargements privés existants. Une conversation conserve recherche,
  page et organisation. Les pannes boîte, conversation, nouveau fil et notifications
  restent indépendantes et explicites.
- Un contexte d’organisation sélectionné est obligatoire dans ce parcours.
  La RPC `get_internal_message_thread_page_for_organization_v1` conserve le lecteur
  canonique et vérifie indépendamment le membership au participant sélectionné.
  Elle corrige la projection d’un acteur membre des deux parties : le lecteur
  historique choisissait la première organisation, ce qui faussait le rôle, la
  contrepartie et l’indicateur « mon message ». Aucun accès supplémentaire n’est
  accordé ; les ACL service/anon restent fermées et le curseur/scan restent ceux
  du lecteur canonique. Le centre partagé réutilise le même contexte explicite.
- Le changement FR/AR conserve le chemin et toute la query courante, y compris
  le dossier, les filtres, la page, la semaine et les microsecondes du curseur.
  Le composant client est sous Suspense conformément aux documents Next 16.
- L’équipe est chargée uniquement dans l’organisation explicitement sélectionnée,
  après membership actif vérifié, avec pages bornées et rôles composites complets.
  Une panne d’une page ne produit pas une équipe partielle présentée comme complète.
  Aucun identifiant utilisateur ou nom personnel supplémentaire n’est exposé.
- La liste des organisations est exhaustive par pages, sans ancien plafond 100.
  Les refus pour identifiant étranger, panne, choix nécessaire et absence réelle
  conservent leurs états distincts. Une erreur de détail ne devient plus un faux
  refus de périmètre.
- Les liens vers Contrats, Questionnaires de qualification et Identité commune
  sont reliés aux nouveaux parcours des lots correspondants. Les onglets de liste
  réinitialisent une page devenue incompatible lorsqu’un filtre change.

Validation exécutée : 8 fichiers unitaires/composants, **36 tests réussis**
(`/tmp/provider-context-unit-final2.log`). Le premier test existant de conversation
avait besoin du contexte App Router désormais requis par le vrai composant de
brouillons ; ce contexte a été ajouté au harness. Un attendu de traduction a été
aligné sur le libellé métier arabe existant « طلب العروض », sans modifier le produit
pour satisfaire l’attendu.

SQL0349 ajoute une reproduction du double membership, 301 messages durables,
refus d’organisation forgée/nulle/étrangère, ACL et search_path. Les fixtures sont
transactionnelles et conservent FK, triggers et RLS actifs. **Premier lancement
strict non exécuté** : la création locale Docker a expiré avant toute migration
(0 migration, 0 test SQL, nettoyage réussi). La preuve SQL et la recette navigateur
intégrée restent à exécuter sur la cible isolée de l’intégrateur ; aucune réussite
ni certification Supabase/Vercel distante n’est annoncée ici.
