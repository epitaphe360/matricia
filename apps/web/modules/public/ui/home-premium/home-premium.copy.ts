export type HomeLocale = "fr" | "ar";

export type HomePremiumCopy = {
  eyebrow: string;
  titleLead: string;
  titleAccent: string;
  intro: string;
  primaryAction: string;
  providerAction: string;
  preciseNeedAction: string;
  previewLabel: string;
  previewStages: readonly string[];
  projectLabel: string;
  projectTitle: string;
  projectStatus: string;
  offersLabel: string;
  offersValue: string;
  decisionLabel: string;
  decisionValue: string;
  cycleEyebrow: string;
  cycleTitle: string;
  cycleIntro: string;
  cycle: readonly { label: string; description: string }[];
  outcomesEyebrow: string;
  outcomesTitle: string;
  outcomesIntro: string;
  outcomes: readonly { title: string; description: string }[];
  professionalsEyebrow: string;
  professionalsTitle: string;
  professionalsIntro: string;
  qualificationBadge: string;
  professionals: readonly string[];
  professionalsAction: string;
  faqEyebrow: string;
  faqTitle: string;
  faq: readonly { question: string; answer: string }[];
  finalEyebrow: string;
  finalTitle: string;
  finalIntro: string;
  finalPrimary: string;
  finalSecondary: string;
};

const fr: HomePremiumCopy = {
  eyebrow: "Comprendre. Décider. Agir.",
  titleLead: "Découvrez ce qui freine votre entreprise.",
  titleAccent: "Passez aux bonnes solutions.",
  intro:
    "Répondez à quelques questions. Matricia vous aide à comprendre vos priorités, comparer les bonnes propositions et piloter vos prestations.",
  primaryAction: "Analyser mon entreprise",
  providerAction: "Proposer mes services",
  preciseNeedAction: "J’ai déjà un besoin précis",
  previewLabel: "Un parcours clair, de votre besoin à sa réalisation",
  previewStages: ["Besoin", "Offres", "Choix", "Mission"],
  projectLabel: "Votre situation",
  projectTitle: "Organisation et croissance",
  projectStatus: "Analyse en cours",
  offersLabel: "Propositions reçues",
  offersValue: "3 offres comparables",
  decisionLabel: "Prochaine décision",
  decisionValue: "Choisir le bon partenaire",
  cycleEyebrow: "Le cycle Matricia",
  cycleTitle: "Une seule plateforme pour avancer, sans perdre le fil.",
  cycleIntro:
    "La complexité reste dans le moteur. Vous voyez seulement les informations utiles, les décisions à prendre et la prochaine action.",
  cycle: [
    { label: "Comprendre", description: "Décrire votre situation" },
    { label: "Structurer", description: "Clarifier les priorités" },
    { label: "Matcher", description: "Identifier les profils adaptés" },
    { label: "Comparer", description: "Évaluer les propositions" },
    { label: "Contractualiser", description: "Sécuriser l’accord" },
    { label: "Exécuter", description: "Suivre la mission" },
    { label: "Suivre", description: "Valider et mesurer" },
  ],
  outcomesEyebrow: "Ce que vous obtenez",
  outcomesTitle: "Plus de clarté à chaque décision.",
  outcomesIntro:
    "Matricia transforme une situation parfois floue en priorités compréhensibles, puis en actions suivies.",
  outcomes: [
    { title: "Des priorités lisibles", description: "Comprenez ce qui mérite votre attention en premier." },
    { title: "Un besoin bien cadré", description: "Conservez un dossier clair, modifiable et partageable." },
    { title: "Des offres comparables", description: "Comparez périmètre, prix, délais, garanties et exclusions." },
    { title: "Une exécution suivie", description: "Pilotez missions, livrables, documents et décisions." },
  ],
  professionalsEyebrow: "Réseau professionnel",
  professionalsTitle: "Des professionnels adaptés à votre contexte.",
  professionalsIntro:
    "Les compétences, capacités et justificatifs sont examinés selon le domaine. La décision finale vous appartient toujours.",
  qualificationBadge: "Qualification suivie",
  professionals: [
    "Compétences reliées aux services recherchés",
    "Documents et capacité suivis dans le temps",
    "Échanges, devis et livrables rassemblés au même endroit",
  ],
  professionalsAction: "Découvrir le parcours professionnel",
  faqEyebrow: "Questions fréquentes",
  faqTitle: "Avant de commencer",
  faq: [
    {
      question: "Dois-je créer un compte pour commencer ?",
      answer:
        "Non. Vous pouvez lancer un premier prédiagnostic sans compte. La connexion intervient lorsque vous souhaitez enregistrer votre bilan ou poursuivre un dossier.",
    },
    {
      question: "Matricia impose-t-elle un prestataire ?",
      answer:
        "Non. Matricia structure votre besoin et facilite la comparaison. Vous restez libre de choisir la proposition qui vous convient.",
    },
    {
      question: "Puis-je commencer avec un besoin déjà précis ?",
      answer:
        "Oui. Le parcours Besoin précis vous demande uniquement les informations nécessaires pour préparer un dossier clair et modifiable.",
    },
  ],
  finalEyebrow: "Matricia",
  finalTitle: "Votre prochaine bonne décision commence ici.",
  finalIntro: "Faites le point, clarifiez votre besoin et avancez avec les bons professionnels.",
  finalPrimary: "Commencer mon analyse",
  finalSecondary: "Décrire un besoin précis",
};

const ar: HomePremiumCopy = {
  eyebrow: "افهم. قرّر. تحرّك.",
  titleLead: "اكتشف ما يعيق تطور مؤسستك.",
  titleAccent: "وانتقل إلى الحلول المناسبة.",
  intro:
    "أجب عن بعض الأسئلة. تساعدك ماتريسيا على فهم أولوياتك ومقارنة العروض المناسبة وتتبع إنجاز خدماتك.",
  primaryAction: "تحليل مؤسستي",
  providerAction: "تقديم خدماتي",
  preciseNeedAction: "لدي حاجة محددة",
  previewLabel: "مسار واضح من الحاجة إلى الإنجاز",
  previewStages: ["الحاجة", "العروض", "الاختيار", "المهمة"],
  projectLabel: "وضعيتك",
  projectTitle: "التنظيم والنمو",
  projectStatus: "التحليل جارٍ",
  offersLabel: "العروض المتوصل بها",
  offersValue: "3 عروض قابلة للمقارنة",
  decisionLabel: "القرار التالي",
  decisionValue: "اختيار الشريك المناسب",
  cycleEyebrow: "دورة ماتريسيا",
  cycleTitle: "منصة واحدة للتقدم دون فقدان سياق العمل.",
  cycleIntro:
    "تبقى التعقيدات داخل المحرك، بينما ترى أنت المعلومات المفيدة والقرارات المطلوبة والخطوة التالية.",
  cycle: [
    { label: "الفهم", description: "وصف الوضعية" },
    { label: "الهيكلة", description: "تحديد الأولويات" },
    { label: "المطابقة", description: "اقتراح المهنيين المناسبين" },
    { label: "المقارنة", description: "تقييم العروض" },
    { label: "التعاقد", description: "تأمين الاتفاق" },
    { label: "التنفيذ", description: "تتبع المهمة" },
    { label: "المتابعة", description: "المصادقة والقياس" },
  ],
  outcomesEyebrow: "ما الذي ستحصل عليه",
  outcomesTitle: "وضوح أكبر في كل قرار.",
  outcomesIntro: "تحول ماتريسيا الوضعية المعقدة إلى أولويات مفهومة ثم إلى إجراءات قابلة للتتبع.",
  outcomes: [
    { title: "أولويات واضحة", description: "اعرف ما يستحق اهتمامك أولاً." },
    { title: "حاجة مؤطرة", description: "احتفظ بملف واضح وقابل للتعديل والمشاركة." },
    { title: "عروض قابلة للمقارنة", description: "قارن النطاق والسعر والآجال والضمانات والاستثناءات." },
    { title: "تنفيذ متابَع", description: "تتبع المهام والتسليمات والوثائق والقرارات." },
  ],
  professionalsEyebrow: "شبكة مهنية",
  professionalsTitle: "مهنيون ملائمون لسياق مؤسستك.",
  professionalsIntro:
    "تتم مراجعة الكفاءات والقدرات والوثائق حسب المجال، ويبقى القرار النهائي بيدك دائماً.",
  qualificationBadge: "تأهيل متابَع",
  professionals: [
    "كفاءات مرتبطة بالخدمات المطلوبة",
    "متابعة الوثائق والقدرة مع مرور الوقت",
    "جمع المحادثات والعروض والتسليمات في مكان واحد",
  ],
  professionalsAction: "اكتشف مسار المهنيين",
  faqEyebrow: "الأسئلة الشائعة",
  faqTitle: "قبل البدء",
  faq: [
    {
      question: "هل يجب إنشاء حساب للبدء؟",
      answer:
        "لا. يمكنك بدء تشخيص أولي دون حساب. تحتاج إلى تسجيل الدخول عند حفظ النتيجة أو متابعة ملفك.",
    },
    {
      question: "هل تفرض ماتريسيا مهنياً معيناً؟",
      answer:
        "لا. تساعدك ماتريسيا على تنظيم حاجتك ومقارنة العروض، ويبقى اختيار العرض المناسب قرارك.",
    },
    {
      question: "هل يمكنني البدء بحاجة محددة مسبقاً؟",
      answer:
        "نعم. يطلب منك مسار الحاجة المحددة فقط المعلومات الضرورية لإعداد ملف واضح وقابل للتعديل.",
    },
  ],
  finalEyebrow: "Matricia",
  finalTitle: "قرارك الجيد التالي يبدأ من هنا.",
  finalIntro: "قيّم وضعيتك وحدد حاجتك وتقدم مع المهنيين المناسبين.",
  finalPrimary: "ابدأ تحليل مؤسستي",
  finalSecondary: "صف حاجة محددة",
};

export function getHomePremiumCopy(locale: HomeLocale): HomePremiumCopy {
  return locale === "ar" ? ar : fr;
}
