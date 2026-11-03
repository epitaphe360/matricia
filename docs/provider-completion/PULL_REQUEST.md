# Compléter le parcours Sous-traitant et fiabiliser les flux partagés Client

Le prestataire était bloqué à la qualification et rencontrait des erreurs de contexte, de lecture ou de reprise. Cette branche issue du Client final7e01276 raccorde identité, questionnaire et revue indépendante, coffre privé, capacité, consultations/devis révisés, contrats, livraisons versionnées, affectations, messagerie et finance gouvernée en FR/AR. Elle corrige aussi la reprise après panne, les rôles composites, les générations signées ADD/REPLACE/REMOVE, l'origine contractuelle des décisions monétaires, les dates civiles, la navigation du double rôle et la langue du document pendant une navigation SPA.

La revue conserve MFA/AAL2, RLS, validation indépendante, audit/outbox et historiques immuables. Aucun montant juridique ou tarif de production n'est inventé ; les données et signatures de recette sont explicitementTEST.

Validation :507migrations/56fichiersSQL/2067assertions,649tables publiques avecRLS et pgTAPfermé ; Web2980tests +30PDF/MFAisolés,1skip opt-in ; worker104 ; types, lint et builds complets. Recette native,232pagesFR/AR×4largeurs et256scansaxe sans violation sur706 ; dernierdelta5b8b0f limité à deux labelsDevis, build et8contrôles ciblés réussis. Les256incomplets de contraste ne sont pas masqués :54cibles réellement mesurées conformes,2nonmesurées, sans certificatWCAGglobal.

[Rapport exhaustif](REPORT.md), [commandes et résultats](VALIDATION.md), [contre-revues](independent-review.md), [captures et provenance](evidence/browser/README.md).

La facture du mois courant et son règlement attendent les vrais cutoff/délai contradictoire ; ils ne sont pas déclarés réussis dans le navigateur. Signature juridique, données légales/fiscales approuvées et recette des intégrations hébergées restent nécessaires avant lancement. Aucune fusion ni mise en production dans cette mission.

Base explicite de revue : `codex/client-completion-20261102` au7e01276 pour isoler le lot Provider ; source globale conservée `codex/bootstrap-foundation`. La création distante de PR peut être bloquée par l'accès API GitHub ; ne pas confondre ce corps prêt à relire avec une PR effectivement créée.
