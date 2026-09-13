# V4.1 — Continuité, sauvegarde et restauration

Ce runbook est exécutable en développement/staging et ne constitue jamais, à lui seul, une preuve de restauration.

1. Identifier le service et sa version dans `third_party_services`, puis son RPO/RTO dans `continuity_service_objectives`.
2. Ouvrir un incident corrélé, suspendre les mutations incompatibles et activer le mode de dégradation enregistré.
3. Vérifier l’intégrité du dernier backup DB/storage/config sans exposer de secret.
4. Restaurer dans une cible isolée non-production. Comparer les hashes source/cible et exécuter les tests fonctionnels, RLS et financiers.
5. Enregistrer `PASSED` ou `FAILED` uniquement avec timestamp et hashes de preuve. Sans exécution réelle, conserver `REQUIRED_NOT_COMPLETED`.
6. Faire approuver le retour au service par un acteur différent, puis vider les files idempotemment.

Pannes : Supabase passe en lecture seule; Vercel/Railway basculent vers artefact/conteneur portable; IA est désactivée; email/signature sont mis en file puis DLQ après retries bornés. Aucun provider indisponible ne doit avancer un état métier sans accusé autoritatif.

Les restores externes initialement seedés restent `REQUIRED_NOT_COMPLETED` jusqu’à preuve indépendante. Aucune restauration de production n’est autorisée par ce document.
