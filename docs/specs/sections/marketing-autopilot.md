# Marketing Autopilot — contrat P18

Les exigences MARKETING-001..008 sont V1 obligatoires et restent versionnées, consent-aware et soumises à approbation humaine pour toute publication externe.

| ID | Contrat vérifiable |
|---|---|
| MARKETING-001 | Segments versionnés, explicables et strictement isolés par organisation. |
| MARKETING-002 | Consentement, base de traitement, opt-out et liste de suppression appliqués avant chaque ciblage. |
| MARKETING-003 | Campagne versionnée avec objectif, audience, canaux, budget exact, calendrier et propriétaire. |
| MARKETING-004 | Contenu FR/AR versionné, relu et approuvé; aucune publication automatique sans policy autorisée. |
| MARKETING-005 | Orchestration par Outbox avec idempotence, retries bornés, déduplication et dead-letter. |
| MARKETING-006 | Attribution et métriques sans fuite inter-tenant, PII minimisée et période de rétention définie. |
| MARKETING-007 | Boucle d’optimisation propose des changements explicables; toute modification sensible reste approuvée et auditée. |
| MARKETING-008 | Command center expose files, erreurs, reprises, arrêt d’urgence et journal d’audit. |

Gate : tests unitaires/intégration/RLS/E2E, consentement positif et refus, accessibilité FR/AR, audit sécurité et preuve de non-publication sans approbation.
