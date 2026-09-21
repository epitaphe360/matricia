# Audit ciblé — refonte des parcours sans catalogue

Date : 2026-09-14  
Branche : `codex/refonte-parcours-sans-catalogue`  
Baseline : `028312a` (aucun reset ni migration supprimée).

Légende : `PRESENT` = présent et relié ; `PARTIAL` = fondation existante mais parcours incompatible/incomplet ; `MISSING` = absent ; `INCORRECT` = contredit le nouveau contrat d'expérience.

| Route / domaine | Statut | Composant / données / accès | Boutons et comportement observé | Décision |
|---|---|---|---|---|
| `/[locale]` | INCORRECT | `(public)/page.tsx`; projection statique 10 bibliothèques/200 services | recherche et cartes ouvrent le catalogue | Remplacer par diagnostic public, besoin précis et entrée fournisseur. |
| `/[locale]/services` | INCORRECT | `(public)/services/page.tsx`; `services.json` (200 entrées) | filtre/liste/fiches de services | Garder l'URL, rediriger l'intention vers diagnostic/besoin ; aucun catalogue commercial. |
| `/[locale]/services/[code]` | PARTIAL | vérifie un code dans `services.json` | fiche publique puis connexion | Conserver le code, transférer son contexte à `/besoin`; pas de redirection permanente. |
| `/[locale]/connexion` | PARTIAL | OTP Supabase dans `connexion/otp-form.tsx` | après OTP/password : tableau de bord systématique | Préserver `next` autorisé et le brouillon local, sans faire confiance au paramètre pour les droits. |
| `/[locale]/client/diagnostics` | PARTIAL | `diagnostic_runs`, recommandations, opportunités ; authentifié | sélection manuelle de session + service + score `/100` | Prédiagnostic public séparé, sans score arbitraire; réutilisation ultérieure des primitives authentifiées. |
| `/[locale]/client/demandes/nouvelle` | INCORRECT | `RequestForm`, `service_requests`, RFQ ; authentifié | demande des UUID, hashes et champs internes à la main | Reconnecter depuis bilan/besoin : contexte prérempli, ne redemander que les données nécessaires. |
| `/[locale]/sous-traitant/qualification` | PARTIAL | `provider_profiles`, `provider_services`, versions de capacité/documents/qualifications ; authentifié et RLS | profil, sélection par codes, documents et capacité | Simplifier l'entrée publique, conserver qualification et décisions serveur. |
| `/[locale]/sous-traitant/devis` | PRESENT | invitations accessibles, devis versionnés et calculs exacts | préparation/révision/soumission sous contrôle serveur | Conserver, exposer depuis opportunités plutôt qu'un annuaire public. |
| `/[locale]/tableau-de-bord` | PARTIAL | utilisateur, organisations, module hub | cartes génériques + navigation large | Réorienter les écrans client/fournisseur vers les prochaines actions, sans retirer les modules secondaires. |
| `/[locale]/contact` | INCORRECT | deux liens vers catalogue/connexion, aucune mutation | aucun formulaire | Ajouter un contact minimal, validé côté serveur et explicite si l'envoi externe est indisponible. |
| `/[locale]/a-propos`, `/franchise` | PARTIAL | contenu éditorial public | CTA vers services | Reconnecter les CTA vers diagnostic/besoin et candidature courte. |

## Primitives métier réellement présentes

- Questionnaire versionné et autosave : `supabase/migrations/20260911003700_question_engine_persistence.sql`, fonctions `start_questionnaire_session`, `autosave_questionnaire_answers`, `submit_questionnaire_session` ; RLS et audit/outbox associés. Les 6 000 questions ne seront pas chargées côté navigateur.
- Diagnostics : `diagnostic_runs`, `diagnostic_anomalies`, `diagnostic_recommendations`, `diagnostic_opportunities` dans `20260912007200_diagnostics_opportunities.sql`; affichage actuel dans `apps/web/modules/shared/lib/diagnostics-opportunities`.
- RFQ/demandes : fondation et matching dans `20260912005900_rfq_matching_foundation.sql`, mutations serveur dans `apps/web/modules/client/data/rfq`.
- Fournisseurs : profils, compétences, documents, qualifications et capacité dans `20260912006200_provider_qualification.sql`; les contacts client/fournisseur restent protégés.
- Authentification : OTP avec quota serveur `reserve_otp_request`, Supabase et session ; la destination de retour manque.

## Risques et limites initiales

- Aucune migration n'est justifiée pour le prédiagnostic public tant qu'il ne stocke que des réponses générales, limitées et expirables dans le navigateur. Une conversion authentifiée devra passer par une mutation serveur idempotente et les tables existantes.
- Le formulaire RFQ actuel est une fuite de vocabulaire interne dans l'UX, pas une violation RLS démontrée. Il est remplacé progressivement, pas contourné côté client.
- Les services/fragments publics créés au commit `028312a` sont une orientation désormais remplacée. Les identifiants restent internes et les anciennes URL conservent leur intention.

