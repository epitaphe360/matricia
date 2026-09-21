# Navigation publique proposée

| Intention | Route cible indicative | Action suivante |
| --- | --- | --- |
| Comprendre la proposition Matricia | `/[locale]` | Diagnostic, besoin précis ou parcours professionnel |
| Analyser son entreprise | `/[locale]/diagnostic` | Première question immédiate, sans connexion |
| Lire le bilan indicatif | `/[locale]/diagnostic/resultat` | Corriger, enregistrer ou se faire accompagner |
| Décrire un besoin précis | `/[locale]/besoin` | Confirmer le récapitulatif, puis s'authentifier si nécessaire |
| Proposer ses services | `/[locale]/fournisseur` | Choisir domaine, catégorie et services, puis qualification |
| Découvrir les offres | `/[locale]/abonnements` | Contacter ou poursuivre le parcours approprié |
| Contacter Matricia | `/[locale]/contact` | Envoyer une demande non sensible ou ouvrir l'espace sécurisé |
| Comprendre la franchise | `/[locale]/franchise` | Commencer ou reprendre une candidature |
| Candidater à une franchise | `/[locale]/franchise/candidature` | Évaluation et validation internes |
| Comprendre Matricia | `/[locale]/a-propos` | Choisir une intention utile |
| Explorer les domaines | `/[locale]/services` | Commencer un guidage, pas parcourir un catalogue marchand |
| Préserver une ancienne fiche | `/[locale]/services/[code]` | Transformer l'intention en besoin structuré |
| Se connecter | `/[locale]/connexion` | Recevoir un OTP et reprendre le contexte |
| Créer un compte | `/[locale]/inscription` | Choisir un profil, recevoir un OTP, rattacher le brouillon |
| Vérifier l'identité | `/[locale]/auth/callback` | Reprendre exactement le parcours conservé |
| Consulter les informations légales | routes légales existantes | Lire, exercer ses droits ou gérer ses préférences |
| Gérer une destination invalide | `not-found` / erreur | Accueil, reprise, connexion ou nouvel essai |

Les routes sont une correspondance fonctionnelle destinée à l'intégration. Le code existant doit rester la source pour les chemins définitifs et les redirections historiques.
