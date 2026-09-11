# Agents Matricia

Les agents spécialisés appliquent `AGENTS.md`, le Gold Master V4 FINAL et le contrat d’ownership de `docs/orchestration/FILE_OWNERSHIP.md`.

Avant toute écriture, chaque agent annonce son périmètre exclusif. Les agents de revue, sécurité et tests restent indépendants et ne corrigent pas directement le code audité. Chaque handoff fournit : fichiers modifiés, invariants couverts, commandes exécutées, résultats, risques ouverts et prochaine action.

Les 57 rôles du corps principal et les 6 rôles additionnels obligatoires de l’addendum Marketing sont configurés dans les 63 fichiers TOML voisins. Les rôles d’audit restent en lecture seule sur le périmètre qu’ils signent et transmettent leurs findings au propriétaire en écriture.
