from __future__ import annotations

import csv
import json
import re
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any, Iterable

OUT = Path('/mnt/data/Matricia_Catalogue_Metier_V1')
OUT.mkdir(parents=True, exist_ok=True)


def slug(value: str) -> str:
    value = value.lower().strip().replace('&', ' et ').replace('œ', 'oe').replace('æ', 'ae')
    value = unicodedata.normalize('NFKD', value).encode('ascii', 'ignore').decode('ascii')
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return value.strip('_')


@dataclass
class Category:
    library_code: str
    code: str
    name_fr: str
    description_fr: str
    order: int


@dataclass
class Service:
    library_code: str
    category_code: str
    code: str
    name_fr: str
    service_type: str
    unit_label_fr: str
    focus_terms: list[str]
    volume_eligible: bool
    recurring_eligible: bool
    credit_eligible: bool
    order: int


# The service catalog is deliberately explicit. Questions are generated deterministically
# from this curated blueprint; Codex must not invent a different baseline silently.
LIBRARIES: list[dict[str, Any]] = [
    {
        'code': 'IT',
        'name_fr': 'Informatique, cybersécurité et data',
        'description_fr': "Stratégie numérique, infrastructures, logiciels, cybersécurité, données, automatisation et support.",
        'categories': [
            ('IT-GOV', 'Stratégie et gouvernance SI'),
            ('IT-INFRA', 'Infrastructure, réseau et télécom'),
            ('IT-CYBER', 'Cybersécurité et continuité'),
            ('IT-CLOUD', 'Cloud et collaboration'),
            ('IT-DEV', 'Développement Web, mobile et logiciels'),
            ('IT-DATA', 'Data, BI et intelligence artificielle'),
            ('IT-SUPPORT', 'Support, maintenance et infogérance'),
            ('IT-IOT', 'IoT, vidéosurveillance et systèmes connectés'),
        ],
        'services': [
            ('IT-GOV', 'IT-AUDIT-SI', 'Audit du système d’information et feuille de route', 'AUDIT', 'utilisateurs, sites et applications', ['cartographie du SI', 'gouvernance', 'risques prioritaires', 'budget numérique', 'feuille de route']),
            ('IT-GOV', 'IT-ARCHI', 'Architecture et urbanisation du système d’information', 'ADVISORY', 'applications et flux', ['architecture actuelle', 'flux de données', 'interopérabilité', 'dette technique', 'architecture cible']),
            ('IT-INFRA', 'IT-NETWORK', 'Conception et installation réseau LAN/Wi-Fi', 'IMPLEMENTATION', 'sites, zones et points réseau', ['couverture Wi-Fi', 'points réseau', 'débits attendus', 'segmentation', 'câblage']),
            ('IT-INFRA', 'IT-FIREWALL', 'Déploiement de pare-feu et sécurisation réseau', 'IMPLEMENTATION', 'sites et connexions', ['pare-feu existant', 'VPN', 'filtrage', 'haute disponibilité', 'journalisation']),
            ('IT-INFRA', 'IT-VOIP', 'Téléphonie IP, centre d’appels et communications unifiées', 'IMPLEMENTATION', 'postes, numéros et sites', ['nombre de postes', 'numéros existants', 'files d’appels', 'enregistrement', 'intégration CRM']),
            ('IT-CYBER', 'IT-CYBER-AUDIT', 'Audit de cybersécurité', 'AUDIT', 'utilisateurs, actifs et sites', ['périmètre d’audit', 'normes visées', 'vulnérabilités', 'gestion des accès', 'plan de remédiation']),
            ('IT-CYBER', 'IT-PENTEST', 'Test d’intrusion Web, mobile ou infrastructure', 'AUDIT', 'applications, IP et environnements', ['cibles autorisées', 'type de test', 'fenêtre de tir', 'règles d’engagement', 'rapport de preuve']),
            ('IT-CYBER', 'IT-SOC-MDR', 'Supervision SOC/MDR et réponse aux incidents', 'MANAGED_SERVICE', 'postes, serveurs et journaux', ['sources de logs', 'couverture 24/7', 'temps de réponse', 'EDR/XDR', 'escalade incident']),
            ('IT-CYBER', 'IT-BACKUP', 'Sauvegarde, restauration et archivage', 'IMPLEMENTATION', 'Go/To, postes, serveurs et sites', ['volume de données', 'fréquence', 'rétention', 'RPO/RTO', 'tests de restauration']),
            ('IT-CYBER', 'IT-BCP-DRP', 'Plan de continuité et plan de reprise informatique', 'ADVISORY', 'processus et systèmes critiques', ['processus critiques', 'RTO', 'RPO', 'sites de repli', 'exercices de crise']),
            ('IT-CLOUD', 'IT-CLOUD-MIG', 'Migration vers le cloud', 'IMPLEMENTATION', 'applications, serveurs et données', ['workloads à migrer', 'cloud cible', 'dépendances', 'fenêtre de migration', 'réversibilité']),
            ('IT-CLOUD', 'IT-M365', 'Déploiement Microsoft 365 ou Google Workspace', 'IMPLEMENTATION', 'comptes et domaines', ['nombre de comptes', 'messagerie actuelle', 'domaines', 'migration de fichiers', 'sécurité des identités']),
            ('IT-DEV', 'IT-WEB-SHOWCASE', 'Création de site Web vitrine', 'CREATIVE_TECH', 'pages, langues et formulaires', ['nombre de pages', 'langues', 'identité visuelle', 'contenus', 'hébergement et domaine']),
            ('IT-DEV', 'IT-ECOMMERCE', 'Création de boutique e-commerce', 'CREATIVE_TECH', 'produits, commandes et langues', ['catalogue produits', 'paiement', 'livraison', 'stock', 'intégrations ERP']),
            ('IT-DEV', 'IT-WEB-APP', 'Développement d’application Web métier', 'SOFTWARE_PROJECT', 'utilisateurs, modules et workflows', ['rôles utilisateurs', 'modules', 'workflows', 'intégrations', 'données à migrer']),
            ('IT-DEV', 'IT-MOBILE-APP', 'Développement d’application mobile', 'SOFTWARE_PROJECT', 'plateformes, utilisateurs et écrans', ['iOS/Android', 'fonctionnalités', 'mode hors ligne', 'notifications', 'publication stores']),
            ('IT-DEV', 'IT-ERP-CRM', 'Implémentation ou intégration ERP/CRM', 'SOFTWARE_PROJECT', 'utilisateurs, modules et entités', ['processus métier', 'modules', 'reprise des données', 'interfaces', 'formation']),
            ('IT-DATA', 'IT-BI', 'Data warehouse et tableaux de bord BI', 'DATA_PROJECT', 'sources, indicateurs et utilisateurs', ['sources de données', 'KPI', 'fréquence de rafraîchissement', 'qualité des données', 'droits d’accès']),
            ('IT-DATA', 'IT-AI-AUTO', 'Automatisation IA, assistants et chatbots', 'AI_PROJECT', 'processus, documents et utilisateurs', ['cas d’usage', 'sources de connaissance', 'actions automatisées', 'validation humaine', 'confidentialité']),
            ('IT-IOT', 'IT-CCTV-IOT', 'Vidéosurveillance, contrôle d’accès et IoT', 'IMPLEMENTATION', 'caméras, portes, capteurs et sites', ['zones à couvrir', 'rétention vidéo', 'accès distant', 'détection intelligente', 'alimentation et réseau']),
        ],
    },
    {
        'code': 'COM',
        'name_fr': 'Communication, marketing et création',
        'description_fr': "Stratégie de marque, contenus, acquisition, communication digitale, audiovisuel et événements.",
        'categories': [
            ('COM-STRAT', 'Stratégie marketing et marque'),
            ('COM-DESIGN', 'Identité visuelle et design'),
            ('COM-CONTENT', 'Contenus et rédaction'),
            ('COM-DIGITAL', 'Marketing digital et réseaux sociaux'),
            ('COM-ADS', 'Publicité et acquisition'),
            ('COM-AV', 'Photo, vidéo et motion design'),
            ('COM-PR', 'Relations publiques et influence'),
            ('COM-EVENT', 'Événementiel, impression et signalétique'),
        ],
        'services': [
            ('COM-STRAT', 'COM-MKT-STRAT', 'Stratégie marketing globale', 'ADVISORY', 'marchés, segments et offres', ['objectifs marketing', 'segments cibles', 'positionnement', 'canaux', 'indicateurs']),
            ('COM-STRAT', 'COM-BRAND', 'Plateforme de marque et stratégie de branding', 'CREATIVE_STRATEGY', 'marques et gammes', ['raison d’être', 'positionnement', 'promesse', 'personnalité', 'architecture de marque']),
            ('COM-STRAT', 'COM-NAMING', 'Naming de marque, produit ou service', 'CREATIVE_STRATEGY', 'noms et territoires', ['univers lexical', 'marchés linguistiques', 'disponibilité souhaitée', 'contraintes juridiques', 'critères de sélection']),
            ('COM-DESIGN', 'COM-VISUAL-ID', 'Identité visuelle et charte graphique', 'CREATIVE', 'supports et déclinaisons', ['logo existant', 'univers visuel', 'supports prioritaires', 'formats', 'charte attendue']),
            ('COM-DESIGN', 'COM-GRAPHIC', 'Création graphique et supports commerciaux', 'CREATIVE', 'visuels et formats', ['type de support', 'dimensions', 'quantités', 'contenus fournis', 'contraintes d’impression']),
            ('COM-CONTENT', 'COM-COPY', 'Rédaction Web, commerciale et institutionnelle', 'CONTENT', 'pages, articles et langues', ['ton éditorial', 'cibles', 'volumes de mots', 'SEO', 'sources disponibles']),
            ('COM-CONTENT', 'COM-CONTENT-PLAN', 'Stratégie éditoriale et calendrier de contenu', 'CONTENT_STRATEGY', 'canaux et publications', ['canaux', 'fréquence', 'thématiques', 'formats', 'processus de validation']),
            ('COM-DIGITAL', 'COM-SOCIAL-STRAT', 'Stratégie réseaux sociaux', 'ADVISORY', 'réseaux et audiences', ['plateformes', 'audiences', 'objectifs', 'ligne éditoriale', 'indicateurs']),
            ('COM-DIGITAL', 'COM-COMMUNITY', 'Community management', 'MANAGED_SERVICE', 'comptes et publications', ['réseaux', 'fréquence', 'modération', 'réponses clients', 'reporting']),
            ('COM-DIGITAL', 'COM-SEO', 'Référencement naturel SEO', 'MANAGED_SERVICE', 'sites, pages et mots-clés', ['site cible', 'marchés', 'mots-clés', 'contenus', 'SEO technique']),
            ('COM-DIGITAL', 'COM-EMAIL', 'E-mail marketing et automatisation', 'CAMPAIGN', 'contacts et scénarios', ['taille base', 'consentements', 'scénarios', 'outil actuel', 'objectifs de conversion']),
            ('COM-ADS', 'COM-DIGITAL-ADS', 'Campagnes publicitaires digitales', 'CAMPAIGN', 'campagnes, audiences et budgets', ['plateformes publicitaires', 'budget média', 'cibles', 'créatifs', 'conversion']),
            ('COM-ADS', 'COM-MEDIA', 'Plan média et achat d’espace', 'CAMPAIGN', 'supports et périodes', ['zone', 'audience', 'budget', 'supports', 'mesure d’impact']),
            ('COM-AV', 'COM-PHOTO', 'Photographie corporate, produit ou immobilière', 'CREATIVE_PRODUCTION', 'photos, produits et lieux', ['type de shooting', 'nombre de produits', 'lieux', 'retouches', 'droits d’usage']),
            ('COM-AV', 'COM-VIDEO', 'Production vidéo corporate ou publicitaire', 'CREATIVE_PRODUCTION', 'vidéos et durées', ['objectif', 'durée', 'scénario', 'lieux', 'formats de diffusion']),
            ('COM-AV', 'COM-MOTION', 'Motion design et animation', 'CREATIVE_PRODUCTION', 'séquences et durées', ['style graphique', 'durée', 'voix-off', 'langues', 'formats']),
            ('COM-PR', 'COM-PR', 'Relations presse et relations publiques', 'MANAGED_SERVICE', 'campagnes et médias', ['messages clés', 'porte-parole', 'médias cibles', 'calendrier', 'gestion de crise']),
            ('COM-PR', 'COM-INFLUENCE', 'Marketing d’influence', 'CAMPAIGN', 'créateurs et contenus', ['cible', 'plateformes', 'nombre de créateurs', 'formats', 'droits de réutilisation']),
            ('COM-EVENT', 'COM-EVENT', 'Conception et communication événementielle', 'EVENT', 'participants, jours et lieux', ['type d’événement', 'participants', 'lieu', 'programme', 'prestations techniques']),
            ('COM-EVENT', 'COM-PRINT-SIGN', 'Impression, PLV et signalétique', 'PRODUCTION', 'unités, formats et sites', ['supports', 'dimensions', 'quantités', 'matières', 'installation']),
        ],
    },
    {
        'code': 'ACC',
        'name_fr': 'Comptabilité, fiscalité et finance',
        'description_fr': "Tenue comptable, fiscalité, pilotage financier, trésorerie, financement et transformation de la fonction finance.",
        'categories': [
            ('ACC-BOOK', 'Comptabilité et clôture'),
            ('ACC-TAX', 'Fiscalité et déclarations'),
            ('ACC-CTRL', 'Contrôle de gestion et performance'),
            ('ACC-CASH', 'Trésorerie et recouvrement'),
            ('ACC-FIN', 'Financement et modélisation'),
            ('ACC-AUDIT', 'Audit et due diligence'),
            ('ACC-SYS', 'Systèmes et digitalisation finance'),
            ('ACC-SPECIAL', 'Opérations comptables spécialisées'),
        ],
        'services': [
            ('ACC-BOOK', 'ACC-BOOKKEEPING', 'Tenue comptable externalisée', 'OUTSOURCING', 'écritures, comptes et mois', ['volume de pièces', 'logiciel', 'périodicité', 'plan comptable', 'mode de transmission']),
            ('ACC-BOOK', 'ACC-CLEANUP', 'Rattrapage et régularisation comptable', 'PROJECT', 'mois, écritures et comptes', ['périodes en retard', 'volume de pièces', 'écarts connus', 'logiciel', 'date de clôture']),
            ('ACC-BOOK', 'ACC-CLOSE', 'Clôture mensuelle et annuelle', 'OUTSOURCING', 'entités et périodes', ['calendrier de clôture', 'réconciliations', 'provisions', 'immobilisations', 'reporting attendu']),
            ('ACC-BOOK', 'ACC-FS', 'Préparation des états financiers', 'PROJECT', 'entités et exercices', ['référentiel', 'période', 'balances disponibles', 'annexes', 'date limite']),
            ('ACC-TAX', 'ACC-VAT', 'Déclarations de TVA', 'OUTSOURCING', 'déclarations et périodes', ['régime TVA', 'fréquence', 'volume factures', 'opérations internationales', 'crédits TVA']),
            ('ACC-TAX', 'ACC-CORP-TAX', 'Déclarations fiscales et impôt sur les sociétés', 'OUTSOURCING', 'entités et exercices', ['régime fiscal', 'résultat comptable', 'réintégrations', 'incitations', 'échéances']),
            ('ACC-TAX', 'ACC-TAX-REVIEW', 'Revue fiscale et diagnostic de conformité', 'AUDIT', 'taxes et exercices', ['impôts concernés', 'années', 'contrôles antérieurs', 'risques identifiés', 'documents disponibles']),
            ('ACC-TAX', 'ACC-TAX-AUDIT', 'Assistance lors d’un contrôle fiscal', 'ADVISORY', 'notifications et exercices', ['avis reçu', 'périmètre', 'délais', 'montants en jeu', 'pièces demandées']),
            ('ACC-CTRL', 'ACC-BUDGET', 'Budget annuel et prévisions', 'ADVISORY', 'centres, scénarios et mois', ['horizon', 'centres de coûts', 'hypothèses', 'scénarios', 'format de restitution']),
            ('ACC-CTRL', 'ACC-MGMT-CONTROL', 'Mise en place du contrôle de gestion', 'ADVISORY', 'processus et indicateurs', ['modèle économique', 'axes analytiques', 'KPI', 'fréquence', 'outils']),
            ('ACC-CTRL', 'ACC-COSTING', 'Calcul des coûts et rentabilité par produit', 'ADVISORY', 'produits, activités et centres', ['méthode actuelle', 'charges directes', 'inducteurs', 'volumes', 'marges attendues']),
            ('ACC-CASH', 'ACC-TREASURY', 'Gestion et prévision de trésorerie', 'ADVISORY', 'comptes et semaines', ['comptes bancaires', 'horizon', 'encaissements', 'décaissements', 'alertes']),
            ('ACC-CASH', 'ACC-COLLECTION', 'Optimisation du recouvrement client', 'MANAGED_SERVICE', 'factures et clients', ['balance âgée', 'processus de relance', 'litiges', 'outils', 'objectifs DSO']),
            ('ACC-CASH', 'ACC-INVOICING', 'Mise en place de la facturation et des contrôles', 'IMPLEMENTATION', 'factures et utilisateurs', ['types de factures', 'workflow', 'taxes', 'numérotation', 'intégrations']),
            ('ACC-FIN', 'ACC-FIN-MODEL', 'Modèle financier et business plan', 'ADVISORY', 'années et scénarios', ['horizon', 'sources de revenus', 'charges', 'investissements', 'scénarios']),
            ('ACC-FIN', 'ACC-FUNDING', 'Préparation d’un dossier de financement', 'ADVISORY', 'banques et montants', ['montant recherché', 'usage des fonds', 'garanties', 'prévisions', 'documents juridiques']),
            ('ACC-AUDIT', 'ACC-AUDIT-PREP', 'Préparation à l’audit financier', 'AUDIT_SUPPORT', 'entités et cycles', ['auditeur', 'périmètre', 'PBC list', 'réconciliations', 'deadline']),
            ('ACC-AUDIT', 'ACC-DUE-DIL', 'Due diligence financière', 'AUDIT', 'entités et années', ['objectif transaction', 'période', 'data room', 'qualité des résultats', 'dette nette']),
            ('ACC-SYS', 'ACC-SOFTWARE', 'Choix et déploiement d’un logiciel comptable', 'IMPLEMENTATION', 'utilisateurs et entités', ['processus', 'utilisateurs', 'fonctionnalités', 'migration', 'intégrations']),
            ('ACC-SPECIAL', 'ACC-INVENTORY', 'Inventaire physique et valorisation des stocks', 'PROJECT', 'références, sites et unités', ['nombre de références', 'sites', 'méthode de comptage', 'valorisation', 'écarts historiques']),
        ],
    },
    {
        'code': 'LEGAL',
        'name_fr': 'Juridique, conformité et gouvernance',
        'description_fr': "Droit des affaires, contrats, gouvernance, conformité, propriété intellectuelle et prévention des litiges.",
        'categories': [
            ('LEGAL-CORP', 'Droit des sociétés et gouvernance'),
            ('LEGAL-CONTRACT', 'Contrats commerciaux'),
            ('LEGAL-LABOR', 'Droit du travail'),
            ('LEGAL-IP', 'Propriété intellectuelle et numérique'),
            ('LEGAL-COMP', 'Conformité réglementaire et éthique'),
            ('LEGAL-DISPUTE', 'Précontentieux et contentieux'),
            ('LEGAL-REAL', 'Immobilier et baux'),
            ('LEGAL-TRANS', 'Transactions et partenariats'),
        ],
        'services': [
            ('LEGAL-CORP', 'LEGAL-CREATE', 'Création et structuration de société', 'LEGAL_ADVISORY', 'associés et entités', ['forme juridique', 'associés', 'capital', 'activité', 'gouvernance']),
            ('LEGAL-CORP', 'LEGAL-CORP-SECRETARY', 'Secrétariat juridique annuel', 'MANAGED_SERVICE', 'entités et actes', ['assemblées', 'modifications', 'registres', 'mandats', 'calendrier']),
            ('LEGAL-CORP', 'LEGAL-GOV', 'Mise en place de la gouvernance et délégations', 'LEGAL_ADVISORY', 'organes et décisions', ['organes de gouvernance', 'délégations', 'seuils', 'comités', 'reporting']),
            ('LEGAL-CONTRACT', 'LEGAL-CONTRACT-DRAFT', 'Rédaction de contrat commercial', 'LEGAL_SERVICE', 'contrats et parties', ['objet', 'parties', 'prix', 'responsabilités', 'droit applicable']),
            ('LEGAL-CONTRACT', 'LEGAL-CONTRACT-REVIEW', 'Revue et négociation de contrat', 'LEGAL_SERVICE', 'contrats et versions', ['document source', 'enjeux', 'clauses critiques', 'deadline', 'pouvoir de négociation']),
            ('LEGAL-CONTRACT', 'LEGAL-GTC', 'Conditions générales de vente ou d’utilisation', 'LEGAL_SERVICE', 'canaux et offres', ['modèle de vente', 'clients', 'paiement', 'livraison', 'réclamations']),
            ('LEGAL-LABOR', 'LEGAL-EMPLOYMENT', 'Contrats de travail et documents RH', 'LEGAL_SERVICE', 'salariés et modèles', ['types de contrats', 'catégories', 'rémunération', 'confidentialité', 'mobilité']),
            ('LEGAL-LABOR', 'LEGAL-HR-DISPUTE', 'Assistance en conflit ou procédure disciplinaire', 'LEGAL_ADVISORY', 'salariés et incidents', ['faits', 'preuves', 'chronologie', 'mesures prises', 'urgence']),
            ('LEGAL-IP', 'LEGAL-TRADEMARK', 'Dépôt et protection de marque', 'LEGAL_SERVICE', 'marques et classes', ['signe', 'territoires', 'classes', 'recherche antérieure', 'propriétaire']),
            ('LEGAL-IP', 'LEGAL-IP-CONTRACT', 'Contrats de propriété intellectuelle et licences', 'LEGAL_SERVICE', 'œuvres, logiciels et territoires', ['actifs', 'droits cédés', 'territoire', 'durée', 'rémunération']),
            ('LEGAL-IP', 'LEGAL-PRIVACY', 'Conformité données personnelles et politique de confidentialité', 'COMPLIANCE', 'traitements et sites', ['données collectées', 'finalités', 'sous-traitants', 'consentements', 'transferts']),
            ('LEGAL-COMP', 'LEGAL-COMPLIANCE-AUDIT', 'Audit de conformité réglementaire', 'COMPLIANCE', 'réglementations et processus', ['secteur', 'textes applicables', 'licences', 'contrôles', 'risques']),
            ('LEGAL-COMP', 'LEGAL-ETHICS', 'Code éthique, anticorruption et dispositif d’alerte', 'COMPLIANCE', 'entités et salariés', ['risques d’intégrité', 'cadeaux', 'tiers', 'canal d’alerte', 'enquêtes']),
            ('LEGAL-COMP', 'LEGAL-LICENSE', 'Obtention ou renouvellement d’agrément/licence', 'LEGAL_SERVICE', 'autorisations et sites', ['autorité', 'activité', 'conditions', 'documents', 'deadline']),
            ('LEGAL-DISPUTE', 'LEGAL-DEBT-RECOVERY', 'Recouvrement amiable et juridique', 'LEGAL_SERVICE', 'débiteurs et créances', ['montants', 'échéances', 'preuves', 'relances', 'solvabilité']),
            ('LEGAL-DISPUTE', 'LEGAL-PRE-LITIGATION', 'Mise en demeure et stratégie précontentieuse', 'LEGAL_ADVISORY', 'litiges et parties', ['faits', 'contrat', 'preuves', 'préjudice', 'objectif']),
            ('LEGAL-DISPUTE', 'LEGAL-LITIGATION', 'Coordination et suivi d’un contentieux', 'LEGAL_SERVICE', 'dossiers et audiences', ['juridiction', 'étape', 'avocat', 'preuves', 'échéances']),
            ('LEGAL-REAL', 'LEGAL-LEASE', 'Rédaction ou revue de bail commercial', 'LEGAL_SERVICE', 'locaux et parties', ['local', 'durée', 'loyer', 'charges', 'travaux']),
            ('LEGAL-TRANS', 'LEGAL-SHA', 'Pacte d’associés ou convention de partenariat', 'LEGAL_SERVICE', 'associés et décisions', ['répartition capital', 'gouvernance', 'sortie', 'financement', 'non-concurrence']),
            ('LEGAL-TRANS', 'LEGAL-FRANCHISE', 'Contrat et structuration de franchise', 'LEGAL_SERVICE', 'franchisés et territoires', ['concept', 'droits d’entrée', 'redevances', 'territoire', 'assistance']),
        ],
    },
    {
        'code': 'HR',
        'name_fr': 'Ressources humaines et formation',
        'description_fr': "Organisation RH, recrutement, compétences, performance, formation, administration du personnel et climat social.",
        'categories': [
            ('HR-STRAT', 'Stratégie et organisation RH'),
            ('HR-REC', 'Recrutement et intégration'),
            ('HR-PERF', 'Performance, compétences et carrière'),
            ('HR-COMP', 'Rémunération et avantages'),
            ('HR-ADMIN', 'Administration RH et paie'),
            ('HR-TRAIN', 'Formation et développement'),
            ('HR-REL', 'Relations sociales et engagement'),
            ('HR-DIGI', 'SIRH et digitalisation RH'),
        ],
        'services': [
            ('HR-STRAT', 'HR-AUDIT', 'Audit RH et plan d’action', 'AUDIT', 'salariés et sites', ['organisation RH', 'effectifs', 'processus', 'risques sociaux', 'priorités']),
            ('HR-STRAT', 'HR-WORKFORCE', 'Planification des effectifs et emplois', 'ADVISORY', 'postes et années', ['prévisions activité', 'effectifs', 'compétences', 'turnover', 'scénarios']),
            ('HR-STRAT', 'HR-JOB-DESC', 'Fiches de poste et référentiel métiers', 'PROJECT', 'postes et familles', ['organigramme', 'missions', 'responsabilités', 'compétences', 'indicateurs']),
            ('HR-REC', 'HR-RECRUIT', 'Recrutement de profils', 'RECRUITMENT', 'postes et candidats', ['poste', 'niveau', 'localisation', 'rémunération', 'date de prise de poste']),
            ('HR-REC', 'HR-EXEC-SEARCH', 'Chasse de cadres et dirigeants', 'RECRUITMENT', 'postes et marchés', ['mandat', 'profil cible', 'entreprises cibles', 'confidentialité', 'package']),
            ('HR-REC', 'HR-ONBOARD', 'Parcours d’intégration des nouveaux salariés', 'PROJECT', 'postes et sites', ['étapes', 'responsables', 'documents', 'formation', 'période d’essai']),
            ('HR-PERF', 'HR-PERFORMANCE', 'Système d’évaluation de la performance', 'IMPLEMENTATION', 'salariés et cycles', ['objectifs', 'compétences', 'fréquence', 'workflow', 'calibration']),
            ('HR-PERF', 'HR-COMPETENCY', 'Référentiel de compétences et gestion des carrières', 'PROJECT', 'métiers et niveaux', ['familles métiers', 'niveaux', 'compétences', 'mobilité', 'succession']),
            ('HR-PERF', 'HR-SUCCESSION', 'Plans de succession et hauts potentiels', 'ADVISORY', 'postes clés et talents', ['postes critiques', 'critères', 'talents', 'plans de développement', 'gouvernance']),
            ('HR-COMP', 'HR-COMP-BEN', 'Politique de rémunération et avantages', 'ADVISORY', 'postes et salariés', ['grilles actuelles', 'benchmark', 'bonus', 'avantages', 'équité interne']),
            ('HR-COMP', 'HR-PAYROLL', 'Externalisation ou sécurisation de la paie', 'OUTSOURCING', 'bulletins et salariés', ['effectif', 'variables', 'outil', 'calendrier', 'contrôles']),
            ('HR-ADMIN', 'HR-ADMIN', 'Administration du personnel externalisée', 'OUTSOURCING', 'salariés et actes', ['contrats', 'absences', 'dossiers salariés', 'attestations', 'reporting']),
            ('HR-ADMIN', 'HR-TIME', 'Gestion du temps, absences et planning', 'IMPLEMENTATION', 'salariés et sites', ['horaires', 'équipes', 'badges', 'règles absence', 'intégration paie']),
            ('HR-TRAIN', 'HR-TRAIN-NEEDS', 'Analyse des besoins de formation', 'ADVISORY', 'salariés et métiers', ['objectifs', 'écarts compétences', 'populations', 'budget', 'priorités']),
            ('HR-TRAIN', 'HR-TRAIN-DELIVERY', 'Conception et animation de formation', 'TRAINING', 'participants et sessions', ['thème', 'niveau', 'participants', 'format', 'évaluation']),
            ('HR-REL', 'HR-ENGAGEMENT', 'Enquête d’engagement et climat social', 'SURVEY', 'salariés et sites', ['population', 'anonymat', 'thèmes', 'communication', 'plan d’action']),
            ('HR-REL', 'HR-RELATIONS', 'Gestion des relations sociales', 'ADVISORY', 'sites et instances', ['instances', 'accords', 'conflits', 'calendrier', 'priorités']),
            ('HR-REL', 'HR-DISCIPLINE', 'Processus disciplinaire et gestion des dossiers sensibles', 'ADVISORY', 'dossiers et salariés', ['faits', 'preuves', 'règles internes', 'chronologie', 'mesures']),
            ('HR-DIGI', 'HR-HRIS', 'Choix et déploiement d’un SIRH', 'IMPLEMENTATION', 'salariés, modules et utilisateurs', ['modules', 'effectif', 'intégrations', 'migration', 'droits']),
            ('HR-DIGI', 'HR-OUTSOURCING', 'Direction RH externalisée', 'MANAGED_SERVICE', 'salariés et mois', ['périmètre', 'présence souhaitée', 'processus', 'reporting', 'gouvernance']),
        ],
    },
    {
        'code': 'INS',
        'name_fr': 'Assurance et gestion des risques',
        'description_fr': "Cartographie des risques, conception des couvertures, appels d’offres assureurs et gestion des sinistres.",
        'categories': [
            ('INS-RISK', 'Audit et cartographie des risques'),
            ('INS-PROP', 'Biens et pertes d’exploitation'),
            ('INS-LIAB', 'Responsabilités'),
            ('INS-PEOPLE', 'Protection des personnes'),
            ('INS-SPEC', 'Risques spécialisés'),
            ('INS-FLEET', 'Flotte, transport et logistique'),
            ('INS-CLAIM', 'Sinistres et prévention'),
            ('INS-PROGRAM', 'Programme d’assurance et appels d’offres'),
        ],
        'services': [
            ('INS-RISK', 'INS-RISK-AUDIT', 'Audit global des risques assurables', 'RISK_AUDIT', 'sites et risques', ['activités', 'sites', 'sinistres', 'valeurs exposées', 'tolérance au risque']),
            ('INS-RISK', 'INS-MAP', 'Cartographie et plan de traitement des risques', 'RISK_AUDIT', 'processus et risques', ['processus critiques', 'probabilité', 'impact', 'contrôles', 'priorités']),
            ('INS-PROP', 'INS-PROPERTY', 'Assurance multirisque des biens', 'INSURANCE_PLACEMENT', 'sites et valeurs', ['bâtiments', 'contenu', 'stocks', 'protections', 'historique sinistres']),
            ('INS-PROP', 'INS-BI', 'Assurance pertes d’exploitation', 'INSURANCE_PLACEMENT', 'sites et mois', ['marge brute', 'période indemnisation', 'dépendances', 'plan de continuité', 'scénario majeur']),
            ('INS-LIAB', 'INS-GL', 'Responsabilité civile exploitation', 'INSURANCE_PLACEMENT', 'activités et CA', ['activités', 'chiffre d’affaires', 'territoires', 'clients', 'sinistres']),
            ('INS-LIAB', 'INS-PRO-LIAB', 'Responsabilité civile professionnelle', 'INSURANCE_PLACEMENT', 'missions et CA', ['services rendus', 'contrats', 'limites souhaitées', 'territoires', 'réclamations']),
            ('INS-LIAB', 'INS-PRODUCT', 'Responsabilité produits', 'INSURANCE_PLACEMENT', 'produits et marchés', ['produits', 'volumes', 'pays', 'traçabilité', 'rappels']),
            ('INS-LIAB', 'INS-DNO', 'Responsabilité des dirigeants', 'INSURANCE_PLACEMENT', 'dirigeants et entités', ['structure', 'gouvernance', 'actionnariat', 'litiges', 'levées de fonds']),
            ('INS-PEOPLE', 'INS-HEALTH', 'Assurance santé collective', 'INSURANCE_PLACEMENT', 'salariés et ayants droit', ['effectif', 'population', 'garanties', 'réseau', 'budget']),
            ('INS-PEOPLE', 'INS-LIFE', 'Décès, invalidité et prévoyance collective', 'INSURANCE_PLACEMENT', 'salariés et catégories', ['catégories', 'capitaux', 'invalidité', 'bénéficiaires', 'budget']),
            ('INS-PEOPLE', 'INS-WORK-ACC', 'Accidents du travail et risques professionnels', 'INSURANCE_PLACEMENT', 'salariés et métiers', ['métiers', 'effectifs', 'sites', 'sinistres', 'mesures prévention']),
            ('INS-SPEC', 'INS-CYBER', 'Assurance cyber', 'INSURANCE_PLACEMENT', 'utilisateurs et CA', ['données', 'contrôles cyber', 'incidents', 'chiffre d’affaires', 'limites']),
            ('INS-SPEC', 'INS-CONSTRUCTION', 'Tous risques chantier et responsabilité décennale', 'INSURANCE_PLACEMENT', 'chantiers et montants', ['nature chantier', 'budget', 'durée', 'intervenants', 'garanties']),
            ('INS-SPEC', 'INS-CREDIT', 'Assurance-crédit clients', 'INSURANCE_PLACEMENT', 'clients et encours', ['encours', 'pays', 'concentration', 'impayés', 'politique crédit']),
            ('INS-FLEET', 'INS-FLEET', 'Assurance flotte automobile', 'INSURANCE_PLACEMENT', 'véhicules et conducteurs', ['parc', 'usage', 'conducteurs', 'sinistres', 'franchises']),
            ('INS-FLEET', 'INS-CARGO', 'Assurance transport de marchandises', 'INSURANCE_PLACEMENT', 'expéditions et valeurs', ['marchandises', 'modes', 'routes', 'valeurs', 'incoterms']),
            ('INS-CLAIM', 'INS-CLAIMS', 'Gestion et optimisation des sinistres', 'CLAIMS_MANAGEMENT', 'sinistres et polices', ['type sinistre', 'date', 'montant', 'preuves', 'avancement']),
            ('INS-CLAIM', 'INS-PREVENTION', 'Plan de prévention et réduction des sinistres', 'RISK_ADVISORY', 'sites et actions', ['risques dominants', 'sinistres', 'contrôles', 'investissements', 'KPI']),
            ('INS-PROGRAM', 'INS-POLICY-AUDIT', 'Audit des polices et garanties existantes', 'AUDIT', 'polices et entités', ['polices', 'exclusions', 'limites', 'franchises', 'doublons']),
            ('INS-PROGRAM', 'INS-TENDER', 'Appel d’offres assureurs et renouvellement', 'PROCUREMENT', 'polices et assureurs', ['échéance', 'périmètre', 'sinistralité', 'marché', 'objectifs']),
        ],
    },
    {
        'code': 'LOG',
        'name_fr': 'Achats, logistique et supply chain',
        'description_fr': "Sourcing, achats, fournisseurs, stocks, entrepôts, transport, import-export et continuité d’approvisionnement.",
        'categories': [
            ('LOG-PROC', 'Stratégie achats et sourcing'),
            ('LOG-SUP', 'Gestion des fournisseurs'),
            ('LOG-SPEND', 'Dépenses et performance achats'),
            ('LOG-INV', 'Stocks et prévisions'),
            ('LOG-WH', 'Entrepôts et opérations'),
            ('LOG-TRANS', 'Transport et distribution'),
            ('LOG-TRADE', 'Import-export et douane'),
            ('LOG-DIGI', 'Digitalisation et résilience supply chain'),
        ],
        'services': [
            ('LOG-PROC', 'LOG-PROC-AUDIT', 'Audit de la fonction achats', 'AUDIT', 'catégories et fournisseurs', ['organisation', 'dépenses', 'processus', 'contrats', 'gouvernance']),
            ('LOG-PROC', 'LOG-SOURCING-STRAT', 'Stratégie de sourcing et catégories', 'ADVISORY', 'catégories et marchés', ['catégories', 'enjeux', 'marché fournisseurs', 'risques', 'objectifs']),
            ('LOG-PROC', 'LOG-SUPPLIER-SEARCH', 'Recherche et présélection de fournisseurs', 'SOURCING', 'fournisseurs et pays', ['produit/service', 'spécifications', 'pays', 'quantités', 'certifications']),
            ('LOG-PROC', 'LOG-TENDER', 'Gestion d’appel d’offres fournisseurs', 'PROCUREMENT', 'lots et soumissionnaires', ['cahier des charges', 'lots', 'critères', 'calendrier', 'négociation']),
            ('LOG-SUP', 'LOG-SUP-QUAL', 'Qualification et homologation fournisseurs', 'AUDIT', 'fournisseurs et sites', ['critères', 'documents', 'audit', 'échantillons', 'risque']),
            ('LOG-SUP', 'LOG-SUP-PERF', 'Évaluation et performance fournisseurs', 'ADVISORY', 'fournisseurs et KPI', ['qualité', 'délai', 'coût', 'service', 'plans d’action']),
            ('LOG-SUP', 'LOG-CONTRACT-NEG', 'Négociation et optimisation des contrats achats', 'ADVISORY', 'contrats et catégories', ['contrats', 'volumes', 'prix', 'SLA', 'clauses de sortie']),
            ('LOG-SPEND', 'LOG-SPEND-ANALYSIS', 'Analyse des dépenses et économies', 'DATA_PROJECT', 'transactions et catégories', ['sources', 'période', 'codification', 'fournisseurs', 'objectifs économies']),
            ('LOG-SPEND', 'LOG-E-PROC', 'Mise en place d’un processus e-procurement', 'IMPLEMENTATION', 'utilisateurs et workflows', ['processus', 'catalogues', 'approbations', 'budgets', 'intégrations']),
            ('LOG-INV', 'LOG-INVENTORY-OPT', 'Optimisation des niveaux de stock', 'ADVISORY', 'références et sites', ['historique', 'lead times', 'service cible', 'saisonnalité', 'contraintes stockage']),
            ('LOG-INV', 'LOG-FORECAST', 'Prévision de la demande et S&OP', 'DATA_PROJECT', 'références et mois', ['historique ventes', 'promotions', 'horizon', 'granularité', 'processus S&OP']),
            ('LOG-WH', 'LOG-WH-DESIGN', 'Conception ou optimisation d’entrepôt', 'ENGINEERING', 'm², références et flux', ['surface', 'flux', 'volumes', 'équipements', 'contraintes bâtiment']),
            ('LOG-WH', 'LOG-WMS', 'Choix et déploiement WMS', 'IMPLEMENTATION', 'utilisateurs, sites et références', ['processus', 'volumes', 'matériels', 'intégrations', 'migration']),
            ('LOG-WH', 'LOG-PICKING', 'Optimisation préparation de commandes', 'ADVISORY', 'commandes et lignes', ['profils commandes', 'layout', 'méthodes', 'temps', 'erreurs']),
            ('LOG-TRANS', 'LOG-TRANS-TENDER', 'Appel d’offres transporteurs', 'PROCUREMENT', 'routes et expéditions', ['routes', 'volumes', 'fréquence', 'SLA', 'contraintes marchandises']),
            ('LOG-TRANS', 'LOG-ROUTE', 'Optimisation des tournées et du dernier kilomètre', 'DATA_PROJECT', 'livraisons et véhicules', ['adresses', 'fenêtres', 'véhicules', 'capacités', 'KPI']),
            ('LOG-TRADE', 'LOG-CUSTOMS', 'Assistance douane et conformité import-export', 'ADVISORY', 'produits et déclarations', ['produits', 'pays', 'codes douaniers', 'incoterms', 'documents']),
            ('LOG-TRADE', 'LOG-IMPORT', 'Organisation d’opérations import-export', 'MANAGED_SERVICE', 'expéditions et conteneurs', ['origine/destination', 'marchandises', 'volumes', 'délais', 'assurance']),
            ('LOG-DIGI', 'LOG-SC-DIGITAL', 'Digitalisation et tableau de bord supply chain', 'DATA_PROJECT', 'sources et KPI', ['systèmes', 'KPI', 'fréquence', 'alertes', 'utilisateurs']),
            ('LOG-DIGI', 'LOG-BCP', 'Plan de continuité supply chain', 'RISK_ADVISORY', 'fournisseurs et scénarios', ['fournisseurs critiques', 'single source', 'stocks sécurité', 'alternatives', 'scénarios']),
        ],
    },
    {
        'code': 'BTP',
        'name_fr': 'BTP, immobilier et maintenance',
        'description_fr': "Études, construction, rénovation, installations techniques, gestion immobilière et maintenance des actifs.",
        'categories': [
            ('BTP-STUDY', 'Études et conception'),
            ('BTP-COST', 'Économie de la construction'),
            ('BTP-WORK', 'Construction et rénovation'),
            ('BTP-MEP', 'Lots techniques'),
            ('BTP-SAFE', 'Sécurité et systèmes spéciaux'),
            ('BTP-ENERGY', 'Énergie et durabilité'),
            ('BTP-FM', 'Facility management et maintenance'),
            ('BTP-REAL', 'Immobilier, inspection et aménagement'),
        ],
        'services': [
            ('BTP-STUDY', 'BTP-FEAS', 'Étude de faisabilité immobilière ou chantier', 'ENGINEERING', 'm² et sites', ['objectif projet', 'terrain/bâtiment', 'programme', 'budget', 'contraintes']),
            ('BTP-STUDY', 'BTP-ARCH', 'Conception architecturale', 'DESIGN_ENGINEERING', 'm², niveaux et espaces', ['programme', 'surface', 'style', 'réglementation', 'niveau de détail']),
            ('BTP-STUDY', 'BTP-STRUCT', 'Étude de structure', 'ENGINEERING', 'm² et éléments', ['type structure', 'plans', 'charges', 'sol', 'normes']),
            ('BTP-STUDY', 'BTP-GEO', 'Étude géotechnique', 'ENGINEERING', 'sondages et parcelles', ['site', 'surface', 'projet', 'sondages', 'accès']),
            ('BTP-STUDY', 'BTP-MEP-DESIGN', 'Études électricité, plomberie et CVC', 'ENGINEERING', 'm² et systèmes', ['usage bâtiment', 'puissance', 'besoins eau', 'climatisation', 'plans']),
            ('BTP-COST', 'BTP-QS', 'Métré, estimation et bordereau de prix', 'ENGINEERING', 'lots et m²', ['plans disponibles', 'lots', 'niveau précision', 'base prix', 'deadline']),
            ('BTP-COST', 'BTP-PM', 'Maîtrise d’œuvre et gestion de projet chantier', 'PROJECT_MANAGEMENT', 'lots, mois et sites', ['périmètre', 'planning', 'intervenants', 'budget', 'reporting']),
            ('BTP-WORK', 'BTP-GC', 'Construction tous corps d’état', 'CONSTRUCTION', 'm² et lots', ['plans', 'surface', 'lots', 'délai', 'conditions site']),
            ('BTP-WORK', 'BTP-RENOV', 'Rénovation de bâtiment ou local', 'CONSTRUCTION', 'm² et espaces', ['état existant', 'travaux', 'occupation', 'finitions', 'délai']),
            ('BTP-WORK', 'BTP-FITOUT', 'Aménagement intérieur et fit-out', 'CONSTRUCTION', 'm² et postes', ['usage', 'plans', 'mobilier', 'finitions', 'contraintes exploitation']),
            ('BTP-MEP', 'BTP-ELEC', 'Installation et mise à niveau électrique', 'CONSTRUCTION', 'points et puissances', ['puissance', 'tableaux', 'points', 'mise à la terre', 'tests']),
            ('BTP-MEP', 'BTP-PLUMB', 'Plomberie, sanitaires et réseaux d’eau', 'CONSTRUCTION', 'points et réseaux', ['plans', 'points', 'pression', 'évacuation', 'équipements']),
            ('BTP-MEP', 'BTP-HVAC', 'Climatisation, ventilation et traitement d’air', 'CONSTRUCTION', 'zones et kW', ['surfaces', 'occupation', 'température', 'qualité air', 'équipements']),
            ('BTP-SAFE', 'BTP-FIRE', 'Détection et protection incendie', 'CONSTRUCTION', 'zones et équipements', ['usage', 'surface', 'risques', 'système existant', 'évacuation']),
            ('BTP-SAFE', 'BTP-SECURITY', 'Contrôle d’accès, alarme et sûreté bâtiment', 'CONSTRUCTION', 'portes, zones et utilisateurs', ['zones', 'portes', 'badges', 'intégrations', 'supervision']),
            ('BTP-ENERGY', 'BTP-SOLAR', 'Installation solaire photovoltaïque', 'ENERGY_PROJECT', 'kWc et sites', ['consommation', 'toiture', 'puissance', 'autoconsommation', 'raccordement']),
            ('BTP-ENERGY', 'BTP-ENERGY-AUDIT', 'Audit énergétique de bâtiment', 'AUDIT', 'sites et compteurs', ['factures énergie', 'surface', 'équipements', 'horaires', 'objectifs']),
            ('BTP-FM', 'BTP-MAINT', 'Contrat de maintenance multi-technique', 'MANAGED_SERVICE', 'sites et équipements', ['inventaire actifs', 'fréquence', 'SLA', 'astreinte', 'pièces']),
            ('BTP-REAL', 'BTP-INSPECTION', 'Inspection technique et diagnostic bâtiment', 'AUDIT', 'm² et éléments', ['objectif', 'pathologies', 'plans', 'accès', 'rapport attendu']),
            ('BTP-REAL', 'BTP-LANDSCAPE', 'Aménagement paysager, piscine et extérieurs', 'CONSTRUCTION', 'm² et zones', ['terrain', 'style', 'végétation', 'arrosage', 'équipements']),
        ],
    },
    {
        'code': 'QHSE',
        'name_fr': 'Qualité, HSE et certifications',
        'description_fr': "Systèmes de management, audits, sécurité au travail, environnement, sécurité alimentaire et préparation aux certifications.",
        'categories': [
            ('QHSE-QMS', 'Qualité et processus'),
            ('QHSE-ENV', 'Environnement'),
            ('QHSE-OHS', 'Santé et sécurité au travail'),
            ('QHSE-FOOD', 'Sécurité alimentaire'),
            ('QHSE-LAB', 'Laboratoires et métrologie'),
            ('QHSE-AUDIT', 'Audits et amélioration'),
            ('QHSE-DOC', 'Documentation et digitalisation'),
            ('QHSE-CERT', 'Préparation aux certifications'),
        ],
        'services': [
            ('QHSE-QMS', 'QHSE-ISO9001', 'Mise en place ISO 9001', 'COMPLIANCE_PROJECT', 'processus et sites', ['périmètre', 'processus', 'documentation', 'indicateurs', 'certification cible']),
            ('QHSE-QMS', 'QHSE-PROCESS', 'Cartographie et optimisation des processus', 'ADVISORY', 'processus et départements', ['processus', 'interfaces', 'irritants', 'KPI', 'outils']),
            ('QHSE-QMS', 'QHSE-SUPPLIER-QUALITY', 'Qualité fournisseurs', 'COMPLIANCE_PROJECT', 'fournisseurs et familles', ['critères', 'contrôles', 'non-conformités', 'audits', 'KPI']),
            ('QHSE-ENV', 'QHSE-ISO14001', 'Mise en place ISO 14001', 'COMPLIANCE_PROJECT', 'sites et aspects', ['aspects environnementaux', 'obligations', 'objectifs', 'déchets', 'urgence']),
            ('QHSE-ENV', 'QHSE-ENV-AUDIT', 'Audit environnemental', 'AUDIT', 'sites et impacts', ['activités', 'émissions', 'rejets', 'déchets', 'autorisations']),
            ('QHSE-ENV', 'QHSE-WASTE', 'Plan de gestion des déchets', 'ADVISORY', 'flux et tonnes', ['types déchets', 'quantités', 'stockage', 'prestataires', 'traçabilité']),
            ('QHSE-OHS', 'QHSE-ISO45001', 'Mise en place ISO 45001', 'COMPLIANCE_PROJECT', 'sites et salariés', ['dangers', 'évaluation risques', 'consultation', 'incidents', 'objectifs']),
            ('QHSE-OHS', 'QHSE-SAFETY-AUDIT', 'Audit santé et sécurité au travail', 'AUDIT', 'sites et postes', ['activités', 'dangers', 'EPI', 'formations', 'incidents']),
            ('QHSE-OHS', 'QHSE-RISK-ASSESS', 'Évaluation des risques professionnels', 'AUDIT', 'postes et unités', ['unités de travail', 'tâches', 'exposition', 'mesures', 'priorités']),
            ('QHSE-OHS', 'QHSE-HSE-PLAN', 'Plan HSE chantier ou site', 'COMPLIANCE_PROJECT', 'sites et intervenants', ['projet', 'effectifs', 'risques', 'sous-traitants', 'urgence']),
            ('QHSE-FOOD', 'QHSE-HACCP', 'Mise en place HACCP', 'COMPLIANCE_PROJECT', 'produits et lignes', ['produits', 'diagrammes', 'dangers', 'CCP', 'traçabilité']),
            ('QHSE-FOOD', 'QHSE-ISO22000', 'Mise en place ISO 22000', 'COMPLIANCE_PROJECT', 'sites et produits', ['périmètre', 'PRP', 'HACCP', 'fournisseurs', 'certification']),
            ('QHSE-FOOD', 'QHSE-FOOD-AUDIT', 'Audit hygiène et sécurité alimentaire', 'AUDIT', 'sites et zones', ['activité', 'zones', 'produits', 'nettoyage', 'contrôles']),
            ('QHSE-LAB', 'QHSE-ISO17025', 'Préparation ISO/IEC 17025 laboratoire', 'COMPLIANCE_PROJECT', 'méthodes et équipements', ['portée', 'méthodes', 'compétences', 'métrologie', 'essais aptitude']),
            ('QHSE-LAB', 'QHSE-METROLOGY', 'Gestion de métrologie et étalonnage', 'MANAGED_SERVICE', 'équipements et fréquences', ['inventaire', 'criticité', 'tolérances', 'fréquence', 'prestataires']),
            ('QHSE-AUDIT', 'QHSE-INTERNAL-AUDIT', 'Audit interne de système de management', 'AUDIT', 'processus et jours', ['référentiel', 'périmètre', 'sites', 'auditeurs', 'planning']),
            ('QHSE-AUDIT', 'QHSE-CAPA', 'Gestion des non-conformités et CAPA', 'IMPLEMENTATION', 'incidents et processus', ['sources', 'workflow', 'analyse causes', 'délais', 'efficacité']),
            ('QHSE-DOC', 'QHSE-DOC-MGMT', 'Système documentaire qualité/HSE', 'IMPLEMENTATION', 'documents et utilisateurs', ['documents', 'approbations', 'versions', 'diffusion', 'outil']),
            ('QHSE-CERT', 'QHSE-INTEGRATED', 'Système intégré Qualité-Environnement-Sécurité', 'COMPLIANCE_PROJECT', 'référentiels et sites', ['référentiels', 'processus communs', 'documentation', 'audits', 'certification']),
            ('QHSE-CERT', 'QHSE-CERT-PREP', 'Préparation et accompagnement à la certification', 'COMPLIANCE_PROJECT', 'sites et audits', ['référentiel', 'organisme', 'date cible', 'écarts', 'pré-audit']),
        ],
    },
    {
        'code': 'SALES',
        'name_fr': 'Commercial, vente et expérience client',
        'description_fr': "Stratégie commerciale, acquisition, CRM, canaux, performance des ventes, service client et expérience client.",
        'categories': [
            ('SALES-STRAT', 'Stratégie commerciale et marché'),
            ('SALES-PROC', 'Processus et performance de vente'),
            ('SALES-CRM', 'CRM et automatisation commerciale'),
            ('SALES-LEAD', 'Prospection et génération de leads'),
            ('SALES-TEAM', 'Organisation et compétences commerciales'),
            ('SALES-CHANNEL', 'Canaux, partenaires et export'),
            ('SALES-CX', 'Expérience et fidélisation client'),
            ('SALES-SERVICE', 'Service client et centres de contact'),
        ],
        'services': [
            ('SALES-STRAT', 'SALES-AUDIT', 'Audit commercial', 'AUDIT', 'équipes, canaux et offres', ['organisation', 'pipeline', 'conversion', 'outils', 'priorités']),
            ('SALES-STRAT', 'SALES-GTM', 'Stratégie go-to-market', 'ADVISORY', 'marchés, segments et offres', ['marché', 'segments', 'proposition de valeur', 'canaux', 'lancement']),
            ('SALES-STRAT', 'SALES-MARKET-RESEARCH', 'Étude de marché et segmentation clients', 'RESEARCH', 'segments et zones', ['objectif', 'marché', 'géographie', 'méthode', 'décisions attendues']),
            ('SALES-STRAT', 'SALES-PRICING', 'Stratégie de prix et politique commerciale', 'ADVISORY', 'offres et segments', ['coûts', 'concurrence', 'élasticité', 'remises', 'gouvernance']),
            ('SALES-PROC', 'SALES-PROCESS', 'Conception du processus de vente', 'IMPLEMENTATION', 'étapes et équipes', ['cycle de vente', 'étapes', 'critères', 'approbations', 'KPI']),
            ('SALES-PROC', 'SALES-PIPELINE', 'Mise en place du pipeline et prévisions commerciales', 'IMPLEMENTATION', 'opportunités et équipes', ['étapes', 'probabilités', 'forecast', 'revues', 'outils']),
            ('SALES-PROC', 'SALES-TENDER', 'Réponse aux appels d’offres commerciaux', 'MANAGED_SERVICE', 'dossiers et lots', ['dossier', 'deadline', 'exigences', 'références', 'prix']),
            ('SALES-CRM', 'SALES-CRM-IMPL', 'Choix et déploiement CRM', 'IMPLEMENTATION', 'utilisateurs et pipelines', ['processus', 'utilisateurs', 'données', 'intégrations', 'automatisations']),
            ('SALES-CRM', 'SALES-SALES-AUTO', 'Automatisation commerciale et séquences', 'IMPLEMENTATION', 'contacts et scénarios', ['sources leads', 'séquences', 'canaux', 'règles', 'mesure']),
            ('SALES-LEAD', 'SALES-LEADGEN', 'Génération de leads B2B/B2C', 'CAMPAIGN', 'leads et marchés', ['cible', 'volume', 'canaux', 'critères qualité', 'coût cible']),
            ('SALES-LEAD', 'SALES-TELEMARKETING', 'Téléprospection et prise de rendez-vous', 'MANAGED_SERVICE', 'contacts et rendez-vous', ['cible', 'script', 'volume appels', 'qualification', 'planning']),
            ('SALES-LEAD', 'SALES-SCRIPTS', 'Scripts, argumentaires et outils d’aide à la vente', 'CONTENT', 'offres et équipes', ['offres', 'objections', 'personas', 'canaux', 'formats']),
            ('SALES-TEAM', 'SALES-ORG', 'Organisation et dimensionnement de la force de vente', 'ADVISORY', 'commerciaux et territoires', ['effectif', 'territoires', 'portefeuilles', 'objectifs', 'rémunération']),
            ('SALES-TEAM', 'SALES-TRAIN', 'Formation et coaching commercial', 'TRAINING', 'participants et sessions', ['niveau', 'compétences', 'produits', 'format', 'évaluation']),
            ('SALES-TEAM', 'SALES-KAM', 'Programme grands comptes et key account management', 'ADVISORY', 'comptes et responsables', ['comptes stratégiques', 'potentiel', 'plans de compte', 'gouvernance', 'KPI']),
            ('SALES-CHANNEL', 'SALES-CHANNEL', 'Réseau de distributeurs et partenaires', 'ADVISORY', 'partenaires et territoires', ['modèle canal', 'territoires', 'marges', 'contrats', 'animation']),
            ('SALES-CHANNEL', 'SALES-EXPORT', 'Développement commercial à l’export', 'ADVISORY', 'pays et marchés', ['pays cibles', 'offre', 'réglementation', 'partenaires', 'budget']),
            ('SALES-CX', 'SALES-CX-MAP', 'Cartographie du parcours et expérience client', 'RESEARCH', 'parcours et segments', ['segments', 'points de contact', 'irritants', 'données', 'priorités']),
            ('SALES-CX', 'SALES-LOYALTY', 'Programme de fidélité et rétention', 'IMPLEMENTATION', 'clients et avantages', ['base clients', 'comportements', 'récompenses', 'canaux', 'économie programme']),
            ('SALES-SERVICE', 'SALES-CUSTOMER-SERVICE', 'Mise en place ou optimisation du service client', 'IMPLEMENTATION', 'agents et canaux', ['volumes contacts', 'canaux', 'SLA', 'outils', 'qualité']),
        ],
    },
]

# Add a 10th domain that was intentionally separated from QHSE/BTP.
LIBRARIES.insert(5, {
    'code': 'OPS',
    'name_fr': 'Opérations, productivité et transformation',
    'description_fr': "Excellence opérationnelle, organisation, processus, productivité, digitalisation et pilotage de la transformation.",
    'categories': [
        ('OPS-STRAT', 'Stratégie opérationnelle'),
        ('OPS-PROC', 'Processus et organisation'),
        ('OPS-LEAN', 'Lean et amélioration continue'),
        ('OPS-PMO', 'Gestion de projets et PMO'),
        ('OPS-PROD', 'Production et planification'),
        ('OPS-SERVICE', 'Opérations de services'),
        ('OPS-DIGI', 'Digitalisation des opérations'),
        ('OPS-CHANGE', 'Conduite du changement'),
    ],
    'services': [
        ('OPS-STRAT', 'OPS-AUDIT', 'Diagnostic de performance opérationnelle', 'AUDIT', 'processus, sites et équipes', ['objectifs', 'processus', 'coûts', 'délais', 'goulots']),
        ('OPS-STRAT', 'OPS-OPERATING-MODEL', 'Conception du modèle opérationnel cible', 'ADVISORY', 'fonctions et sites', ['organisation', 'rôles', 'gouvernance', 'processus', 'indicateurs']),
        ('OPS-PROC', 'OPS-PROCESS-MAP', 'Cartographie et refonte des processus', 'ADVISORY', 'processus et activités', ['périmètre', 'acteurs', 'entrées/sorties', 'irritants', 'contrôles']),
        ('OPS-PROC', 'OPS-SOP', 'Création de procédures et modes opératoires', 'CONTENT_PROJECT', 'procédures et postes', ['processus', 'niveau de détail', 'supports', 'validation', 'formation']),
        ('OPS-PROC', 'OPS-ORG-DESIGN', 'Organisation, rôles et responsabilités', 'ADVISORY', 'postes et équipes', ['organigramme', 'charges', 'responsabilités', 'interfaces', 'dimensionnement']),
        ('OPS-LEAN', 'OPS-LEAN', 'Programme Lean et réduction des gaspillages', 'TRANSFORMATION', 'lignes et processus', ['flux', 'gaspillages', 'temps', 'qualité', 'équipes']),
        ('OPS-LEAN', 'OPS-SIX-SIGMA', 'Projet Six Sigma et réduction de variabilité', 'TRANSFORMATION', 'processus et défauts', ['CTQ', 'données', 'défauts', 'capabilité', 'objectifs']),
        ('OPS-LEAN', 'OPS-5S', 'Déploiement 5S et management visuel', 'IMPLEMENTATION', 'zones et équipes', ['zones', 'standards', 'audits', 'matériel', 'animation']),
        ('OPS-PMO', 'OPS-PMO', 'Mise en place d’un PMO', 'IMPLEMENTATION', 'projets et chefs de projet', ['portefeuille', 'méthodologie', 'gouvernance', 'outils', 'reporting']),
        ('OPS-PMO', 'OPS-PROJECT-RECOVERY', 'Redressement de projet en difficulté', 'PROJECT_MANAGEMENT', 'projets et lots', ['situation', 'retards', 'budget', 'risques', 'décisions']),
        ('OPS-PROD', 'OPS-PRODUCTION-PLAN', 'Planification et ordonnancement de production', 'ADVISORY', 'références et lignes', ['capacités', 'demandes', 'gammes', 'stocks', 'contraintes']),
        ('OPS-PROD', 'OPS-OEE', 'Amélioration du rendement et TRS/OEE', 'TRANSFORMATION', 'machines et lignes', ['disponibilité', 'performance', 'qualité', 'arrêts', 'données']),
        ('OPS-PROD', 'OPS-MAINT-EXCELLENCE', 'Excellence maintenance et fiabilité', 'TRANSFORMATION', 'équipements et sites', ['criticité', 'pannes', 'préventif', 'pièces', 'GMAO']),
        ('OPS-SERVICE', 'OPS-SERVICE-DESIGN', 'Conception et optimisation d’opérations de services', 'ADVISORY', 'dossiers et équipes', ['parcours', 'volumes', 'SLA', 'ressources', 'qualité']),
        ('OPS-SERVICE', 'OPS-BACKOFFICE', 'Optimisation du back-office', 'TRANSFORMATION', 'transactions et équipes', ['types de dossiers', 'volumes', 'délais', 'erreurs', 'automatisation']),
        ('OPS-DIGI', 'OPS-RPA', 'Automatisation RPA des processus', 'AUTOMATION', 'processus et robots', ['tâches', 'volumes', 'applications', 'exceptions', 'ROI']),
        ('OPS-DIGI', 'OPS-BPM', 'Déploiement BPM et workflows', 'IMPLEMENTATION', 'processus et utilisateurs', ['workflows', 'règles', 'formulaires', 'intégrations', 'SLA']),
        ('OPS-DIGI', 'OPS-KPI', 'Tableau de bord opérationnel et KPI', 'DATA_PROJECT', 'indicateurs et sources', ['KPI', 'sources', 'fréquence', 'alertes', 'utilisateurs']),
        ('OPS-CHANGE', 'OPS-CHANGE', 'Conduite du changement', 'CHANGE_MANAGEMENT', 'populations et sites', ['transformation', 'impacts', 'parties prenantes', 'communication', 'adoption']),
        ('OPS-CHANGE', 'OPS-TRAIN-COACH', 'Formation et coaching des équipes opérationnelles', 'TRAINING', 'participants et sessions', ['compétences', 'niveau', 'format', 'mise en pratique', 'évaluation']),
    ],
})

# Ensure exactly ten libraries. OPS replaces the original sales count issue by making 11; drop none? We now have IT,COM,ACC,LEGAL,HR,OPS,INS,LOG,BTP,QHSE,SALES = 11.
# The original Matricia brief requires 10. Keep SALES and remove OPS from the production baseline; OPS services can be imported later as an optional library.
OPTIONAL_LIBRARY = LIBRARIES.pop(5)


MACRO_CATEGORY_MAP: dict[str, list[tuple[str, str, list[str]]]] = {
    'IT': [
        ('IT-MACRO-GOV', 'Stratégie, gouvernance et architecture', ['IT-GOV']),
        ('IT-MACRO-INFRA', 'Infrastructure, cloud et communications', ['IT-INFRA', 'IT-CLOUD']),
        ('IT-MACRO-CYBER', 'Cybersécurité, sauvegarde et continuité', ['IT-CYBER']),
        ('IT-MACRO-DIGITAL', 'Applications, données et systèmes connectés', ['IT-DEV', 'IT-DATA', 'IT-SUPPORT', 'IT-IOT']),
    ],
    'COM': [
        ('COM-MACRO-BRAND', 'Stratégie, marque et positionnement', ['COM-STRAT']),
        ('COM-MACRO-CONTENT', 'Design, contenus et production créative', ['COM-DESIGN', 'COM-CONTENT', 'COM-AV']),
        ('COM-MACRO-ACQ', 'Marketing digital, acquisition et fidélisation', ['COM-DIGITAL', 'COM-ADS']),
        ('COM-MACRO-INFLUENCE', 'Relations publiques, influence et événements', ['COM-PR', 'COM-EVENT']),
    ],
    'ACC': [
        ('ACC-MACRO-ACCOUNTING', 'Comptabilité, clôture et fiscalité', ['ACC-BOOK', 'ACC-TAX']),
        ('ACC-MACRO-PERF', 'Performance, coûts et trésorerie', ['ACC-CTRL', 'ACC-CASH']),
        ('ACC-MACRO-FIN', 'Financement, audit et transaction', ['ACC-FIN', 'ACC-AUDIT']),
        ('ACC-MACRO-SYSTEMS', 'Systèmes financiers et opérations spécialisées', ['ACC-SYS', 'ACC-SPECIAL']),
    ],
    'LEGAL': [
        ('LEGAL-MACRO-CORP', 'Sociétés, gouvernance et partenariats', ['LEGAL-CORP', 'LEGAL-TRANS']),
        ('LEGAL-MACRO-CONTRACT', 'Contrats commerciaux et droit du travail', ['LEGAL-CONTRACT', 'LEGAL-LABOR']),
        ('LEGAL-MACRO-COMP', 'Propriété intellectuelle et conformité', ['LEGAL-IP', 'LEGAL-COMP']),
        ('LEGAL-MACRO-DISPUTE', 'Litiges, recouvrement et immobilier', ['LEGAL-DISPUTE', 'LEGAL-REAL']),
    ],
    'HR': [
        ('HR-MACRO-ORG', 'Stratégie RH et organisation', ['HR-STRAT']),
        ('HR-MACRO-TALENT', 'Recrutement, intégration et talents', ['HR-REC', 'HR-PERF']),
        ('HR-MACRO-REWARD', 'Rémunération, administration et paie', ['HR-COMP', 'HR-ADMIN']),
        ('HR-MACRO-DEV', 'Formation, relations sociales et digital RH', ['HR-TRAIN', 'HR-REL', 'HR-DIGI']),
    ],
    'INS': [
        ('INS-MACRO-RISK', 'Audit des risques et protection des actifs', ['INS-RISK', 'INS-PROP']),
        ('INS-MACRO-LIAB', 'Responsabilités et protection des personnes', ['INS-LIAB', 'INS-PEOPLE']),
        ('INS-MACRO-SPECIAL', 'Risques spécialisés, flotte et transport', ['INS-SPEC', 'INS-FLEET']),
        ('INS-MACRO-PROGRAM', 'Prévention, sinistres et programme d’assurance', ['INS-CLAIM', 'INS-PROGRAM']),
    ],
    'LOG': [
        ('LOG-MACRO-PROC', 'Achats, sourcing et fournisseurs', ['LOG-PROC', 'LOG-SUP']),
        ('LOG-MACRO-PLAN', 'Dépenses, stocks et planification', ['LOG-SPEND', 'LOG-INV']),
        ('LOG-MACRO-OPS', 'Entrepôts, transport et distribution', ['LOG-WH', 'LOG-TRANS']),
        ('LOG-MACRO-TRADE', 'Commerce international, digitalisation et résilience', ['LOG-TRADE', 'LOG-DIGI']),
    ],
    'BTP': [
        ('BTP-MACRO-DESIGN', 'Études, conception et économie de la construction', ['BTP-STUDY', 'BTP-COST']),
        ('BTP-MACRO-WORK', 'Construction, rénovation et lots techniques', ['BTP-WORK', 'BTP-MEP']),
        ('BTP-MACRO-SAFE', 'Sécurité, énergie et durabilité', ['BTP-SAFE', 'BTP-ENERGY']),
        ('BTP-MACRO-ASSET', 'Maintenance, immobilier et aménagement', ['BTP-FM', 'BTP-REAL']),
    ],
    'QHSE': [
        ('QHSE-MACRO-QE', 'Qualité, processus et environnement', ['QHSE-QMS', 'QHSE-ENV']),
        ('QHSE-MACRO-HS', 'Santé, sécurité et sécurité alimentaire', ['QHSE-OHS', 'QHSE-FOOD']),
        ('QHSE-MACRO-LAB', 'Laboratoires, métrologie et audits', ['QHSE-LAB', 'QHSE-AUDIT']),
        ('QHSE-MACRO-CERT', 'Documentation et certifications', ['QHSE-DOC', 'QHSE-CERT']),
    ],
    'SALES': [
        ('SALES-MACRO-STRAT', 'Stratégie de marché et processus commercial', ['SALES-STRAT', 'SALES-PROC']),
        ('SALES-MACRO-ACQ', 'CRM, automatisation et acquisition', ['SALES-CRM', 'SALES-LEAD']),
        ('SALES-MACRO-ORG', 'Organisation commerciale, canaux et export', ['SALES-TEAM', 'SALES-CHANNEL']),
        ('SALES-MACRO-CX', 'Expérience, fidélisation et service client', ['SALES-CX', 'SALES-SERVICE']),
    ],
}

SUBCATEGORY_TO_MACRO = {
    sub: macro_code
    for lib_groups in MACRO_CATEGORY_MAP.values()
    for macro_code, _macro_name, subs in lib_groups
    for sub in subs
}


SECONDARY_SERVICE_SUBCATEGORIES: dict[str, list[str]] = {
    'IT-SOC-MDR': ['IT-SUPPORT'],
    'IT-M365': ['IT-SUPPORT'],
    'IT-ERP-CRM': ['IT-SUPPORT'],
    'COM-COPY': ['COM-DIGITAL'],
    'ACC-INVOICING': ['ACC-SYS'],
    'LEGAL-PRIVACY': ['LEGAL-COMP'],
    'HR-PAYROLL': ['HR-ADMIN'],
    'INS-CYBER': ['INS-RISK'],
    'LOG-WMS': ['LOG-DIGI'],
    'BTP-SECURITY': ['BTP-FM'],
    'QHSE-CAPA': ['QHSE-QMS'],
    'SALES-CRM-IMPL': ['SALES-PROC'],
}


TYPE_PROFILES: dict[str, dict[str, Any]] = {
    'AUDIT': {'deliverables': 'rapport de diagnostic, constats, priorités et plan d’action', 'proof': 'rapport signé et restitution', 'recurring': False},
    'ADVISORY': {'deliverables': 'analyse, recommandations, feuille de route et ateliers', 'proof': 'livrables validés et compte rendu', 'recurring': False},
    'LEGAL_ADVISORY': {'deliverables': 'analyse juridique, options, risques et recommandations', 'proof': 'note ou avis validé', 'recurring': False},
    'LEGAL_SERVICE': {'deliverables': 'document juridique versionné, commentaires et version finale', 'proof': 'document final et validation du client', 'recurring': False},
    'COMPLIANCE': {'deliverables': 'diagnostic, registre, politiques et plan de mise en conformité', 'proof': 'dossier de conformité et preuves', 'recurring': False},
    'COMPLIANCE_PROJECT': {'deliverables': 'système documenté, preuves de déploiement et préparation audit', 'proof': 'documents, enregistrements et audit blanc', 'recurring': False},
    'IMPLEMENTATION': {'deliverables': 'solution installée, configurée, testée et documentée', 'proof': 'PV de tests, documentation et réception', 'recurring': False},
    'SOFTWARE_PROJECT': {'deliverables': 'application, code, documentation, tests et déploiement', 'proof': 'recette fonctionnelle et accès livrés', 'recurring': False},
    'AI_PROJECT': {'deliverables': 'cas d’usage, prototype, intégrations, garde-fous et documentation', 'proof': 'tests, mesures et validation métier', 'recurring': False},
    'DATA_PROJECT': {'deliverables': 'modèle de données, pipelines, tableaux de bord et documentation', 'proof': 'contrôles qualité et validation KPI', 'recurring': False},
    'CREATIVE_TECH': {'deliverables': 'design, réalisation, intégration, mise en ligne et accès', 'proof': 'site fonctionnel et recette', 'recurring': False},
    'CREATIVE_STRATEGY': {'deliverables': 'territoires créatifs, recommandations et sélection finale', 'proof': 'présentation et validation', 'recurring': False},
    'CREATIVE': {'deliverables': 'concepts, fichiers sources et déclinaisons finales', 'proof': 'fichiers livrés aux formats convenus', 'recurring': False},
    'CONTENT': {'deliverables': 'contenus rédigés, relus et livrés aux formats convenus', 'proof': 'contenus validés', 'recurring': False},
    'CONTENT_STRATEGY': {'deliverables': 'ligne éditoriale, calendrier, formats et gouvernance', 'proof': 'plan éditorial validé', 'recurring': True},
    'CREATIVE_PRODUCTION': {'deliverables': 'production, fichiers maîtres et exports multi-formats', 'proof': 'fichiers et droits d’usage', 'recurring': False},
    'CAMPAIGN': {'deliverables': 'plan de campagne, paramétrage, créations, diffusion et reporting', 'proof': 'rapports plateforme et bilan', 'recurring': True},
    'EVENT': {'deliverables': 'concept, planning, coordination, exécution et bilan', 'proof': 'PV, photos et bilan', 'recurring': False},
    'PRODUCTION': {'deliverables': 'produits conformes, BAT et livraison/installation', 'proof': 'BAT et bon de livraison', 'recurring': False},
    'MANAGED_SERVICE': {'deliverables': 'service récurrent, SLA, rapports et support', 'proof': 'rapports périodiques et tickets', 'recurring': True},
    'OUTSOURCING': {'deliverables': 'opérations exécutées, contrôles et reporting périodique', 'proof': 'rapports et pièces de contrôle', 'recurring': True},
    'PROJECT': {'deliverables': 'livrables du projet, planning, contrôles et clôture', 'proof': 'livrables et PV', 'recurring': False},
    'AUDIT_SUPPORT': {'deliverables': 'dossier préparé, réponses et suivi des demandes', 'proof': 'liste PBC clôturée', 'recurring': False},
    'RECRUITMENT': {'deliverables': 'shortlist, évaluations, entretiens et accompagnement', 'proof': 'candidats présentés et décisions', 'recurring': False},
    'TRAINING': {'deliverables': 'supports, sessions, évaluations et attestations', 'proof': 'feuilles de présence et évaluations', 'recurring': False},
    'SURVEY': {'deliverables': 'questionnaire, collecte, analyse et plan d’action', 'proof': 'rapport agrégé et restitution', 'recurring': False},
    'INSURANCE_PLACEMENT': {'deliverables': 'analyse, consultation du marché, comparaison et proposition de couverture', 'proof': 'comparatif et documents de souscription', 'recurring': True},
    'RISK_AUDIT': {'deliverables': 'cartographie des risques, évaluation et plan de traitement', 'proof': 'rapport et matrice des risques', 'recurring': False},
    'RISK_ADVISORY': {'deliverables': 'plan de prévention, procédures et indicateurs', 'proof': 'plan validé et preuves de mise en œuvre', 'recurring': False},
    'CLAIMS_MANAGEMENT': {'deliverables': 'dossier sinistre, échanges, suivi et bilan d’indemnisation', 'proof': 'dossier complet et décision', 'recurring': True},
    'PROCUREMENT': {'deliverables': 'dossier de consultation, analyse des offres et recommandation', 'proof': 'comparatif et décision', 'recurring': False},
    'SOURCING': {'deliverables': 'longlist, shortlist, vérifications et recommandations', 'proof': 'fiches fournisseurs', 'recurring': False},
    'ENGINEERING': {'deliverables': 'études, plans, notes de calcul et estimations', 'proof': 'documents approuvés', 'recurring': False},
    'DESIGN_ENGINEERING': {'deliverables': 'esquisses, plans, rendus et dossier de conception', 'proof': 'plans validés', 'recurring': False},
    'PROJECT_MANAGEMENT': {'deliverables': 'planning, coordination, contrôle budget/qualité et reporting', 'proof': 'rapports et PV', 'recurring': True},
    'CONSTRUCTION': {'deliverables': 'travaux exécutés, essais, DOE et réception', 'proof': 'PV, photos et DOE', 'recurring': False},
    'ENERGY_PROJECT': {'deliverables': 'étude, équipements, installation, tests et mise en service', 'proof': 'mesures et PV de mise en service', 'recurring': False},
    'RESEARCH': {'deliverables': 'méthodologie, collecte, analyse et rapport', 'proof': 'rapport et base anonymisée', 'recurring': False},
}


COMMON_RFQ_QUESTIONS = [
    ('OBJECTIVE', 'Objectif', 'Quel est l’objectif principal attendu pour le service « {service} » ?', 'LONG_TEXT', True, 'Décrivez le résultat métier recherché et la raison de la demande.'),
    ('CURRENT_STATE', 'Situation actuelle', 'Quelle est votre situation actuelle concernant « {service} » ?', 'LONG_TEXT', True, 'Décrivez les outils, prestataires, pratiques ou solutions déjà en place.'),
    ('SCOPE', 'Périmètre', 'Quel est le périmètre quantitatif exact à prendre en charge ({unit}) ?', 'TABLE', True, 'Indiquez les volumes, sites, utilisateurs, unités ou lots concernés.'),
    ('LOCATIONS', 'Localisation', 'Quels sites, villes ou zones géographiques sont concernés par « {service} » ?', 'TABLE', True, 'Ajoutez chaque site et précisez si une intervention sur place est nécessaire.'),
    ('STAKEHOLDERS', 'Parties prenantes', 'Quels utilisateurs, équipes, décideurs ou tiers participeront au projet ?', 'TABLE', True, 'Indiquez les rôles, responsabilités et interlocuteurs de validation.'),
    ('DELIVERABLES', 'Livrables', 'Quels livrables attendez-vous précisément du prestataire ?', 'TABLE', True, 'Sélectionnez les livrables attendus et ajoutez les éléments spécifiques.'),
    ('DOCUMENTS', 'Documents disponibles', 'Quels documents, données, plans, contrats, accès ou contenus pouvez-vous fournir ?', 'FILE', False, 'Joignez les éléments disponibles et indiquez ceux qui seront fournis plus tard.'),
    ('DEPENDENCIES', 'Dépendances', 'Quelles dépendances, intégrations, autorisations ou contributions internes peuvent influencer la mission ?', 'LONG_TEXT', False, 'Mentionnez les autres projets, systèmes, fournisseurs ou validations nécessaires.'),
    ('COMPLIANCE', 'Contraintes', 'Quelles contraintes réglementaires, de confidentialité, de sécurité, de marque ou de fonctionnement doivent être respectées ?', 'LONG_TEXT', True, 'Indiquez les normes internes et obligations particulières.'),
    ('TIMELINE', 'Calendrier', 'Quelle est la date de démarrage souhaitée et quelles sont les échéances ou étapes impératives ?', 'TABLE', True, 'Ajoutez les jalons, dates de validation et date finale attendue.'),
    ('BUDGET', 'Budget', 'Quelle enveloppe budgétaire ou fourchette avez-vous prévue pour cette mission ?', 'MONEY', False, 'La réponse peut rester confidentielle et sert à proposer une solution adaptée.'),
    ('ACCEPTANCE', 'Réception', 'Selon quels critères objectifs considérerez-vous la prestation comme conforme et terminée ?', 'LONG_TEXT', True, 'Définissez les résultats, tests, formats et validations attendus.'),
    ('SUPPORT', 'Accompagnement', 'Avez-vous besoin de formation, transfert de compétences, support ou maintenance après livraison ?', 'MULTIPLE_CHOICE', False, 'Précisez la durée, les populations et le niveau de support.'),
    ('PAYMENT', 'Modalités', 'Quelles modalités de facturation, d’acompte ou de paiement souhaitez-vous proposer ?', 'SINGLE_CHOICE', False, 'Le prestataire pourra accepter ou proposer une variante dans son devis.'),
    ('SPECIAL', 'Contraintes particulières', 'Existe-t-il une contrainte, un risque ou une attente particulière non couverte par les questions précédentes ?', 'LONG_TEXT', False, 'Ajoutez toute information utile à un devis fiable.'),
]


FOCUS_QUESTION_TEMPLATES = [
    ('F1', 'Spécification métier', 'Décrivez précisément vos exigences concernant « {focus} » pour le service « {service} ».', 'LONG_TEXT', True),
    ('F2', 'État existant', 'Quel est l’état actuel de « {focus} » et quelles difficultés rencontrez-vous ?', 'LONG_TEXT', True),
    ('F3', 'Volumes', 'Quels volumes, fréquences, niveaux ou capacités sont attendus pour « {focus} » ?', 'TABLE', True),
    ('F4', 'Qualité attendue', 'Quels standards, niveaux de qualité ou indicateurs souhaitez-vous appliquer à « {focus} » ?', 'LONG_TEXT', False),
    ('F5', 'Limites', 'Quelles limites, exclusions ou contraintes doivent être prises en compte pour « {focus} » ?', 'LONG_TEXT', False),
]


TYPE_EXTRA_QUESTION_GROUPS = {
    'AUDIT': [
        ('X1', 'Méthode d’audit', 'Souhaitez-vous un audit documentaire, des entretiens, des tests sur site, des échantillonnages ou une combinaison de ces méthodes ?', 'MULTIPLE_CHOICE', True),
        ('X2', 'Référentiel', 'Quel référentiel, norme, politique interne ou niveau de maturité doit servir de base à l’évaluation ?', 'LONG_TEXT', False),
        ('X3', 'Échantillonnage', 'Quels sites, périodes, dossiers, actifs ou populations doivent obligatoirement être inclus dans l’échantillon ?', 'TABLE', True),
        ('X4', 'Restitution', 'Quel niveau de détail attendez-vous dans le rapport, la restitution et le plan d’action ?', 'SINGLE_CHOICE', True),
        ('X5', 'Indépendance', 'Existe-t-il des exigences d’indépendance, de confidentialité ou de qualification des auditeurs ?', 'LONG_TEXT', False),
    ],
    'IMPLEMENTATION': [
        ('X1', 'Environnement cible', 'Dans quel environnement la solution doit-elle être installée ou déployée ?', 'LONG_TEXT', True),
        ('X2', 'Compatibilité', 'Quelles contraintes de compatibilité avec l’existant doivent être respectées ?', 'LONG_TEXT', True),
        ('X3', 'Fenêtre d’intervention', 'Quelles fenêtres d’intervention, interruptions maximales ou périodes interdites faut-il respecter ?', 'TABLE', True),
        ('X4', 'Recette', 'Quels tests de recette, performances ou contrôles doivent être exécutés avant acceptation ?', 'TABLE', True),
        ('X5', 'Exploitation', 'Qui exploitera la solution après livraison et quels accès, manuels ou transferts sont nécessaires ?', 'LONG_TEXT', True),
    ],
    'SOFTWARE': [
        ('X1', 'Utilisateurs et rôles', 'Listez les profils utilisateurs, leurs droits et les actions principales de chacun.', 'TABLE', True),
        ('X2', 'Fonctionnalités prioritaires', 'Classez les fonctionnalités en indispensable, importante et souhaitable.', 'TABLE', True),
        ('X3', 'Intégrations', 'Quelles API, bases, logiciels, moyens de paiement ou services tiers doivent être intégrés ?', 'TABLE', True),
        ('X4', 'Données', 'Quelles données doivent être créées, importées, migrées, conservées ou supprimées ?', 'TABLE', True),
        ('X5', 'Exigences non fonctionnelles', 'Précisez les exigences de performance, disponibilité, sécurité, traçabilité, appareils et navigateurs.', 'LONG_TEXT', True),
    ],
    'CREATIVE': [
        ('X1', 'Audience', 'Décrivez les audiences, personas et réactions recherchées.', 'LONG_TEXT', True),
        ('X2', 'Références créatives', 'Fournissez des références appréciées et refusées, avec les raisons.', 'FILE', False),
        ('X3', 'Identité existante', 'Quels éléments de marque, chartes, logos, contenus ou gabarits doivent être respectés ?', 'FILE', True),
        ('X4', 'Formats de livraison', 'Listez les formats, dimensions, résolutions, variantes et fichiers sources requis.', 'TABLE', True),
        ('X5', 'Droits d’usage', 'Précisez les territoires, durées, médias et droits d’utilisation ou de modification nécessaires.', 'LONG_TEXT', True),
    ],
    'MANAGED': [
        ('X1', 'SLA', 'Quels horaires de service, délais de réponse, délais de résolution et niveaux de priorité sont attendus ?', 'TABLE', True),
        ('X2', 'Volumétrie récurrente', 'Indiquez les volumes mensuels, saisonnalités, pics et croissance prévisible.', 'TABLE', True),
        ('X3', 'Gouvernance', 'Quelle fréquence de comité, reporting et revue de performance souhaitez-vous ?', 'TABLE', True),
        ('X4', 'Escalade', 'Définissez les contacts, niveaux d’escalade et situations nécessitant une alerte immédiate.', 'TABLE', True),
        ('X5', 'Réversibilité', 'Quelles obligations de restitution des données, documents, accès et connaissances sont attendues en fin de contrat ?', 'LONG_TEXT', True),
    ],
    'LEGAL': [
        ('X1', 'Cadre juridique', 'Quels pays, juridictions, autorités ou règles internes sont concernés ?', 'LONG_TEXT', True),
        ('X2', 'Parties', 'Identifiez toutes les parties, bénéficiaires, représentants et relations juridiques concernées.', 'TABLE', True),
        ('X3', 'Historique', 'Décrivez la chronologie, les engagements antérieurs et les documents déjà signés ou échangés.', 'LONG_TEXT', True),
        ('X4', 'Niveau de risque', 'Quels risques, montants, responsabilités ou conséquences souhaitez-vous prioritairement limiter ?', 'LONG_TEXT', True),
        ('X5', 'Validation', 'Qui doit réviser, négocier, approuver et signer le livrable juridique ?', 'TABLE', True),
    ],
    'FINANCE': [
        ('X1', 'Périodes', 'Quelles périodes, entités, devises et référentiels doivent être couverts ?', 'TABLE', True),
        ('X2', 'Volumétrie financière', 'Indiquez les volumes de transactions, factures, comptes, déclarations ou lignes à traiter.', 'TABLE', True),
        ('X3', 'Systèmes sources', 'Quels logiciels, fichiers, banques ou systèmes contiennent les données nécessaires ?', 'TABLE', True),
        ('X4', 'Contrôles', 'Quels contrôles, rapprochements, validations ou pistes d’audit sont obligatoires ?', 'LONG_TEXT', True),
        ('X5', 'Restitution', 'Quels états, analyses, annexes, formats et fréquences de reporting sont attendus ?', 'TABLE', True),
    ],
    'HR': [
        ('X1', 'Population', 'Quelles populations, postes, niveaux, contrats ou établissements sont concernés ?', 'TABLE', True),
        ('X2', 'Politique existante', 'Quelles politiques, pratiques, outils ou accords existent déjà ?', 'LONG_TEXT', True),
        ('X3', 'Données RH', 'Quelles données individuelles ou agrégées seront disponibles et quelles restrictions de confidentialité s’appliquent ?', 'LONG_TEXT', True),
        ('X4', 'Adoption', 'Quels managers, représentants, salariés ou instances doivent être consultés et accompagnés ?', 'TABLE', True),
        ('X5', 'Mesure', 'Quels indicateurs permettront d’évaluer l’efficacité de la prestation RH ?', 'LONG_TEXT', True),
    ],
    'INSURANCE': [
        ('X1', 'Expositions', 'Décrivez les activités, valeurs, personnes, territoires et événements exposés au risque.', 'TABLE', True),
        ('X2', 'Historique sinistres', 'Fournissez l’historique des sinistres, réclamations et mesures correctives disponibles.', 'TABLE', True),
        ('X3', 'Couvertures actuelles', 'Joignez les polices, garanties, plafonds, franchises et exclusions actuellement en vigueur.', 'FILE', True),
        ('X4', 'Couverture cible', 'Quels capitaux, limites, franchises, extensions et niveaux de service recherchez-vous ?', 'TABLE', True),
        ('X5', 'Échéances', 'Quelles dates de renouvellement, obligations contractuelles ou urgences doivent être respectées ?', 'TABLE', True),
    ],
    'PROCUREMENT': [
        ('X1', 'Spécifications', 'Quelles spécifications techniques, fonctionnelles, qualité et conformité doivent être respectées ?', 'LONG_TEXT', True),
        ('X2', 'Volumes et paliers', 'Quels volumes minimum, prévisionnels, maximum et paliers tarifaires sont envisagés ?', 'TABLE', True),
        ('X3', 'Marché fournisseur', 'Quels fournisseurs, pays, marques ou technologies sont imposés, préférés ou exclus ?', 'TABLE', False),
        ('X4', 'Critères de sélection', 'Comment pondérer prix, qualité, délai, capacité, risque, durabilité et service ?', 'TABLE', True),
        ('X5', 'Contrat et logistique', 'Quelles conditions de livraison, paiement, garantie, pénalité et réversibilité sont attendues ?', 'LONG_TEXT', True),
    ],
    'CONSTRUCTION': [
        ('X1', 'État du site', 'Décrivez l’état actuel du terrain, bâtiment, réseaux et accès au chantier.', 'LONG_TEXT', True),
        ('X2', 'Plans et métrés', 'Quels plans, relevés, métrés, études et diagnostics sont disponibles ?', 'FILE', True),
        ('X3', 'Matériaux et finitions', 'Précisez les matériaux, marques, gammes, niveaux de finition et équivalences autorisées.', 'TABLE', True),
        ('X4', 'Phasage chantier', 'Quelles phases, contraintes d’occupation, horaires, coactivités et mesures de sécurité s’appliquent ?', 'TABLE', True),
        ('X5', 'Réception et garanties', 'Quels essais, DOE, garanties, réserves et délais de levée sont exigés ?', 'LONG_TEXT', True),
    ],
    'TRAINING': [
        ('X1', 'Population apprenante', 'Indiquez le nombre de participants, leurs profils, niveaux et prérequis.', 'TABLE', True),
        ('X2', 'Objectifs pédagogiques', 'Quelles compétences observables doivent être acquises à l’issue de la formation ?', 'LONG_TEXT', True),
        ('X3', 'Modalités', 'Quel format, rythme, lieu, langue, durée et calendrier souhaitez-vous ?', 'TABLE', True),
        ('X4', 'Évaluation', 'Quels tests, mises en situation, attestations ou indicateurs d’impact sont attendus ?', 'TABLE', True),
        ('X5', 'Personnalisation', 'Quels cas internes, outils, documents ou scénarios doivent être intégrés aux supports ?', 'LONG_TEXT', False),
    ],
    'RESEARCH': [
        ('X1', 'Population étudiée', 'Définissez les populations, segments, zones et critères d’inclusion de l’étude.', 'TABLE', True),
        ('X2', 'Méthodologie', 'Quelles méthodes qualitatives, quantitatives, documentaires ou terrain sont souhaitées ?', 'MULTIPLE_CHOICE', True),
        ('X3', 'Échantillon', 'Quel niveau de précision, taille d’échantillon et représentativité sont nécessaires ?', 'TABLE', True),
        ('X4', 'Données sources', 'Quelles données internes, bases externes ou accès terrain sont disponibles ?', 'FILE', False),
        ('X5', 'Décisions attendues', 'Quelles décisions concrètes le rapport doit-il permettre de prendre ?', 'LONG_TEXT', True),
    ],
}

TYPE_TO_EXTRA_GROUP = {
    'AUDIT': 'AUDIT', 'RISK_AUDIT': 'AUDIT',
    'IMPLEMENTATION': 'IMPLEMENTATION', 'ENERGY_PROJECT': 'IMPLEMENTATION',
    'SOFTWARE_PROJECT': 'SOFTWARE', 'AI_PROJECT': 'SOFTWARE', 'DATA_PROJECT': 'SOFTWARE', 'CREATIVE_TECH': 'SOFTWARE',
    'CREATIVE': 'CREATIVE', 'CREATIVE_STRATEGY': 'CREATIVE', 'CREATIVE_PRODUCTION': 'CREATIVE', 'CONTENT': 'CREATIVE', 'CONTENT_STRATEGY': 'CREATIVE', 'CAMPAIGN': 'CREATIVE', 'EVENT': 'CREATIVE', 'PRODUCTION': 'CREATIVE',
    'MANAGED_SERVICE': 'MANAGED', 'OUTSOURCING': 'MANAGED', 'CLAIMS_MANAGEMENT': 'MANAGED',
    'LEGAL_ADVISORY': 'LEGAL', 'LEGAL_SERVICE': 'LEGAL', 'COMPLIANCE': 'LEGAL',
    'PROJECT': 'IMPLEMENTATION', 'COMPLIANCE_PROJECT': 'IMPLEMENTATION', 'AUDIT_SUPPORT': 'AUDIT',
    'ADVISORY': 'AUDIT', 'RISK_ADVISORY': 'AUDIT',
    'RECRUITMENT': 'HR', 'SURVEY': 'HR',
    'TRAINING': 'TRAINING',
    'INSURANCE_PLACEMENT': 'INSURANCE',
    'PROCUREMENT': 'PROCUREMENT', 'SOURCING': 'PROCUREMENT',
    'ENGINEERING': 'CONSTRUCTION', 'DESIGN_ENGINEERING': 'CONSTRUCTION', 'PROJECT_MANAGEMENT': 'CONSTRUCTION', 'CONSTRUCTION': 'CONSTRUCTION',
    'RESEARCH': 'RESEARCH',
}


COMMON_RFQ_OPTIONS = {
    'SUPPORT': ['FORMATION', 'TRANSFERT_COMPETENCES', 'SUPPORT', 'MAINTENANCE', 'ACCOMPAGNEMENT', 'AUCUN'],
    'PAYMENT': ['ACOMPTE_SOLDE', 'PAR_JALONS', 'MENSUEL', 'A_LA_LIVRAISON', 'A_NEGOCIER'],
}

TYPE_EXTRA_OPTIONS = {
    ('AUDIT', 'X1'): ['REVUE_DOCUMENTAIRE', 'ENTRETIENS', 'SUR_SITE', 'TESTS', 'ECHANTILLONNAGE'],
    ('RESEARCH', 'X2'): ['ENTRETIENS', 'QUESTIONNAIRE', 'ETUDE_DOCUMENTAIRE', 'OBSERVATION', 'ANALYSE_DONNEES'],
}


LIBRARY_DIAGNOSTIC_COMMON = [
    ('MATURITY', 'Quel est le niveau de formalisation actuel de vos pratiques dans la bibliothèque « {library} » ?', 'SINGLE_CHOICE', ['INEXISTANT', 'INFORMEL', 'PARTIEL', 'FORMALISE', 'MESURE_ET_AMELIORE']),
    ('OWNER', 'Un responsable clairement identifié pilote-t-il ce domaine ?', 'YES_NO', ['YES', 'NO', 'UNKNOWN']),
    ('BUDGET', 'Un budget annuel est-il défini et suivi pour ce domaine ?', 'YES_NO', ['YES', 'NO', 'PARTIAL']),
    ('KPI', 'Disposez-vous d’indicateurs réguliers pour mesurer la performance de ce domaine ?', 'YES_NO', ['YES', 'NO', 'PARTIAL']),
    ('RISKS', 'Les risques majeurs de ce domaine sont-ils identifiés, évalués et suivis ?', 'YES_NO', ['YES', 'NO', 'PARTIAL']),
    ('DOCUMENTATION', 'Les politiques, procédures et responsabilités sont-elles documentées et à jour ?', 'YES_NO', ['YES', 'NO', 'PARTIAL']),
    ('TOOLS', 'Les outils utilisés répondent-ils aux besoins et communiquent-ils correctement entre eux ?', 'SINGLE_CHOICE', ['YES', 'PARTIAL', 'NO', 'UNKNOWN']),
    ('SKILLS', 'Les équipes disposent-elles des compétences et ressources nécessaires ?', 'SINGLE_CHOICE', ['YES', 'PARTIAL', 'NO', 'UNKNOWN']),
    ('INCIDENTS', 'Avez-vous connu des incidents, retards, pertes ou réclamations significatifs dans ce domaine au cours des 12 derniers mois ?', 'YES_NO', ['YES', 'NO']),
    ('PRIORITY', 'Souhaitez-vous faire de ce domaine une priorité d’amélioration dans les 12 prochains mois ?', 'SINGLE_CHOICE', ['HIGH', 'MEDIUM', 'LOW', 'NO']),
]


PROVIDER_COMMON = [
    ('LEGAL', 'Votre entreprise est-elle administrativement active et autorisée à fournir les prestations de cette bibliothèque ?', 'YES_NO'),
    ('INSURANCE', 'Disposez-vous d’une assurance responsabilité professionnelle adaptée aux services proposés ?', 'YES_NO'),
    ('TEAM', 'Décrivez la taille, les rôles et l’expérience de l’équipe affectable à cette bibliothèque.', 'TABLE'),
    ('REFERENCES', 'Fournissez au moins trois références comparables réalisées récemment.', 'TABLE'),
    ('CAPACITY', 'Quelle capacité mensuelle pouvez-vous garantir sans dégrader la qualité ?', 'QUANTITY'),
    ('REGIONS', 'Dans quelles régions pouvez-vous intervenir sur site et à distance ?', 'MULTIPLE_CHOICE'),
    ('SLA', 'Quels délais de réponse, démarrage, correction et support pouvez-vous garantir ?', 'TABLE'),
    ('QUALITY', 'Quel processus de contrôle qualité appliquez-vous avant livraison ?', 'LONG_TEXT'),
    ('SUBCONTRACTING', 'Recourez-vous à de la sous-traitance secondaire et, si oui, comment la contrôlez-vous ?', 'LONG_TEXT'),
    ('SECURITY', 'Comment protégez-vous les informations, documents et accès confiés par les clients ?', 'LONG_TEXT'),
]


def library_rows() -> list[dict[str, Any]]:
    rows = []
    for i, lib in enumerate(LIBRARIES, 1):
        rows.append({
            'code': lib['code'],
            'name_fr': lib['name_fr'],
            'description_fr': lib['description_fr'],
            'order': i,
            'status': 'ACTIVE',
            'version': 1,
            'franchisee_can_edit': True,
            'central_approval_for_sensitive_changes': True,
        })
    return rows


def category_rows() -> list[dict[str, Any]]:
    rows = []
    for lib in LIBRARIES:
        for i, (code, name, subcodes) in enumerate(MACRO_CATEGORY_MAP[lib['code']], 1):
            rows.append({
                'library_code': lib['code'],
                'code': code,
                'name_fr': name,
                'description_fr': f"Grande catégorie {name} de la bibliothèque {lib['name_fr']}.",
                'order': i,
                'status': 'ACTIVE',
                'version': 1,
                'franchisee_can_edit': True,
                'subcategories_json': json.dumps(subcodes, ensure_ascii=False),
            })
    return rows


def subcategory_rows() -> list[dict[str, Any]]:
    rows = []
    for lib in LIBRARIES:
        for i, (code, name) in enumerate(lib['categories'], 1):
            rows.append({
                'library_code': lib['code'],
                'macro_category_code': SUBCATEGORY_TO_MACRO[code],
                'code': code,
                'name_fr': name,
                'description_fr': f"Sous-catégorie {name} de la bibliothèque {lib['name_fr']}.",
                'order': i,
                'status': 'ACTIVE',
                'version': 1,
                'franchisee_can_edit': True,
                'delete_policy': 'ARCHIVE_IF_REFERENCED',
            })
    return rows


def service_rows() -> list[dict[str, Any]]:
    rows = []
    for lib in LIBRARIES:
        for i, (cat, code, name, stype, unit, focus) in enumerate(lib['services'], 1):
            profile = TYPE_PROFILES.get(stype, {'deliverables': 'livrables convenus, documentation et validation', 'proof': 'preuves de réalisation et réception', 'recurring': False})
            svc = Service(
                library_code=lib['code'],
                category_code=cat,
                code=code,
                name_fr=name,
                service_type=stype,
                unit_label_fr=unit,
                focus_terms=focus,
                volume_eligible=stype in {'CREATIVE', 'CONTENT', 'CREATIVE_PRODUCTION', 'PRODUCTION', 'MANAGED_SERVICE', 'OUTSOURCING', 'TRAINING', 'RECRUITMENT', 'IMPLEMENTATION'},
                recurring_eligible=bool(profile.get('recurring')),
                credit_eligible=stype not in {'LEGAL_ADVISORY', 'LEGAL_SERVICE', 'INSURANCE_PLACEMENT'},
                order=i,
            )
            d = asdict(svc)
            d['macro_category_code'] = SUBCATEGORY_TO_MACRO[cat]
            d['subcategory_code'] = cat
            d['secondary_subcategory_codes_json'] = json.dumps(SECONDARY_SERVICE_SUBCATEGORIES.get(code, []), ensure_ascii=False)
            d.update({
                'description_fr': f"Prestation structurée de {name.lower()} comprenant cadrage, exécution, contrôle, documentation et réception.",
                'standard_deliverables_fr': profile['deliverables'],
                'standard_proof_fr': profile['proof'],
                'status': 'ACTIVE',
                'version': 1,
                'franchisee_can_create': True,
                'franchisee_can_edit': True,
                'franchisee_delete_policy': 'ARCHIVE_IF_REFERENCED',
                'central_approval_flags': json.dumps(['FINANCIAL_RULES', 'CONTRACT_CLAUSES', 'LEGAL_TEXT', 'PENALTIES', 'SCORING_BLOCKERS'], ensure_ascii=False),
            })
            d['focus_terms'] = json.dumps(d['focus_terms'], ensure_ascii=False)
            rows.append(d)
    return rows



def service_subcategory_link_rows(services: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for svc in services:
        rows.append({
            'service_code': svc['code'],
            'library_code': svc['library_code'],
            'subcategory_code': svc['subcategory_code'],
            'link_type': 'PRIMARY',
            'status': 'ACTIVE',
        })
        for sub in json.loads(svc['secondary_subcategory_codes_json']):
            rows.append({
                'service_code': svc['code'],
                'library_code': svc['library_code'],
                'subcategory_code': sub,
                'link_type': 'SECONDARY',
                'status': 'ACTIVE',
            })
    return rows


def qrow(**kwargs: Any) -> dict[str, Any]:
    base = {
        'question_id': kwargs.pop('question_id'),
        'template_key': kwargs.pop('template_key', ''),
        'library_code': kwargs.pop('library_code'),
        'category_code': kwargs.pop('category_code', ''),
        'service_code': kwargs.pop('service_code', ''),
        'phase': kwargs.pop('phase'),
        'section': kwargs.pop('section'),
        'order': kwargs.pop('order'),
        'label_fr': kwargs.pop('label_fr'),
        'help_fr': kwargs.pop('help_fr', ''),
        'answer_type': kwargs.pop('answer_type'),
        'required': kwargs.pop('required', False),
        'required_for_quote': kwargs.pop('required_for_quote', False),
        'options_json': json.dumps(kwargs.pop('options', []), ensure_ascii=False),
        'validation_json': json.dumps(kwargs.pop('validation', {}), ensure_ascii=False),
        'condition_json': json.dumps(kwargs.pop('condition', {}), ensure_ascii=False),
        'data_key': kwargs.pop('data_key'),
        'weight': kwargs.pop('weight', 1),
        'max_score': kwargs.pop('max_score', 10),
        'anomaly_code': kwargs.pop('anomaly_code', ''),
        'risk_code': kwargs.pop('risk_code', ''),
        'recommendation_code': kwargs.pop('recommendation_code', ''),
        'opportunity_service_code': kwargs.pop('opportunity_service_code', ''),
        'sensitivity': kwargs.pop('sensitivity', 'BUSINESS'),
        'modifiable_by_franchisee': True,
        'deletion_policy': 'ARCHIVE_IF_REFERENCED',
        'requires_central_approval': kwargs.pop('requires_central_approval', False),
        'status': 'ACTIVE',
        'version': 1,
        'origin': 'MATRICIA_GOLD_MASTER_BASELINE',
    }
    base.update(kwargs)
    return base


def generate_rfq_questions() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lib in LIBRARIES:
        for cat, scode, sname, stype, unit, focus_terms in lib['services']:
            # 15 universal questions + five service-specific focus questions + five type-specific questions = 25 per service.
            selected_common = COMMON_RFQ_QUESTIONS
            order = 1
            for suffix, section, label, atype, req, help_text in selected_common:
                rows.append(qrow(
                    question_id=f"Q-RFQ-{scode}-{suffix}", template_key=f"RFQ_COMMON_{suffix}", library_code=lib['code'], category_code=cat,
                    service_code=scode, phase='RFQ', section=section, order=order,
                    label_fr=label.format(service=sname, unit=unit), help_fr=help_text,
                    answer_type=atype, required=req, required_for_quote=req,
                    data_key=f"rfq.{slug(scode)}.{suffix.lower()}",
                    options=COMMON_RFQ_OPTIONS.get(suffix, []),
                    validation={'min_length': 10} if atype == 'LONG_TEXT' and req else {},
                ))
                order += 1
            for idx, focus in enumerate(focus_terms[:5]):
                suffix, section, label, atype, req = FOCUS_QUESTION_TEMPLATES[idx]
                rows.append(qrow(
                    question_id=f"Q-RFQ-{scode}-{suffix}", template_key=f"RFQ_FOCUS_{idx+1}", library_code=lib['code'], category_code=cat,
                    service_code=scode, phase='RFQ', section=section, order=order,
                    label_fr=label.format(focus=focus, service=sname),
                    help_fr=f"Cette réponse permet aux sous-traitants de chiffrer correctement la composante « {focus} ».",
                    answer_type=atype, required=req, required_for_quote=req,
                    data_key=f"rfq.{slug(scode)}.focus_{idx+1}",
                    validation={'min_length': 5} if atype == 'LONG_TEXT' and req else {},
                ))
                order += 1
            group = TYPE_TO_EXTRA_GROUP.get(stype, 'AUDIT')
            for suffix, section, label, atype, req in TYPE_EXTRA_QUESTION_GROUPS[group]:
                rows.append(qrow(
                    question_id=f"Q-RFQ-{scode}-{suffix}", template_key=f"RFQ_TYPE_{group}_{suffix}", library_code=lib['code'], category_code=cat,
                    service_code=scode, phase='RFQ', section=section, order=order,
                    label_fr=label,
                    help_fr=f"Question spécialisée pour cadrer et chiffrer correctement le service « {sname} ».",
                    answer_type=atype, required=req, required_for_quote=req,
                    data_key=f"rfq.{slug(scode)}.{suffix.lower()}",
                    options=TYPE_EXTRA_OPTIONS.get((group, suffix), []),
                    validation={'min_length': 5} if atype == 'LONG_TEXT' and req else {},
                ))
                order += 1
    return rows


def generate_diagnostic_questions() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lib in LIBRARIES:
        # 10 library-level questions.
        for i, (suffix, label, atype, options) in enumerate(LIBRARY_DIAGNOSTIC_COMMON, 1):
            anomaly = f"ANOM-{lib['code']}-BASE-{suffix}"
            risk = f"RISK-{lib['code']}-BASE-{suffix}"
            rec = f"REC-{lib['code']}-BASE-{suffix}"
            rows.append(qrow(
                question_id=f"Q-DIAG-{lib['code']}-BASE-{i:02d}", template_key=f"DIAG_COMMON_{suffix}", library_code=lib['code'], phase='DIAGNOSTIC',
                section='Diagnostic général', order=i, label_fr=label.format(library=lib['name_fr']),
                help_fr='Répondez selon la situation réelle de votre entreprise.', answer_type=atype,
                required=True, data_key=f"diagnostic.{lib['code'].lower()}.base_{suffix.lower()}", options=options,
                weight=2 if suffix in {'RISKS','INCIDENTS','MATURITY'} else 1, anomaly_code=anomaly, risk_code=risk,
                recommendation_code=rec, requires_central_approval=suffix in {'RISKS'},
            ))
        # 3 questions per service = 60, giving exactly 70 per library.
        order = 11
        for cat, scode, sname, stype, unit, focus_terms in lib['services']:
            diag_defs = [
                ('EXISTS', f"Disposez-vous actuellement d’un dispositif ou processus formalisé pour « {sname} » ?", 'SINGLE_CHOICE', ['YES','PARTIAL','NO','UNKNOWN']),
                ('PERFORMANCE', f"Comment évaluez-vous la performance actuelle de « {sname} » ?", 'RATING_5', []),
                ('ISSUES', f"Quels problèmes, retards, incidents ou insatisfactions rencontrez-vous concernant « {sname} » ?", 'LONG_TEXT', []),
            ]
            for suffix, label, atype, options in diag_defs:
                anomaly = f"ANOM-{scode}-{suffix}"
                risk = f"RISK-{scode}-{suffix}"
                rec = f"REC-{scode}-{suffix}"
                rows.append(qrow(
                    question_id=f"Q-DIAG-{scode}-{suffix}", template_key=f"DIAG_SERVICE_{suffix}", library_code=lib['code'], category_code=cat,
                    service_code=scode, phase='DIAGNOSTIC', section='Diagnostic par service', order=order,
                    label_fr=label, help_fr=f"La réponse peut générer une recommandation liée au service « {sname} ».",
                    answer_type=atype, required=(suffix != 'ISSUES'), data_key=f"diagnostic.{slug(scode)}.{suffix.lower()}",
                    options=options, weight=2 if suffix in {'EXISTS','PERFORMANCE'} else 1,
                    anomaly_code=anomaly, risk_code=risk, recommendation_code=rec,
                    opportunity_service_code=scode,
                ))
                order += 1
    return rows


def generate_provider_questions() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lib in LIBRARIES:
        # 10 common questions.
        order = 1
        for suffix, label, atype in PROVIDER_COMMON:
            rows.append(qrow(
                question_id=f"Q-PROV-{lib['code']}-BASE-{suffix}", template_key=f"PROV_COMMON_{suffix}", library_code=lib['code'], phase='PROVIDER_QUALIFICATION',
                section='Qualification générale', order=order, label_fr=label,
                help_fr=f"Cette information est utilisée pour qualifier le sous-traitant dans la bibliothèque « {lib['name_fr']} ».",
                answer_type=atype, required=True, data_key=f"provider.{lib['code'].lower()}.base_{suffix.lower()}",
                required_for_quote=False, requires_central_approval=suffix in {'LEGAL','INSURANCE','SECURITY'},
            ))
            order += 1
        # One service-specific experience question per service = 20, total 30/library.
        for cat, scode, sname, stype, unit, focus_terms in lib['services']:
            rows.append(qrow(
                question_id=f"Q-PROV-{scode}-EXPERIENCE", template_key="PROV_SERVICE_EXPERIENCE", library_code=lib['code'], category_code=cat,
                service_code=scode, phase='PROVIDER_QUALIFICATION', section='Qualification par service', order=order,
                label_fr=f"Présentez votre expérience, vos références, votre équipe et votre capacité pour le service « {sname} ».",
                help_fr=f"Joignez des preuves et indiquez le volume maximal que vous pouvez réaliser en {unit}.",
                answer_type='TABLE', required=True, data_key=f"provider.{slug(scode)}.experience_capacity",
            ))
            order += 1
    return rows


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    fields: list[str] = []
    seen = set()
    for row in rows:
        for k in row:
            if k not in seen:
                seen.add(k)
                fields.append(k)
    with path.open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)


def write_jsonl(path: Path, rows: Iterable[dict[str, Any]]) -> None:
    with path.open('w', encoding='utf-8') as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + '\n')


def validate(libs, cats, svcs, rfq, diag, prov) -> list[str]:
    errors: list[str] = []
    if len(libs) != 10:
        errors.append(f'Expected 10 libraries, got {len(libs)}')
    if len(svcs) != 200:
        errors.append(f'Expected 200 services, got {len(svcs)}')
    if len(rfq) != 5000:
        errors.append(f'Expected 5000 RFQ questions, got {len(rfq)}')
    if len(diag) != 700:
        errors.append(f'Expected 700 diagnostic questions, got {len(diag)}')
    if len(prov) != 300:
        errors.append(f'Expected 300 provider questions, got {len(prov)}')
    all_ids = [r['question_id'] for r in [*rfq, *diag, *prov]]
    dups = [k for k, c in Counter(all_ids).items() if c > 1]
    if dups:
        errors.append(f'Duplicate question IDs: {dups[:10]}')
    svc_codes = {s['code'] for s in svcs}
    for row in [*rfq, *diag, *prov]:
        if row['service_code'] and row['service_code'] not in svc_codes:
            errors.append(f"Question {row['question_id']} points to unknown service {row['service_code']}")
    if any('TO_DEFINE' in json.dumps(r, ensure_ascii=False) for r in [*rfq, *diag, *prov]):
        errors.append('TO_DEFINE placeholder detected')
    return errors


def build_readme(counts: dict[str, int]) -> str:
    return f"""# Catalogue métier Matricia V1 — base Gold Master

Ce dossier remplace l'exigence vague « créer au moins 900 questions » par une base déterministe et importable.

## Contenu validé

- Bibliothèques : **{counts['libraries']}**
- Grandes catégories : **{counts['categories']}**
- Sous-catégories : **{counts['subcategories']}**
- Services actifs : **{counts['services']}**
- Questions de cadrage RFQ/devis : **{counts['rfq_questions']}**
- Questions de diagnostic : **{counts['diagnostic_questions']}**
- Questions de qualification sous-traitant : **{counts['provider_questions']}**
- Total questions : **{counts['total_questions']}**

Chaque service contient exactement 25 questions de cadrage pour rendre une demande chiffrable. Chaque bibliothèque contient 70 questions de diagnostic et 30 questions de qualification fournisseur.

## Gouvernance franchisé

Le franchisé peut :

- créer, dupliquer, modifier, réordonner, désactiver ou archiver une question ;
- créer, modifier, déplacer, désactiver ou archiver un service ;
- ajouter ou retirer des catégories ;
- importer/exporter CSV/JSON ;
- prévisualiser et simuler un questionnaire ;
- publier une nouvelle version selon ses permissions.

Une question ou un service déjà utilisé n'est jamais supprimé physiquement : il est archivé et sa version historique reste attachée aux diagnostics, demandes, devis et contrats existants. Les changements financiers, juridiques, bloquants ou contractuels exigent une approbation centrale Matricia.

## Fichiers

- `libraries.csv`
- `categories.csv`
- `subcategories.csv`
- `services.csv`
- `service_subcategory_links.csv`
- `questions_rfq.csv`
- `questions_diagnostic.csv`
- `questions_provider_qualification.csv`
- `questions_all.jsonl`
- `catalog_manifest.json`
- `optional_library_operations.json` (bibliothèque supplémentaire proposée mais non activée dans les dix de base)

## Important

Cette base est très étendue, mais aucun catalogue fini ne peut anticiper toutes les variantes futures de chaque métier. Le moteur CRUD/versionné est donc obligatoire. Avant production, les contenus juridiques, fiscaux, assurance, HSE et réglementaires doivent être revus par les experts du domaine concerné.
"""


def main() -> None:
    libs = library_rows()
    cats = category_rows()
    subcats = subcategory_rows()
    svcs = service_rows()
    svc_links = service_subcategory_link_rows(svcs)
    rfq = generate_rfq_questions()
    diag = generate_diagnostic_questions()
    prov = generate_provider_questions()
    errors = validate(libs, cats, svcs, rfq, diag, prov)
    if len(subcats) != 80:
        errors.append(f'Expected 80 subcategories, got {len(subcats)}')
    if errors:
        raise SystemExit('\n'.join(errors))

    write_csv(OUT / 'libraries.csv', libs)
    write_csv(OUT / 'categories.csv', cats)
    write_csv(OUT / 'subcategories.csv', subcats)
    write_csv(OUT / 'services.csv', svcs)
    write_csv(OUT / 'service_subcategory_links.csv', svc_links)
    write_csv(OUT / 'questions_rfq.csv', rfq)
    write_csv(OUT / 'questions_diagnostic.csv', diag)
    write_csv(OUT / 'questions_provider_qualification.csv', prov)
    write_jsonl(OUT / 'questions_all.jsonl', [*rfq, *diag, *prov])
    (OUT / 'optional_library_operations.json').write_text(json.dumps(OPTIONAL_LIBRARY, ensure_ascii=False, indent=2), encoding='utf-8')

    counts = {
        'libraries': len(libs),
        'categories': len(cats),
        'subcategories': len(subcats),
        'services': len(svcs),
        'service_subcategory_links': len(svc_links),
        'rfq_questions': len(rfq),
        'diagnostic_questions': len(diag),
        'provider_questions': len(prov),
        'total_questions': len(rfq) + len(diag) + len(prov),
    }
    by_library: dict[str, dict[str, int]] = {}
    for lib in libs:
        code = lib['code']
        by_library[code] = {
            'categories': sum(1 for x in cats if x['library_code'] == code),
            'subcategories': sum(1 for x in subcats if x['library_code'] == code),
            'services': sum(1 for x in svcs if x['library_code'] == code),
            'rfq_questions': sum(1 for x in rfq if x['library_code'] == code),
            'diagnostic_questions': sum(1 for x in diag if x['library_code'] == code),
            'provider_questions': sum(1 for x in prov if x['library_code'] == code),
        }
    manifest = {
        'catalog_version': '1.0.0',
        'generated_by': 'Matricia Gold Master baseline generator',
        'counts': counts,
        'by_library': by_library,
        'rules': {
            'franchisee_service_crud': True,
            'franchisee_question_crud': True,
            'delete_semantics': 'SOFT_DELETE_ARCHIVE_IF_REFERENCED',
            'versioning_required': True,
            'central_approval_for_sensitive_changes': True,
            'arabic_translation_required_before_production': True,
        },
    }
    (OUT / 'catalog_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    (OUT / 'README.md').write_text(build_readme(counts), encoding='utf-8')
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
