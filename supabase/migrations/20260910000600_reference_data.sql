insert into public.role_definitions (code, scope_type, label_fr, label_ar) values
('SUPER_ADMIN','PLATFORM','Super administrateur','المشرف الأعلى'),
('MATRICIA_ADMIN','PLATFORM','Administrateur Matricia','مسؤول ماتريسيا'),
('COMPLIANCE_MANAGER','PLATFORM','Responsable conformité','مسؤول الامتثال'),
('FINANCE_MANAGER','PLATFORM','Responsable finance','مسؤول المالية'),
('DISPUTE_MANAGER','PLATFORM','Responsable litiges','مسؤول النزاعات'),
('LIBRARY_MANAGER','PLATFORM','Responsable bibliothèque','مسؤول المكتبة'),
('SUPPORT_AGENT','PLATFORM','Agent support','موظف الدعم'),
('READ_ONLY_AUDITOR','PLATFORM','Auditeur lecture seule','مدقق للقراءة فقط'),
('CLIENT_OWNER','ORGANIZATION','Propriétaire client','مالك العميل'),
('CLIENT_ADMIN','ORGANIZATION','Administrateur client','مسؤول العميل'),
('CLIENT_BUYER','ORGANIZATION','Acheteur client','مشتري العميل'),
('CLIENT_ACCOUNTING','ORGANIZATION','Comptabilité client','محاسبة العميل'),
('CLIENT_MEMBER','ORGANIZATION','Membre client','عضو العميل'),
('CLIENT_VIEWER','ORGANIZATION','Observateur client','مشاهد العميل'),
('PROVIDER_OWNER','ORGANIZATION','Propriétaire sous-traitant','مالك مقدم الخدمة'),
('PROVIDER_MANAGER','ORGANIZATION','Responsable sous-traitant','مسؤول مقدم الخدمة'),
('PROVIDER_SALES','ORGANIZATION','Commercial sous-traitant','مبيعات مقدم الخدمة'),
('PROVIDER_TECHNICIAN','ORGANIZATION','Technicien sous-traitant','تقني مقدم الخدمة'),
('PROVIDER_ACCOUNTING','ORGANIZATION','Comptabilité sous-traitant','محاسبة مقدم الخدمة'),
('PROVIDER_VIEWER','ORGANIZATION','Observateur sous-traitant','مشاهد مقدم الخدمة'),
('FRANCHISE_OWNER','FRANCHISE','Propriétaire franchisé','مالك الامتياز'),
('FRANCHISE_MANAGER','FRANCHISE','Responsable franchisé','مسؤول الامتياز'),
('FRANCHISE_EXPERT','FRANCHISE','Expert franchisé','خبير الامتياز'),
('FRANCHISE_PROVIDER_MANAGER','FRANCHISE','Responsable réseau sous-traitants','مسؤول شبكة مقدمي الخدمة'),
('FRANCHISE_ACCOUNTING','FRANCHISE','Comptabilité franchisé','محاسبة الامتياز'),
('FRANCHISE_VIEWER','FRANCHISE','Observateur franchisé','مشاهد الامتياز')
on conflict (code) do nothing;

insert into public.franchise_economic_rule_versions
(franchise_type, version, entry_fee_minor, currency, franchisee_share_bps, neoxa_share_bps, matricia_share_bps, distribution_basis, effective_from, status)
values
('IT',1,0,'MAD',5000,5000,0,'DISTRIBUTABLE_PROFIT','2026-09-10','ACTIVE'),
('STANDARD',1,0,'MAD',5000,2500,2500,'DISTRIBUTABLE_PROFIT','2026-09-10','ACTIVE')
on conflict (franchise_type, version) do nothing;
