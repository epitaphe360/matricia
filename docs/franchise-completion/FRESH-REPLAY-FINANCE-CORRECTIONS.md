# Corrections reproduites par le replay SQL frais

Le responsable a exécuté un replay de 552 migrations et quinze recettes isolées. Les migrations ont toutes été appliquées ; 0362, 0364, 0373 et 0375 ont notamment passé respectivement 27, 106, 23 et 20 assertions. Ces résultats appartiennent à ce replay précis et ne certifient pas les corrections suivantes tant qu’elles ne sont pas rejouées.

0372 s’arrêtait sur `42702` : la variable locale `id` de `create_franchise_finance_rule` rendait ambigu le contrôle d’organisation, puis potentiellement `RETURNING id`. L’additif `20261103455340` qualifie les colonnes en conservant les gardes financières, l’idempotence et la traçabilité de la commande.

0370 démontrait que le rôle sensible était vérifié par un helper qui applique déjà MFA : un compte Finance connu sans assurance recevait donc « accès refusé » au lieu du prérequis MFA. Le nouveau helper privé identifie uniquement la session active et l’attribution courante non révoquée, pour classifier l’erreur. Il n’autorise aucune opération ; l’assertion conserve ensuite le contrôle strict AAL2 et le helper complet d’autorisation existant. Un auditeur en lecture seule demeure interdit d’écriture.

Deux assertions 0370/0376 attendaient un message interne d’un endpoint scanner/serveur, alors qu’EXECUTE est correctement refusé plus tôt par PostgreSQL. Elles attendent désormais cette vraie erreur ACL `42501`. Aucun droit n’est accordé pour atteindre artificiellement le corps de ces fonctions.

Enfin le serveur retourne `can_retry` avec ses critères existants : Finance autorisé AAL2, créateur, pièce UPLOADED, état PENDING/ERROR et aucune lease active. La commande de reprise manuelle remet déjà le compteur automatique à zéro ; ce comportement n’est pas élargi. La recette 0370 produit une véritable réponse scanner ERROR, recharge la capacité, teste les refus pour lease/tiers/auditeur puis la reprise qui reste PENDING. Elle ne transforme jamais une panne en document CLEAN.

Ces correctifs n’ont pas été appliqués par leur auteur à b9 ni à un environnement distant. Le responsable doit exécuter les additifs et recettes avant d’enregistrer leur résultat final.
