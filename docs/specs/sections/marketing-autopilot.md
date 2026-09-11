# Marketing Autopilot — contrat P18

Autorité : addendum obligatoire V1 du Gold Master V4 FINAL. Les modes sont `MANUAL`, `ASSISTED` et `AUTOPILOT`. Le mode initial est `ASSISTED`; `AUTOPILOT` exige comptes sociaux connectés et règles de marque validées. Toute exception de conformité bloque uniquement le contenu concerné.

| ID | Fonction V1 et preuve de sortie |
|---|---|
| MARKETING-001 | **Brand Kit automatisé** : source versionnée par Provider, Franchisé ou Matricia, préremplie depuis les données existantes; statut READY et certifications valides requis avant publication. |
| MARKETING-002 | **1 service = 3 contenus** : lot LinkedIn B2B, Facebook/Instagram et script Reel 20–30 s, avec sources, claims, CTA tracké, cible, langue, risque et expiration. |
| MARKETING-003 | **Six templates standardisés** : PROBLEM_SOLUTION, EXPERT_TIP, PROVIDER_INTRO, BEFORE_AFTER, SERVICE_OF_MONTH et SUCCESS_CASE, chacun versionné avec structure et limites réseau. |
| MARKETING-004 | **Calendrier mensuel automatique** : génération le 25 pour le mois suivant, valeurs initiales 8 posts + 4 Reels, états DRAFT à PUBLISHED/FAILED/SKIPPED et approbation globale en ASSISTED. |
| MARKETING-005 | **Publication sociale contrôlée** : abstraction social_provider LinkedIn/Meta, OAuth serveur, permissions minimales, révocation, audit et retry idempotent sans double publication. |
| MARKETING-006 | **Tracking CTA → contrat** : UTM normalisées, chemin multi-touch et attribution configurable LAST_NON_DIRECT_CLICK par défaut jusqu’aux diagnostics, RFQ, contrats et valeur exacte. |
| MARKETING-007 | **Campagnes depuis anomalies réelles** : agrégation hebdomadaire, seuil k-anonymity, tendances, snapshot source, services associés et publication uniquement si policy autorisée. |
| MARKETING-008 | **Dashboard actionnable** : KPI obligatoires par acteur/bibliothèque/service/réseau/campagne/période et recommandation hebdomadaire KEEP/INCREASE/REDUCE/CHANGE/PAUSE. |

## Conformité et états

Pipeline obligatoire : `GENERATE → SOURCE_CHECK → BRAND_CHECK → CLAIMS_CHECK → PRIVACY_CHECK → CERTIFICATION_CHECK → DUPLICATE_CHECK → RISK_SCORE → SCHEDULE/PUBLISH`.

Interdictions : client nommé sans consentement, chiffre sans source, certification ou promotion expirée, prix non validé, promesse absolue, donnée privée et répétition excessive. Un échec crée une `MARKETING_EXCEPTION`; il ne doit jamais publier le contenu.

## Gate

Les huit fonctions, AUTOPILOT démo, 10 Brand Kits franchises, 20 Provider, 50 campagnes, 300 contenus et 100 programmations doivent être prouvés. Tests obligatoires : génération déterministe, Brand Kit, claims/certifications/PII bloqués, retry sans doublon, attribution, RLS, calendrier, AUTOPILOT PASS seulement, FR/AR, mobile, audit et failover provider.
