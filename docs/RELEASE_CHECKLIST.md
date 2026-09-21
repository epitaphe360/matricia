# Matricia — checklist de release

Statut global actuel : **FAIL — non signable à ce stade**.

L'arbre local contient des modifications suivies et non suivies : il n'est pas figé en commit candidat. Les PASS ci-dessous décrivent l'état observé au moment de chaque commande et ne valent pas signature du HEAD final.

| Critère | État | Preuve / motif |
|---|---:|---|
| Branche/SHA de production réconciliés | PASS | `codex/bootstrap-foundation` / `b4050fc3...` |
| Build, lint, typecheck | PASS provisoire | exécutés sur l'arbre local audité; à rejouer après gel du HEAD |
| Unitaires/intégration | PASS sur l'arbre courant | 910 tests, dont Web 755/755; replay encore requis après commit/gel du HEAD |
| SQL/RLS | PARTIEL FINAL | 154 fichiers et 3 590 assertions PASS; 311/311 RPC avec indice DENY; migrations 205–207 appliquées en development et dry-run `upToDate=true`; 0154/0155 ciblés + 4 concurrences PASS; replay complet Outbox à refaire sans worker concurrent |
| E2E public et critiques | PARTIEL | 34/34 publics FR/AR/responsive, smoke routes 8/8 et 3/3 authentifiés messagerie/comparaison/matching; MAT-FUNC-020 et le nouveau smoke authentifié 16 scénarios ne sont pas verts; tout rejouer sur le HEAD figé |
| Aucune P0 exploitable reproduite | PASS audit DB | aucun P0 DB/RLS reproduit; preuves fournisseurs distants, signature réelle et outbox bout-en-bout restent des gates de release |
| Taxonomie prestataire structurée | PASS | 10 domaines, 79 catégories actives et 200 services canoniques; sélection structurée, recherche, brouillon et reprise |
| Matrice routes complète | PASS statique / dette runtime | 107 routes classées; 61 exclusions motivées |
| Matrice boutons complète | PASS statique / dette runtime | 614 interactions classées; 249 exclusions motivées; 336 validations runtime restantes |
| RBAC/RLS exhaustif | PASS DENY structurel / dette ALLOW | 438 tables publiques avec RLS; 311/311 RPC référencées avec indice négatif; preuves positives atomiques encore incomplètes |
| FR/AR/RTL toutes routes critiques | PARTIEL | parcours publics critiques verts; espaces authentifiés non parcourus exhaustivement dans les deux langues |
| Responsive 360–1440 | PASS public ciblé | Home, diagnostic, besoin et prestataire contrôlés; page prestataire et services sans overflow de 360 à 1440 px |
| Paiements sandbox | FAIL | tests code présents, intégration distante non prouvée |
| SMTP/OTP réel | FAIL | configuration distante/livraison non prouvée |
| Worker/outbox/ClamAV distants | FAIL | code présent, chaîne distante non prouvée dans cet audit |
| Aucun secret versionné | PASS limité | scans docs/diff propres; poursuivre contrôle final |
| Documentation finale | PASS audit / release FAIL | onze livrables présents; décisions externes et dette de preuve consignées |

La checklist ne passe à PASS qu'avec preuves observées, pas avec une hypothèse de configuration.
