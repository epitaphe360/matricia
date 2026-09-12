export const moduleHubCopy = {
  fr: {
    title: "Espaces opérationnels",
    description: "Accédez aux modules autorisés pour vos rôles. Chaque espace applique ses contrôles serveur et RLS.",
    links: [
      ["Demandes et devis", "client/demandes"],
      ["Contrats et missions", "client/missions"],
      ["Litiges et réaffectation", "client/litiges"],
      ["Abonnement", "client/abonnement"],
      ["Achats groupés", "client/achats-groupes"],
      ["Qualification Sous-traitant", "sous-traitant/qualification"],
      ["Facturation Sous-traitant", "sous-traitant/facturation"],
      ["Command Center", "administration/command-center"],
    ],
  },
  ar: {
    title: "مساحات العمليات",
    description: "ادخل إلى الوحدات المسموح بها لأدوارك. تطبق كل مساحة صلاحيات الخادم وسياسات RLS.",
    links: [
      ["الطلبات والعروض", "client/demandes"],
      ["العقود والمهام", "client/missions"],
      ["النزاعات وإعادة الإسناد", "client/litiges"],
      ["الاشتراك", "client/abonnement"],
      ["المشتريات المجمعة", "client/achats-groupes"],
      ["تأهيل مقدم الخدمات", "sous-traitant/qualification"],
      ["فواتير مقدم الخدمات", "sous-traitant/facturation"],
      ["مركز القيادة", "administration/command-center"],
    ],
  },
} as const;
