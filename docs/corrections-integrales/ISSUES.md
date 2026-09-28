# Défauts traités — 2026-09-28

Branche `codex/audit-final-2026-09-15`, HEAD `a1e5752`. Aucun déploiement.

| ID | Route | Gravité | Preuve | Correctif | Test | Statut |
| --- | --- | --- | --- | --- | --- | --- |
| PUB-CONTACT-001 | `/fr/contact`, `/ar/contact` | P2 | Bloc « États d’envoi (exemples) » et « Exemple illustratif » rendus à côté du formulaire réel | Bloc retiré. Le message de succès ne s’affiche qu’après `state.status === "success"` | `public-pages-mockup-alignment.test.tsx` | corrigé, test vert |
| PUB-CONTACT-002 | `/fr/contact` | P2 | Carte « Nous écrire directement — Via le formulaire ci-dessus » | Carte retirée | même test (`not.toContain`) | corrigé, test vert |
| PUB-PLANS-001 | `/fr/abonnements` | P1 | Trois cartes avec la même liste, ou repli Essentiel / Premium / Organisation sans données | Chaque plan publié affiche son prix (`formatMinor`, unités mineures) et son nombre de crédits. Prix à 0 ou chargement indisponible : tarif communiqué avant souscription, sans cartes inventées | `abonnements/page.test.tsx` (3 tests) | corrigé, tests verts |
| PUB-NEED-001 | `/fr/besoin` | P1 | Deux titres « 3. » dans `need-flow.tsx` (questions et éléments complémentaires) | Numéros 3, 4, 5. Faute « nous pourrez » → « vous pourrez » | non ajouté | corrigé, non couvert par un test dédié |

| PUB-NAV-001 | Navigation publique FR et AR | P1 | L’arabe exposait الرئيسية، لمن، موارد، اتصل بنا. Le français omettait Entreprises et n’avait pas les mêmes liens | Une seule liste : Comment ça marche, Entreprises, Professionnels, Franchise, Abonnements, À propos, dans les deux langues | `public-navigation.test.tsx` | corrigé, test vert |
| PUB-HOME-001 | `/fr` et `/ar` | P2 | Slogan, valeurs, script et bandeaux posés sur la photo du hero. Le voile clair partait toujours de la gauche, donc le texte arabe reposait sur la photo | Ces quatre décors sont retirés du hero. Le voile utilise `to inline-end`, donc il couvre le côté du texte en arabe comme en français | `public-pages-mockup-alignment.test.tsx` | corrigé, test vert |

| PUB-DIAG-001 | `/fr/diagnostic`, `/ar/diagnostic` | P1 | Sans priorité, l’écran montrait trois cartes avec 92 %, 83 %, 71 % et « 44 / 48 réponses », sans lien avec les réponses. L’échec de stockage local montrait trois pannes en même temps. | Un seul constat réel, sans pourcentage inventé. Un seul état de reprise : le brouillon local n’a pas pu être conservé. | `prediagnostic-phases.test.tsx` | corrigé, tests verts |
| PUB-DIAG-002 | `/fr/diagnostic` | P1 | Le choix « Santé, éducation & social » (`health_social`) était proposé, alors que `save_public_diagnostic_intake` refuse cette valeur. | Le choix est retiré des libellés FR et AR. Un ancien brouillon qui le contient est enregistré comme « Autre activité ». | même fichier | corrigé, test vert |

| PUB-PRO-001 | `/fr/fournisseur`, `/ar/fournisseur` | P1 | Le hero montrait une photo d’artisan et l’exemple ne parlait que de menuiserie. Tous les services du domaine s’affichaient d’un bloc dans une zone défilante. | Le hero liste les domaines réels du catalogue. Les catégories sont repliées, seule la première est ouverte. L’exemple cite plusieurs métiers. | `provider-taxonomy-selector.test.tsx` | corrigé, tests verts |

| PUB-FRANCHISE-001 | `/fr/franchise`, `/ar/franchise` | P1 | La page promettait « un territoire exclusif » et « votre territoire exclusif », sans renvoyer au contrat versionné. | Le territoire est décrit comme celui prévu au contrat versionné. Le mot « exclusif » / « حصري » n’apparaît plus. | `public-pages-mockup-alignment.test.tsx` | corrigé, test vert |

| PUB-NEED-002 | `/fr/besoin`, `/ar/besoin` | P1 | La description, les suggestions, la taxonomie, les questions, les contraintes et les documents s’affichaient ensemble. Le score de suggestion montrait `TOKEN_OVERLAP_V1`. | Une seule section est visible : description, compréhension, questions, puis compléments. Le récapitulatif reste l’étape suivante. L’identifiant technique n’est plus affiché. | `need-flow.test.tsx` | corrigé, test vert |

| ADM-CC-001 | `/fr/administration/command-center`, `/ar/...` | P1 | Le formulaire « Demander une action contrôlée » faisait saisir un UUID d’organisation, un UUID d’action liée, une empreinte SHA-256, un résumé JSON et un UUID d’utilisateur support. L’expiration en `datetime-local` n’était pas au format attendu par le schéma serveur. | L’administrateur choisit un dossier ouvert dans une liste. Le serveur relit ce dossier (RLS), en déduit l’organisation et la ressource, puis calcule l’empreinte et le résumé. L’accès support va au responsable du dossier, pour 15, 30 ou 60 minutes. La référence production n’apparaît que pour l’environnement Production. | `actions-center.test.ts` (4 tests), `command-center-panel.test.tsx` | corrigé, tests verts |
| ADM-FIN-001 | `/fr/administration/finance` (box) | P2 | « Versions d’avantages autorisées (UUID) » : champ texte libre | Cases à cocher sur les avantages existants | suite complète | corrigé |
| ADM-VOL-001 | `/fr/administration/achats-groupes` | P2 | « Organisation fournisseur (UUID, facultatif) » : champ texte libre | Liste des fournisseurs chargée côté serveur | `volume-negotiate-panel.test.tsx` | corrigé |
| TEST-001 | Suite Vitest | P2 | Quatre tests périmés : ils attendaient le bouton « Soumettre pour validation », retiré volontairement par `9ccd49c`, l’absence de l’entrée Finance franchisé et d’anciens nombres d’entrées de menu | Tests alignés sur le comportement réel. Le test franchise vérifie en plus qu’aucun nom de bénéficiaire de partage interne n’apparaît. | suite complète | corrigé |

## Non traité dans cette passe

Les espaces Client, Prestataire et Franchisé n’ont pas été repris écran par écran dans cette passe. Aucune P0 (fuite, RLS, IDOR, secret) n’a été cherchée ni prouvée par un audit indépendant. Aucun test E2E navigateur ni SQL/RLS n’a été relancé. Le formulaire Command center n’a pas été essayé dans le navigateur avec un compte administrateur.
