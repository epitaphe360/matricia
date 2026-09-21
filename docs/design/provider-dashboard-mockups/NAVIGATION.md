# Navigation — espace Prestataire / Sous-traitant

Préfixe `/{locale}` : `/fr` ou `/ar`.

Les maquettes `00`–`27` sont dans `docs/design/sous-traitant-dashboard-mockups/`.

## Accueil et qualification

- Accueil : `/{locale}/tableau-de-bord` — maquettes `00`, `27` (AR RTL)
- Qualification : `/{locale}/sous-traitant/qualification` — `01`
- Certifications et références : `/{locale}/sous-traitant/qualification/certifications` — `25`
- Services & capacité : `/{locale}/sous-traitant/services` — `02`

## Cycle commercial

- Consultations : `/{locale}/sous-traitant/consultations` — `03`
- Détail consultation : `/{locale}/sous-traitant/consultations/{id}` — `09`
- Devis : `/{locale}/sous-traitant/devis` — `04`
- Devis multiligne : `/{locale}/sous-traitant/devis/nouveau` et `/{locale}/sous-traitant/devis/{id}` — `10`
- Révision : `/{locale}/sous-traitant/devis/{id}/revision` — `11`
- Prévisualisation : `/{locale}/sous-traitant/devis/{id}/apercu` — `24`
- Missions & livrables : `/{locale}/sous-traitant/missions` — `05`
- Mission et livraison : `/{locale}/sous-traitant/missions/{id}` — `12`
- Planning : `/{locale}/sous-traitant/planning` — `16`

## Documents, facturation, réputation

- Documents : `/{locale}/sous-traitant/documents` — `06`
- Facturation (dossiers client) : `/{locale}/sous-traitant/facturation` — `07`
- Facture et règlement : `/{locale}/sous-traitant/facturation/{id}` — `13`
- Pré-relevé Matricia : `/{locale}/sous-traitant/facturation/pre-releve` — `20`
- Factures Matricia : `/{locale}/sous-traitant/facturation/factures-matricia` — `21`
- Échéancier : `/{locale}/sous-traitant/facturation/echeancier` — `22`
- Commissions : `/{locale}/sous-traitant/facturation/commissions` — `23`
- Réputation : `/{locale}/sous-traitant/reputation` — `08`

## Gouvernance et contexte

- Incidents et litiges : `/{locale}/sous-traitant/litiges` — `18`
- Mes achats : `/{locale}/sous-traitant/achats` — `26`
- Mode Client : `/{locale}/sous-traitant/mode-client` — `19`
- Contrat partenaire : `/{locale}/sous-traitant/entreprise/contrat` — `17`
- Mon entreprise / sécurité : `/{locale}/sous-traitant/entreprise` — `15`
- Messages : `/{locale}/sous-traitant/messages` et `/{locale}/messagerie` — `14`
- Notifications : `/{locale}/notifications`
