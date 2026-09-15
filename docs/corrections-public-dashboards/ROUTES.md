# Cartographie des routes

## Public et authentification

| Route | Rôle | Composant principal | Données / autorisation | Destination principale | État initial |
|---|---|---|---|---|---|
| `/:locale` | Visiteur | `PublicHomePage` | Publique | `/diagnostic` | Accessible |
| `/:locale/diagnostic` | Visiteur | `PrediagnosticFlow` | Brouillon local limité | Connexion avec reprise | Corrigée, publique et testée |
| `/:locale/besoin` | Visiteur | `NeedFlow` | Brouillon local limité puis rattachement serveur autorisé | Connexion avec reprise vers les demandes | Corrigée, publique et testée |
| `/:locale/fournisseur` | Visiteur | `ProviderEntry` | Intention locale puis dossier de qualification autorisé | Inscription ou connexion | Corrigée, publique et testée |
| `/:locale/abonnements` | Visiteur | `PublicSubscriptionsPage` | Projection serveur des seules versions actives publiables | Inscription explicite | Ajoutée |
| `/:locale/contact` | Visiteur | `ContactPage` + `ContactForm` | RPC de dépôt public, quota atomique | Référence de demande réelle | Corrigé et testé |
| `/:locale/services` | Visiteur / ancienne URL | `ServicesTransition` | Aucune | Diagnostic ou besoin guidé | Redirection conservée |
| `/:locale/services/:code` | Visiteur / ancienne URL | `ServiceIntentTransition` | Référentiel interne statique | Besoin guidé prérempli | Redirection conservée |
| `/:locale/connexion` | Visiteur | `OtpForm` | OTP, quota serveur, non-énumération | Retour interne validé avec intention | Corrigé et testé |
| `/:locale/auth/callback` | Visiteur authentifié | Route serveur | Échange PKCE, retour interne validé | Parcours repris ou tableau de bord | Corrigé et testé |

## Espaces connectés

Les routes réellement présentes sous `client`, `sous-traitant`, `franchise`, `administration`, ainsi que `actions`, `messagerie`, `notifications`, `organisation`, `invitations` et `securite`, sont conservées. Le registre typé contient 48 destinations FR/AR avec groupe, contexte et capacités. Les lectures passent par des repositories serveur et les mutations visibles restent conditionnées par leurs capacités/RPC ; l'inventaire couvre onboarding, questionnaires, diagnostics, demandes, missions, portefeuille, devis, qualification, facturation, gouvernance, performance, relances, digest, command-center, conformité, finance, fiscalité, référentiel, marketing, opérations et anti-abus.

Le contexte Client est propagé aux parcours principaux. Résidu connu : documents et crédits filtrent après chargement de l'ensemble déjà autorisé ; questionnaires, litiges et récurrence conservent leur comportement antérieur et doivent recevoir le sélecteur transversal dans une passe P2.

## Inventaire exhaustif des pages au checkpoint

| Groupe / rôle | Routes présentes | Données et autorisation | État / destination |
|---|---|---|---|
| Public | `/`, `/a-propos`, `/abonnements`, `/besoin`, `/contact`, `/diagnostic`, `/fournisseur`, `/franchise`, `/services`, `/services/[code]` | Projection publique bornée ; aucune table privée exposée | Parcours guidés, inscription/connexion ou contact réel |
| Auth/partagé | `/connexion`, `/tableau-de-bord`, `/actions`, `/invitations`, `/messagerie`, `/notifications`, `/organisation`, `/organisation/roles`, `/securite/compte`, `/securite/sessions` | Session, memberships, rôles/capacités et contexte serveur | Accueil métier, action, communication ou gestion du compte |
| Client | `/client/onboarding`, `/client/questionnaires`, `/client/diagnostics`, `/client/diagnostics/[runId]`, `/client/diagnostics/assistance`, `/client/diagnostics/evolution`, `/client/diagnostics/solutions`, `/client/demandes`, `/client/demandes/nouvelle`, `/client/demandes/[requestId]`, `/client/demandes/[requestId]/comparaison`, `/client/demandes/recurrence`, `/client/missions`, `/client/portefeuille`, `/client/documents`, `/client/favoris`, `/client/litiges`, `/client/litiges/nouveau`, `/client/litiges/[caseId]`, `/client/abonnement`, `/client/credits`, `/client/achats-groupes`, `/client/recompenses` | Organisation Client active + RPC/RLS par capacité | Dossier, détail, action métier et retour d'état |
| Sous-traitant | `/sous-traitant/qualification`, `/sous-traitant/devis`, `/sous-traitant/missions`, `/sous-traitant/facturation`, `/sous-traitant/reputation` | Organisation Provider, qualification et périmètre partagé | Qualification, réponse, livraison, règlement et réputation |
| Franchise | `/franchise/gouvernance`, `/franchise/performance`, `/franchise/relances`, `/franchise/digest` | Mandat/territoire/rôle Franchise | Pilotage opérationnel ou gouvernance autorisée |
| Administration | `/administration/command-center`, `/administration/clients`, `/administration/conformite-clients`, `/administration/providers`, `/administration/finance`, `/administration/approbations-finance`, `/administration/fiscalite-maroc`, `/administration/achats-groupes`, `/administration/gouvernance-franchise`, `/administration/incitations`, `/administration/catalogue`, `/administration/catalogue/publications`, `/administration/catalogue/validation`, `/administration/clonage`, `/administration/questionnaires/analytique`, `/administration/marketing-autopilot`, `/administration/operations`, `/administration/anti-abus`, `/administration/v4-1/[module]` | Rôle plateforme explicite ; AAL2/double approbation lorsque requis | Centre de pilotage, dossier ou commande contextualisée |
| Référentiel privé | `/catalogue`, `/catalogue/[librarySlug]/[serviceSlug]` | Lecture authentifiée/RLS ; non indexé et absent du commerce public | Questions, recommandations et qualification internes |

Les parenthèses de groupe Next.js `(public)` ne font pas partie des URL. Toutes les routes sont préfixées par `/:locale` et conservent FR/AR.
