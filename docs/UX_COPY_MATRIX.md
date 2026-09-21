# Matricia — matrice UX, terminologie et contenu public

Audit initial du code au 2026-09-15, sans modification du produit. Branche observée : `codex/audit-final-2026-09-15`; HEAD : `b4050fc3a122d1f61b86f819831991be7d3d5c1a`. Les constats « code » ne valent pas recette navigateur. Le déploiement indiqué n'a pas pu être ouvert par l'outil de lecture durant ce sous-audit; les observations visuelles distantes restent donc **non vérifiées**.

## Vocabulaire canonique FR / AR

| Concept | Français public | Français espace métier | Arabe | À éviter dans l'UI | Compatibilité technique |
|---|---|---|---|---|---|
| Organisation qui propose une prestation | **Professionnel** dans les promesses; **Prestataire** dans les parcours/actions | **Prestataire** | **مقدم الخدمة** | « Sous-traitant » comme terme générique public; alternance non motivée avec « fournisseur » | Conserver `provider`, `PROVIDER_*` et routes historiques `/sous-traitant` |
| Fournisseur au sens achats / AP | **Fournisseur** | **Fournisseur Matricia** ou **fournisseur d'achat** | **مورّد** | Employer « fournisseur » pour tout professionnel qualifié | Conserver tables procurement/vendors |
| Entreprise demandeuse | **Entreprise** / **Client** selon la phrase | **Client** | **العميل** / **المؤسسة** | « Acheteur » hors action d'achat précise | Conserver `CLIENT_*` |
| Consultation structurée | **Demande** / **consultation** | **Demande** | **طلب** / **استشارة** | RFQ comme libellé principal | Conserver `rfq` en backend |
| Référentiel métier | **Domaines et services** en présentation guidée | **Référentiel interne** en administration | **المجالات والخدمات** / **المرجع الداخلي** | « Catalogue » commercial, panier, annuaire | Conserver tables/routes catalogue privées et anciennes redirections |
| Qualification | **Profil vérifié selon le domaine** / **parcours de qualification** | **Qualification** | **تأهيل الملف حسب المجال** | « Certification absolue », « garanti » | Conserver statuts/règles/versions |
| Organisation franchisée | **Franchisé Matricia** | **Franchise** | **صاحب الامتياز** / **الامتياز** | Exposer accords internes | Conserver `FRANCHISE_*` |
| Solde promotionnel | **Crédits commerciaux** | **Crédits** | **أرصدة تجارية** | « Argent », « solde bancaire » | Conserver ledger credits |
| Diagnostic public | **Bilan indicatif** / **prédiagnostic** | **Analyse** / **diagnostic** | **تقييم أولي إرشادي** / **تحليل** | Score/certification/conformité non prouvés | Conserver `diagnostic` technique |

### Écarts terminologiques confirmés

- Navigation publique FR : `Fournisseurs` (`apps/web/modules/public/data/journey/copy.ts:4`) alors que le CTA dit `Proposer mes services` et les textes parlent de `professionnels` (`:8-9`).
- Home : `Commencer mon parcours fournisseur` (`copy.ts:13`), page cible titrée « parcours fournisseur » (`:42-43`), puis espace authentifié « Espace Sous-traitant » (`apps/web/modules/provider/screens/qualification/messages.ts:2`).
- Registre connecté : `Responsable Sous-traitant` (`apps/web/modules/shared/lib/i18n/dictionaries.ts:59`) et nombreuses entrées `Sous-traitants`, tandis que l'arabe utilise correctement `مقدم الخدمة`.
- Contact public FR présente `Parcours sous-traitant` (`apps/web/app/[locale]/(public)/contact/contact-form.tsx:10`), en contradiction avec la terminologie publique cible.

**Correction attendue P2** : adopter `Professionnels` dans la navigation et le discours, `Prestataire` dans les formulaires/parcours, réserver `Fournisseur` aux achats ou à un contexte contractuel précis, et garder « sous-traitant » uniquement là où la relation juridique le justifie.

## Matrice des écrans publics critiques

| Écran | État code observé | FR/AR et accessibilité | Gap / priorité | Preuve |
|---|---|---|---|---|
| Home `/[locale]` | Trois intentions fonctionnelles : diagnostic, proposer ses services, besoin précis. Promesse demandée précédente présente. Cinq grandes sections. | SSR, titres et liens sémantiques; contenu FR/AR. | **P1** : le cycle Matricia complet COMPRENDRE→STRUCTURER→MATCHER→COMPARER→CONTRACTUALISER→EXÉCUTER→SUIVRE n'est pas présenté; seulement trois étapes génériques. **P1** : aucune recherche universelle ni projection réelle des 10 domaines. **P2** : termes fournisseur/prestataire incohérents. | `apps/web/app/[locale]/(public)/page.tsx:9-15`; `apps/web/modules/public/data/journey/copy.ts:7-13,50-51` |
| Navigation publique | Logo→Home, 3 liens, langue, inscription, connexion et CTA diagnostic. Menu mobile compact. | `aria-expanded`, `aria-controls`, fermeture ESC et retour focus présents; cibles min. 44 px. | **P2** : pas d'état actif; menu ne se ferme pas explicitement au changement de route; pas de focus trap ni scroll lock; flèche CTA SVG non inversée en RTL. L'ancre `#comment-ca-marche` utilisée depuis une autre page dépend du comportement Next et doit être testée. | `apps/web/modules/public/ui/site/public-navigation.tsx:16-50,56` |
| Prestataire public `/fournisseur` | **Grand textarea principal**; sauvegarde uniquement une chaîne `matricia.provider-intent`; inscription ne transporte pas explicitement `next` vers qualification. Le compte existant le fait. | Label et description présents; aucune gestion d'erreur stockage/quota; page entière client-side. | **P1 prioritaire** : remplacer par sélection Domaine→Catégorie→Service, recherche, multi-sélection/chips, IDs structurés, fallback « Service non répertorié », TTL/version/reprise. **P1** : préserver l'intention et la destination pour inscription et compte existant. **P2** : réduire hauteur mobile. | `apps/web/app/[locale]/(public)/fournisseur/page.tsx:1,9-39` |
| Qualification connectée | Intention texte récupérée dans le résumé d'activité puis effacée après succès; service demandé par ID. | Formulaires étiquetés et cibles 44 px; FR/AR présents. | **P1** : les listes affichent uniquement `s.code`; les statuts capacité/document sont des codes anglais; `Global`, types de preuve, codes/versions techniques exposés. Relier les labels localisés module/catégorie/service et mapper les statuts. | `apps/web/modules/provider/screens/qualification/qualification-forms.tsx:17-23`; `messages.ts:2-3` |
| Services `/services` | Redirection vers besoin ou diagnostic; aucun écran de domaines/services. | Préserve `q` ou `library` en texte. | **P1** : la Home ne peut pas exposer les domaines réels via cette route. Une ancienne sélection `library=IT` devient le texte libre `IT`, pas un ID structuré. | `apps/web/app/[locale]/(public)/services/page.tsx:3-7` |
| Ancienne fiche `/services/[code]` | Recherche dans un JSON statique de 200 services, puis redirection au besoin avec **nom** du service. | 404 si code absent. | **P1** : transmet du texte localisé, pas l'ID/version/service canonique; provenance/génération du JSON non trouvée. | `apps/web/app/[locale]/(public)/services/[code]/page.tsx:2-8`; `apps/web/modules/public/data/catalogue/services.json` (200 métadonnées, non chargé comme questions) |
| Besoin précis `/besoin` | 4 étapes texte, brouillon v2 local avec TTL, récapitulatif et rattachement serveur après auth. | Labels/erreurs/état local non disponible; bouton retour; FR/AR. | **P1** : aucune classification visible domaine/catégorie/service, aucun « Voici ce que Matricia a compris » avec Modifier/Valider, pas de cahier des charges ni consultation. **P2** : le premier champ reste un grand textarea; aucun `dir` explicite sur le `main` de ce composant (hérité du layout seulement). | `apps/web/modules/public/ui/journey/need-flow.tsx:20-34`; `apps/web/app/[locale]/(public)/besoin/page.tsx:6-8` |
| Diagnostic public `/diagnostic` | 8 questions stables, branches limitées, autosave/reprise/TTL, trois priorités max, aucun faux constat si vide, rattachement serveur. | `dir`, radiogroup, `aria-live`, boutons et feedback FR/AR. | **P2 accessibilité** : les choix simples sont des `<button role="radio">`, mais aucun comportement clavier natif attendu d'un radiogroup (flèches/roving tabindex) n'est implémenté; tester lecteur d'écran. **P2 RTL** : flèches Lucide non inversées. **P1** : lien vers besoin ne transporte qu'un code de priorité, pas un contexte structuré vérifié. | `apps/web/modules/public/ui/journey/prediagnostic-flow.tsx:77-88,103-108` |
| Abonnements public | Projection serveur de plans publiables, prix non inventés; lien gestion séparé. | Cartes et CTA FR/AR. | **P1/P2** : vérifier la donnée réelle; si aucun plan publiable, l'empty state doit rester commercialement fini. Lien « gérer » pointe vers espace connecté sans condition visible. | `apps/web/app/[locale]/(public)/abonnements/page.tsx:35-39`; `apps/web/modules/public/data/subscriptions/repository.ts` |
| Contact | Formulaire réel, succès = enregistrement avec référence; ne prétend pas envoyer un email. | Champs étiquetés; honeypot attendu; erreurs résultat. | **P1** : raccorder la file support/email sans changer la sémantique de livraison. **P2 terminologie** : « parcours sous-traitant ». Vérifier que honeypot est hors tab/lecteur d'écran dans le rendu complet. | `apps/web/app/[locale]/(public)/contact/actions.ts:8-43`; `contact-form.tsx:9-11` |
| SEO public | Metadata localisée, canonical/hreflang, sitemap FR/AR, robots sépare pages privées, OG. | SSR sur Home; page prestataire est entièrement client-side mais texte initial rendu par Next à vérifier au build. | **P0 configuration** : fallback canonique `http://localhost:5173` si `NEXT_PUBLIC_APP_URL` manque; une production mal configurée indexerait des URLs localhost. **P2** : layout public applique une metadata Home générique à toutes les pages sans override locale repérée ici; vérifier titres uniques. | `apps/web/modules/shared/lib/seo/metadata.ts:4-18,34-48`; `apps/web/app/[locale]/(public)/layout.tsx:10-14`; `sitemap.ts:6-24`; `robots.ts:7-12` |

## Source de vérité de la taxonomie

### Présent

- Le référentiel authentifié est versionné et localisé via les RPC `catalog_list_published_libraries_v1`, `catalog_search_published_services_v1` et `catalog_get_published_service_v1` (`apps/web/modules/shared/lib/catalogue/repository.ts:8-10,72-112`).
- La recherche limite la page à 12 services, valide release, curseur et schéma, et regroupe catégorie/sous-catégorie/service (`repository.ts:47-63,83-99`).
- Les types portent les IDs, slugs et noms localisés utiles (`apps/web/modules/shared/lib/catalogue/model.ts:8-24`).
- L'artefact public contient 200 métadonnées de service réparties sur 10 bibliothèques; aucune des 6 000 questions n'a été chargée pour cet audit.

### Écart confirmé P1

- La projection publique Home utilise une liste **hardcodée** de 10 bibliothèques (`apps/web/modules/public/data/catalogue/static-projection.ts:3-21`).
- L'ancienne fiche utilise un JSON statique de 200 services et redirige par nom (`services/[code]/page.tsx:2-8`).
- Aucune commande de génération/provenance pour `static-projection.ts` ou `services.json` n'a été trouvée dans `scripts/`, `docs/` ou les `package.json`.
- Les RPC canoniques exigent actuellement un utilisateur authentifié (`apps/web/modules/shared/lib/catalogue/repository.ts:66-75`); ils ne peuvent donc pas alimenter directement la sélection publique anonyme sans projection serveur publique limitée et sûre.

### Contrat UX cible recommandé

1. Charger uniquement bibliothèques, catégories et métadonnées de services d'une release publiée; jamais les questionnaires complets.
2. Stocker dans le brouillon versionné : `releaseId`, `libraryId`, `categoryId`, `serviceIds[]`, labels d'affichage figés et `otherServiceText` seulement si nécessaire.
3. Recherche serveur paginée et localisée; regroupement par catégorie; multi-sélection avec chips et compteur.
4. Résumé « Voici ce que Matricia a compris » avec Modifier/Valider.
5. À l'authentification, revalider les IDs contre la release et mapper explicitement une release remplacée; ne jamais faire confiance au localStorage comme autorisation.
6. Préremplir qualification/matching/demande avec les IDs; conserver le texte libre comme contexte secondaire, pas source de vérité.

## FR / AR / RTL / accessibilité — risques transversaux

| Sujet | Présent | Gap |
|---|---|---|
| Direction | `dir=rtl` dans layout public et locale | Plusieurs composants ajoutent des flèches directionnelles sans `rtl:-scale-x-100`; test visuel requis aux mêmes dimensions. |
| Navigation clavier | Skip link, focus visible, ESC menu | Pas de focus trap/scroll lock/fermeture route; radiogroup diagnostic sans flèches/roving tabindex. |
| Touch targets | Nombreux `min-h-11` (44 px) | Vérifier textarea, chips futures, fermeture menu et zones upload à 360 px. |
| Traduction | Copy FR/AR dédiée sur parcours publics | Codes anglais restent exposés dans qualification et d'autres espaces; l'arabe réutilise parfois le français via spreads dans des modules hors périmètre public immédiat. |
| Bidirectionnel | `dir=ltr` sur IDs/courriels dans plusieurs écrans connectés | Vérifier nombres, MAD, emails et chevrons en contexte RTL; aucun test manuel lecteur d'écran produit dans ce sous-audit. |
| Erreurs | Diagnostic/besoin/contact ont `role=status/alert` | Prestataire public n'encadre pas les erreurs localStorage/quota et ne valide pas le textarea avant navigation. |

## Priorités de correction issues de cet audit

### P0

- Garantir `NEXT_PUBLIC_APP_URL` valide en production afin d'éviter canonical/sitemap localhost.
- Réconcilier le déploiement cible avant toute conclusion visuelle; aucune preuve navigateur distante n'a été obtenue ici.

### P1

- Construire le sélecteur public taxonomique structuré et sa continuité auth→qualification.
- Remplacer les codes seuls de qualification par les labels localisés de la release canonique.
- Relier Home et besoin aux domaines/services réels sans réintroduire un catalogue commercial obligatoire.
- Faire passer le besoin de texte libre à classification confirmée puis dossier structuré, en réutilisant le moteur existant.
- Supprimer la duplication statique non traçable ou créer une projection générée/versionnée vérifiée contre le manifeste.

### P2

- Unifier Professionnel/Prestataire/Fournisseur/Sous-traitant selon la matrice.
- Corriger le comportement accessible du menu et du radiogroup, les flèches RTL et les codes de statut non traduits.
- Vérifier à 360/390/412/768/1024/1440 px et zoom 200 %, FR/AR, clavier, focus, contraste et lecteur d'écran.

### P3

- Mesurer performance, hydratation de la page Prestataire et metadata par route avant optimisation.
- Ajouter analytics non sensibles sur recherche taxonomique, sélection, reprise et conversion vers qualification.

