# Contrôle Franchisé indépendant — FA08

Source de développement explicite : fusion utilisateur `df67da4`. Ce lot ne modifie aucun environnement hébergé et ne certifie pas la production.

## Comportement

Le nouveau contrôle natif ne consomme aucune mesure manuelle fournie par un administrateur. Un worker appelle une commande service-only bornée, sans choisir lui-même les dates ni injecter de scores. La base calcule les périodes civiles marocaines et génère des rapports quotidiens, mensuels et trimestriels immuables, rejouables et audités. Les transactions par franchise isolent les échecs ; le reçu compte les erreurs et le worker ne les transforme pas en succès.

Les six axes et les poids de référence du Gold Master sont conservés : 20/20/15/20/15/10. Une proposition de modèle versionné exige Admin AAL2 ; son approbation exige un autre administrateur AAL2. Les seuils, la durée des plans et la fraîcheur de l’inventaire sont versionnés. Une même clé avec un autre contenu est refusée.

Une observation absente donne `null`, jamais zéro. Le score global n’existe que si les six axes sont effectivement mesurés. Un catalogue vide est non mesuré ; une vraie identité brouillon incomplète constitue une observation à zéro. Le mandat `NON_CONTRACTUAL_DEMO` ne vaut pas conformité contractuelle réelle. L’exemption IT ne crée aucune dette de droit d’entrée.

## Sources et portée explicite

- Acquisition : invitations réseau réellement acquittées par l’adaptateur externe, ouvertures et inscriptions ; une simple fiche prospect `SENT` et les envois de démonstration ne valent pas un email externe envoyé.
- Bibliothèque : publication courante, traductions approuvées, fraîcheur, questionnaire/questions/règles, checklist et fournisseur qualifié ; les anomalies sans recommandation et services sans fournisseur restent visibles.
- Réseau : candidatures et qualifications courantes valides, délai de qualification.
- Opérations : RFQ, invitations/réponses, devis soumis, missions, échéances et réceptions à temps, corrections.
- Satisfaction : évaluations client natives.
- Conformité : mandat contractuel effectif et obligations de droit d’entrée applicables. Les agrégats de ce contrôle ne remplacent ni la clôture financière ni le rapprochement comptable.

Les événements sont limités à l’intervalle du rapport ; les indicateurs d’inventaire décrivent explicitement l’état à leur collecte. Le grain métier est celui de la bibliothèque mandatée et du réseau propre à la franchise, pas une attribution personnelle des revenus ni une reconstitution rétroactive de l’inventaire. La comparaison anonyme ne publie une médiane qu’à partir de cinq autres franchises comparables complètes. Le rapport conserve son modèle, ses scores, ses compteurs, sa méthode, son lien précédent et l’empreinte du manifeste source ; l’export JSON reste privé et soumis à la même RLS.

Les seuils produisent des alertes figées et une proposition corrective avec objectifs, responsable proposé et échéance. Commentaires et avancement sont append-only et bornés au mandat. Approbation/refus/achèvement exigent Admin AAL2 ; l’achèvement exige une nouvelle mesure native atteignant les objectifs. Ces opérations ne changent jamais automatiquement le statut contractuel d’une franchise.

## Intégration attendue dans la branche principale de travail

- Worker : importer `createFranchisePerformanceScheduler` de `apps/worker/src/franchise-performance.ts`, l’instancier avec le client service existant, l’exécuter comme dépendance indépendante du cycle et de la readiness. Pas de nouveau secret.
- Page Franchisé : charger `loadNativeFranchiseControl(franchiseId, { before, id: beforeId })`, puis rendre `FranchiseNativePerformancePanel` avec `locale`, `result`, `returnPath`. Les capacités d’interaction proviennent de la réponse serveur, jamais d’un rôle supposé dans l’UI.
- L’ancien formulaire reste une déclaration manuelle explicitement nommée ; il ne devient pas le moteur automatique.

## Vérifications réellement exécutées dans ce lot

- Web : 30 tests PASS sur DAL, rendu FR/AR, capacités, états manquants, plans, export privé et actions/messages existants.
- Worker : 10 tests PASS (borne, reçu partiel, panne, reprise, non-chevauchement).
- Types Web et worker PASS ; ESLint ciblé PASS.
- `0365_franchise_native_performance_control.test.sql` fournit une recette native rollback-only à deux mandats TEST, sans désactivation de protection. Son exécution SQL est confiée au rejeu isolé d’intégration ; elle n’est pas déclarée réussie avant ce résultat.
- La recette navigateur, l’intégration effective au worker et la revue indépendante restent à prouver sur le candidat intégré.
