# Compléter le parcours Sous-traitant et sécuriser les flux partagés Client

Le prestataire pouvait être bloqué à la qualification, perdre le contexte de ses dossiers ou rencontrer des limites de lecture et de reprise. La branche issue du Client final7e01276 raccorde identité, questionnaires soumis et revue indépendante, coffre privé, capacité, consultations/devis révisés, contrats, livraisons versionnées, affectations techniques, messagerie et facturation gouvernée en FR/AR.

Les contre-revues ont corrigé des causes communes supplémentaires : mutations distinctes de la lecture pour les rôles composites, reçus rejouables après panne, générations ADD/REPLACE/REMOVE conformes aux versions signées, contexte de planning incomplet explicite, revue financière indépendante et origine économique approuvée/signée plutôt que montants saisis par l'opérateur. Les historiques, ledgers, MFA/AAL2, RLS, audit et outbox restent protégés.

Validation et limites vérifiables : [rapport exhaustif](REPORT.md), [revue indépendante](independent-review.md), [contre-revue Livraison](DELIVERY-INDEPENDENT-REVIEW.md), [Finance](FINANCE.md). Les reçus indiquent exactement le candidat et les sources exécutés. Le build et la recette locale utilisent uniquement des comptes/documentsTEST ; les signatures de développement et scans synthétiques ne valent pas intégrations externes de production.

La recette consolidée et les prérequis externes sont suivis dans le rapport. Cette PR ne doit pas être fusionnée ou déployée en production dans cette mission. Les contenus légaux, fournisseurs externes et droits de staging manquants ne sont pas inventés.

Base de revue recommandée : `codex/client-completion-20261102` (7e01276) pour isoler le lot Sous-traitant. Source globale préservée : `codex/bootstrap-foundation`. Vérifier la branche cible réellement fusionnée avant toute intégration future.
