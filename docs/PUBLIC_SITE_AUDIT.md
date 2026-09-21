# Audit site public — 2026-09-16

**Verdict :** PASS public (écarts P1/P2 audit fermés).

## Correctifs

### Vague 1 (revue)
- `plan=` Connexion + Contact
- Franchise `sourcePath` validé
- Labels AR localisés, `defaultValue` message
- Accueil `lang` domaines
- Footer Fonctionnement + Offres
- `tsc` OrganizationSwitcher

### Vague 2 (reste audit)
- Prédiagnostic « Modifier mes réponses » → retour étape 0 **sans wipe** (`onEdit`)
- Besoin : classification domaine/service **modifiable** avant confirmation
- Proxy tests : entreprises, légales, services, contact, a-propos
- Changement de langue : conserve **search + hash**

## Preuves
- Vitest journey/site/proxy/contact/page : **37/37** verts

## Gaps volontaires (hors audit public)
- Branches prédiagnostic moteur catalogue complet
- Conversion brouillon → RFQ consultation (Lot 3)
- Client factures prestataires / Prestataire litiges UI (CDC espaces)
