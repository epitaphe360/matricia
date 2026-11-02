# Vérifications exécutées — lot Client

Répertoire d’intégration : `/workspace/audit30`, branche
`codex/client-completion-20261102`. Node 24 et pnpm 10.17.1 via Corepack.
Les appels Docker utilisent le socket local, des conteneurs possédés et isolés ;
aucune commande de migration distante n’a été exécutée.

## Contrôles techniques

| Commande réellement exécutée | Résultat |
| --- | --- |
| `pnpm typecheck` | Réussi après correction de l’union discriminée Box. Les dernières modifications de présentation ont aussi été typées par le build final. |
| `pnpm lint` | Réussi ; ESLint ciblé relancé sur les derniers fichiers modifiés. |
| `NEXT_PUBLIC_APP_URL=https://matricia.test.invalid pnpm build` | Réussi, avec contrôles Next/TypeScript activés. URL canonique synthétique locale, pas un domaine déployé ni une configuration de production approuvée. |
| `pnpm --filter @matricia/web exec vitest run --maxWorkers=2 --exclude '**/signature-documents/pdf.test.ts'` | 2 639 tests réussis ; un test Storage opt-in ignoré explicitement. |
| `pnpm --filter @matricia/web exec vitest run modules/client/screens/abonnement/subscription-upgrade.test.tsx modules/client/screens/abonnement/member-count.test.ts modules/shared/testing/workspace-four-spaces.test.ts modules/shared/lib/signature-documents/pdf.test.ts` | 27 tests réussis, dont les 10 tests PDF FR/AR, sans augmenter leur délai. Les assertions de navigation et de changement d’offre ont été alignées sur le parcours effectivement développé. |
| `pnpm --filter @matricia/web exec vitest run modules/shared/lib/auth/security-href.test.ts modules/client/screens/boxes/member modules/client/screens/boxes/lifecycle modules/client/screens/benefit-refunds modules/client/screens/approbations modules/client/data/rfq/exact-comparison-transport.test.ts` | 59 tests réussis, incluant les derniers changements de liens MFA et de transport monétaire. Ce nombre recouvre des tests déjà présents dans la suite complète ; il ne faut pas les additionner. |
| `pnpm --filter @matricia/web exec vitest run modules/client/screens/portefeuille/calendar-title.test.ts modules/client/screens/portefeuille/portfolio-panel.test.tsx` | 9 tests réussis : libellés documentaires existants FR/AR, codes techniques retirés des titres système, texte libre préservé. |
| `pnpm --filter './packages/**' test` | 137 tests réussis. Les packages sans tests ne sont pas comptés comme des scénarios réussis. |
| `pnpm --filter @matricia/worker test` | 102 tests réussis. |
| `pnpm test:integration` | 3 tests réussis. |
| `pnpm test:tooling` | 31 tests réussis. |
| `node --test tests/e2e/helpers/client-isolated/safety.test.mjs` | 3 tests de garde réussis avant le complément de fidélité des restaurations. |
| `pnpm verify:phase00` | Réussi : catalogue 10/200/6000, registres cohérents, traçabilité contrôlée et exports Server Actions valides. P01 reste ouverte et le registre global demeure à 5/76 exigences VERIFIED. |
| `pnpm release:validate` | Refus global conservé : approbations des registres, contrats atomiques, manifeste et preuves d’interactions de toute l’application manquent. Ce refus n’est pas transformé en succès par le lot Client. |

La première exécution Web a signalé quatre échecs : un délai du PDF arabe sous
charge, deux anciennes assertions de lien de changement d’offre et une ancienne
taille de navigation. Les assertions fonctionnelles ont été corrigées ; la
suite complète hors PDF et le groupe PDF ont ensuite été rejoués avec succès.
Les protections de paiement et le délai des tests n’ont pas été assouplis.

## Base et concurrence

Le script `scripts/validate-local-migration-replay.mjs` a été exécuté avec
`APP_ENV=development` et des arguments `--test=` explicites. Il reconstruit
Auth/Storage, rejoue toutes les migrations, exécute les fixtures en rollback,
vérifie RLS/pgTAP puis supprime son conteneur. Le détail des fichiers et leurs
empreintes est dans les JSON du répertoire [evidence](evidence/).

Le rejeu précédant le dernier correctif RLS a réussi : **456 migrations,
31 fichiers SQL, 815 assertions**, 623 tables publiques, aucune table sans RLS,
aucune fonction pgTAP exécutable par les rôles API, nettoyage réussi. La preuve
est nommée explicitement `sql-replay-before-rls-followup.json` ; elle ne certifie
pas la migration 36000 ajoutée ensuite.

Le dernier rejeu inclut tous les correctifs : **457 migrations, 33 fichiers SQL, 873 assertions réussies**, mêmes 623 tables publiques toutes protégées par RLS, aucun accès API à pgTAP et nettoyage réussi. La preuve complète est [sql-replay-final.json](evidence/sql-replay-final.json). Elle inclut 36000/0343, la compatibilité des achats groupés 0049 et le profil complet 0301 validé par la commande canonique.

Les tentatives initiales arrêtées par le précontrôle de fixtures, les erreurs de
données de test et une interruption de démarrage du conteneur Storage sont
conservées dans `work/isolated-replay/`. Elles ne sont pas des résultats verts.
Le test historique 0247 désactive les triggers : il est exclu de cette recette
stricte. Les tests 0332 et 0340 prouvent les retours de crédits et les imputations
comptables avec les contrôles actifs.

Le harness `supabase/tests/helpers/verify-quota-audit-concurrency.mjs` et trois
cohortes GoTrue natives ont confirmé la résolution du vrai interblocage : une
création, un refus de quota 54000, aucun double effet, aucun retry masquant
l’incident. Le contrôle de chaîne couvre l’acquisition inversée d’identités.
La preuve SQL utilise des acteurs de laboratoire ; la preuve GoTrue est
identifiée séparément.

## Navigateur et limites

Les scripts reproductibles sont dans
[tests/e2e/helpers/client-isolated](../../tests/e2e/helpers/client-isolated/README.md).
Ils utilisent uniquement une pile Supabase jetable, un serveur Next optimisé
sur loopback, de vrais OTP/TOTP et des comptes `example.invalid`.

La matrice initiale figée a parcouru 220 pages (22 entrées × FR/AR × cinq
largeurs), plus 22 contrôles de sécurité natifs. Aucun débordement horizontal,
erreur JavaScript ou mauvais contexte/RTL n’a été observé. Son statut est
**FAILED**, car elle a correctement détecté la récursion RLS des achats groupés,
le profil de test incomplet et l’accès public « Mon espace » masqué à 768 px.
Les preuves finales doivent montrer leur correction ; le simple HTTP 200 n’est
jamais traité comme une réussite métier.

Le portefeuille a passé cinq étapes de vraie saisie UI et lecture RLS : site,
projet, tâche, budget MAD exact et relecture arabe. Le questionnaire a passé onze
étapes : conditions, refus serveur indépendant, sauvegarde, texte libre
bilingue inchangé, perte de réseau/reconnexion/rechargement, clavier, reprise
et soumission finale en lecture seule.

Les dossiers de conformité, documents déjà scannés et règles commerciales de
test restent des fixtures historiques/synthétiques clairement identifiées. La
signature distante, la délivrabilité, les vrais PSP, l’antivirus réel, la
restauration d’un environnement hébergé et une certification exhaustive de tous
les rôles de toute l’application ne découlent pas de ces résultats locaux.

La contre-recette canonique finale est en cours. Le premier clone de navigateur
héritait de droits par défaut du conteneur préinitialisé et d’un ancien
prototype absent du rejeu frais. Il est conservé comme preuve d’investigation ;
une seconde pile est reconstruite depuis les 457 migrations dans une base
`template0`, puis comparée au schéma et aux ACL canoniques. Aucun trigger n’est
retiré de l’ancien clone pour obtenir artificiellement une équivalence.
