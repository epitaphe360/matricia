# Conformité Cahier des charges Matricia — 16 septembre 2026

**Référence :** CDC « Plateforme B2B : pages publiques, parcours et espaces connectés »  
**Périmètre validé :** fonctionnel, architecture, sécurité, i18n, données — **hors §4 Design (propositions séparées §V)**.  
**Verdict global :** **PARTIELLEMENT CONFORME** — cœur produit largement raccordé ; release V1 **non signable** ; écarts P1 publics + quelques PARTIEL espaces connectés.

Légende : **R** = respecté · **P** = partiel · **E** = écart · **A** = absent / hors preuve · **H** = hors scope (visuel)

---

## Synthèse exécutive

| Bloc CDC | Verdict | Commentaire |
|----------|---------|-------------|
| 1 Objectifs / périmètre V1 | **P** | Direction OK ; MAT-FUNC-001–068 pas tous VERIFIED |
| 1.2 Économie | **R** | Prestataire fixe prix ; minor units ; pas de séquestre inventé |
| 2–3 Espaces / architecture UX | **P** | Espaces présents ; chrome org switcher incomplet hors home |
| 4 Design | **H** | Voir propositions §V (non jugé « respecté ») |
| 5–7 Public + formulaires | **P** | Nav OK ; footer incomplet ; handoffs `plan=` ; besoin classification |
| 8 Client | **P** | Accueil fort ; finances prestataires / contrats dédiés PARTIEL |
| 9 Prestataire | **P** | Accueil + qualification OK ; litiges UI / signature contrat PARTIEL |
| 10 Franchise | **R** | Gouvernance + IT 50/50 en SQL |
| 11 Admin | **P** | Pilotage/fiches/parcours OK ; coffre transversal non inventé |
| 12–17 Transversal | **P** | Modules présents ; intégrations distantes non signées |
| 18 FR/AR SEO | **R** (public) | Authentifié FR/AR non exhaustif |
| 19 Démo | **R** | Gated env, pas prod |
| 20–21 Recette / terminé | **E** | `RELEASE_CHECKLIST.md` = FAIL |

**Preuves fraîches :** 40 tests public/journey verts · audit `docs/PUBLIC_SITE_AUDIT.md` · validations Client/Provider/Admin.

---

## Matrice détaillée (hors visuel)

### 1 — Objectif et périmètre
| Item | Statut | Note |
|------|--------|------|
| 1 Parcours bout-en-bout décrit | **P** | Modules existants raccordés ; E2E bout-en-bout incomplet |
| 1.1 MAT-FUNC-001–068 V1 | **P** | Scope respecté ; preuves VERIFIED incomplètes |
| 1.1 MAT-FUNC-069–090 hors V1 | **R** | Pas d’élargissement silencieux observé |
| 1.2 Prix Prestataire / choix Client | **R** | FAQ + devis versionnés |
| 1.2 Paiement direct / pas de séquestre | **R** | Architecture credits/abonnements Matricia séparés |
| 1.2 Montants exacts | **R** | `*_minor` / pas de float métier |

### 2–3 — Utilisateurs et architecture expérience
| Item | Statut | Note |
|------|--------|------|
| Profils Client/Prestataire/Franchise/Admin | **R** | Routes + rôles |
| Visiteur public sans données confidentielles | **R** | Proxy public ; pas d’annuaire prestataires |
| 3.1 Pages publiques | **P** | Présentes ; handoffs §6.7–6.9 à corriger |
| 3.2 Chrome connecté (org, rôle, msg, notif) | **P** | Switcher surtout sur `tableau-de-bord` |
| 3.3 Continuité langue / brouillon | **P** | localStorage OK ; `plan=` perdu ; hash langue P3 |

### 5 — Navigation publique
| Item | Statut | Note |
|------|--------|------|
| 5.1 Header (Entreprises, Professionnels, Comment ça marche, Offres, Franchise, login, register, Analyser, FR/AR) | **R** | `public-navigation.tsx` |
| 5.1 Menu mobile accessible | **R** | Focus trap + Escape |
| 5.2 Footer À propos, Contact, légales | **R** | Présents |
| 5.2 Footer Fonctionnement + Offres | **E** | Manquants dans `public-footer.tsx` (Entreprises à la place de Offres/Fonctionnement) |

### 6 — Pages publiques
| Item | Statut | Note |
|------|--------|------|
| 6.1 Accueil 3 CTAs + cycle + domaines catalogue + FAQ | **R** | Domaines → `/besoin?library=` |
| 6.1 Exemple illustratif / pas de faux KPI | **R** | |
| 6.2 Entreprises orientation | **R** | `/entreprises` |
| 6.3 Prédiagnostic sans compte, IDs stables, résultat priorités | **P** | OK global ; branches déclaratives ; « Modifier » efface |
| 6.3 8–12 interactions / activité recherchable | **P** | ~8 Q ; secteurs fixes ≠ recherche activité |
| 6.4 Besoin étapes + classification modifiable | **E** | Classification lecture seule ; champs intervention/budget incomplets vs CDC |
| 6.5 Professionnels taxonomie + handoff qualification | **R** | `fournisseur` + intent v2 |
| 6.6 Domaines/services orientation | **R** | Guide + redirect anciennes fiches |
| 6.7 Offres sans débit ; conserver plan | **E** | Affichage OK ; **`plan=` non consommé** à la connexion |
| 6.8 Franchise + formulaire conditionnel | **P** | Form OK ; `source_path` faussement `/contact` |
| 6.9 Contact motifs + enregistrement réel | **P** | OK ; `plan` ignore ; distinction livraison email partielle |
| 6.10 Auth dual intent + next sûr | **R** | OTP existant ; `next` validé préfixe locale |

### 7 — Règles formulaires
| Item | Statut | Note |
|------|--------|------|
| 7.1 Contrôles adaptés | **P** | Globally OK ; listes longues OK côté provider |
| 7.2 Dépendances domaine→catégorie→service | **P** | Provider/services OK ; besoin récap non éditable |
| 7.3 Brouillon / succès après confirmation / anti-doublon | **P** | RPC idempotentes diagnostic/besoin ; forms contact risque FormData |
| 7.4 Pas d’UUID métier en UI | **R** | |

### 8 — Client
| Item | Statut | Note |
|------|--------|------|
| 8.1 Accueil actions | **R** | |
| 8.2 Entreprise / équipe | **R** | |
| 8.3 Diagnostics | **R** | |
| 8.4 Demandes | **R** | |
| 8.5 Comparaison devis | **R** | |
| 8.6 Contrats / missions | **P** | Missions OK ; route contrats dédiée absente |
| 8.7 Livrables | **R** | Via missions |
| 8.8 Projets / budgets | **P** | Modules partiels selon routes |
| 8.9 Finances séparées | **P** | Matricia OK ; factures prestataires = indisponible honnête |
| 8.10 Autres (litiges, docs…) | **R** | Présents |

### 9 — Prestataire
| Item | Statut | Note |
|------|--------|------|
| 9.1 Accueil | **R** | |
| 9.2 Qualification ≠ déclaration | **R** | |
| 9.3 Capacité | **R** | |
| 9.4–9.5 Consultations / devis | **R** | |
| 9.6 Exécution / contrats | **P** | Missions OK ; signature contrat UI absente |
| 9.7 Facturation | **R** | |
| 9.8 Réputation / litiges | **P** | Pas de `sous-traitant/litiges` |

### 10 — Franchise
| Item | Statut | Note |
|------|--------|------|
| 10.1–10.3 Opérationnel / réseau | **R** | |
| 10.4 IT Hatim 50/50, Asma 0 | **R** | Migration franchise finance |

### 11 — Administration
| Item | Statut | Note |
|------|--------|------|
| 11.1 Centre pilotage | **R** | |
| 11.2 Fiches entreprise | **R** | |
| 11.3 Processus | **R** | `administration/parcours` |
| 11.4–11.5 Finance / référentiel | **R** | Modules présents |
| 11.6 Transversal (anti-abus, marketing…) | **P** | Présents ; coffre unique non inventé |

### 12–21 — Transversal
| Item | Statut | Note |
|------|--------|------|
| 12 Workflow dossiers | **P** | Machines d’état existantes ; UI parfois partielle |
| 13 Documents / messagerie / notif | **R** | |
| 14 Marketing Autopilot | **R** | Approbation humaine |
| 15 Sécurité RLS / secrets | **P** | Structure OK ; preuves release distantes FAIL |
| 16 Architecture / outbox / ledger | **R** | |
| 17 Intégrations | **P** | Code ; sandbox distant non signé |
| 18 FR/AR SEO public | **R** | |
| 19 Démo gated | **R** | |
| 20 Perf / observabilité | **P** | Readiness + logs ; SLO incomplets |
| 21 / 24 Définition de terminé | **E** | Non atteint — checklist FAIL |

---

## Registre des écarts à traiter (hors visuel)

### P1 — à corriger avant claim « CDC public respecté »
~~1. Footer Fonctionnement + Offres~~ **FAIT**  
~~2. `plan=` Connexion/Contact~~ **FAIT**  
~~3. Franchise source_path~~ **FAIT**  
~~4. Hidden message FormData~~ **FAIT** (`defaultValue` + compose)  
~~5. Besoin classification modifiable~~ **FAIT**  
~~6. Prédiagnostic Modifier sans wipe~~ **FAIT**  
~~7. tsc tableau-de-bord~~ **FAIT**

### P2 — cœur produit restant (espaces connectés)
- Client : projection factures prestataires ; route contrats si exigée
- Prestataire : litiges UI ; signature contrat
- Chrome : org switcher dans shells modules
- Prédiagnostic : recherche activité + branches moteur
- Brouillon public → RFQ consultation (Lot 3)

### P0 release (déjà documenté)
- Intégrations distantes (paiement, SMTP, workers) non prouvées
- Acceptation MAT-FUNC exhaustive non signable

---

## §V — Propositions visuelles (hors conformité)

Le CDC §4 fixe Design A (clair, bleu nuit, action `#1D4ED8`). **Ne pas confondre** avec l’expérience publique actuelle « bleu électrique » déjà en place.

### Proposition V-A — Unifier « Moderne & Professionnelle » (recommandée)
- **Espace connecté** : conserver Design A forest/gold + tokens admin/client/provider déjà peaufinés.
- **Public** : rapprocher `experience.css` des tokens CDC (`#F7F9FC`, `#0B1739`, `#1D4ED8`) tout en gardant une identité légèrement plus « marketing » (hero atmosphère, pas dashboard).
- Une **action primaire** par viewport ; listes avant KPI décoratifs.
- Motion : 2–3 transitions d’état, honor `prefers-reduced-motion`.

### Proposition V-B — Dual brand contrôlé
- Public = electric blue (acquisition) ; connecté = Design A (travail).
- Documenter la bascule dans le design system (même typo, mêmes rayons, contraste AA).
- Risque : sensation de deux produits — compenser par logo/chrome commun.

### Proposition V-C — Accent métier par espace (optionnel)
- Client : bleu action CDC.
- Prestataire : teal sombre dérivé du forest Design A.
- Admin : charcoal + or discret déjà en place.
- Franchise : indigo nuit.
- Toujours fond `#F7F9FC` et surfaces blanches.

### Critères de succès visuels (recette)
- Contraste AA titres/actions
- Cibles ≥ 44 px
- 360 px : nav + CTA principal sans overflow
- Aucun faux KPI / badge / témoignage
- Une seule CTA primaire au-dessus de la ligne de flottaison

---

## Conclusion

**Hors visuel, le CDC n’est pas « tout respecté ».**  
Ce qui est solide : économie, catalogue canonique public, nav header, espaces Client/Prestataire/Franchise/Admin largement raccordés, démo gated, SEO public, ledgers.  
Ce qui empêche un verdict « conforme » : handoffs `plan=`, footer incomplet, besoin/prédiagnostic vs §6.3–6.4, chrome org incomplet, gaps Client finances prestataires / Prestataire litiges, et **release V1 non signable**.

**Prochaine action recommandée :** corriger le paquet P1 public (1 journée) puis rejouer cette matrice.
