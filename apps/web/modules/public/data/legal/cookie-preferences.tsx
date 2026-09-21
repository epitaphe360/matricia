"use client";

import { useEffect, useState } from "react";
import type { Locale } from "@/modules/shared/lib/i18n/locale";

const storageKey = "matricia.cookie-preferences.v1";

export function CookiePreferences({ locale }: { locale: Locale }) {
  const [hydrated, setHydrated] = useState(false);
  const [serviceMessages, setServiceMessages] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(storageKey);
      if (raw) {
        const value = JSON.parse(raw) as { serviceMessages?: boolean };
        setServiceMessages(value.serviceMessages === true);
      }
    } catch {
      /* keep defaults */
    }
    setHydrated(true);
  }, []);

  function save() {
    window.localStorage.setItem(storageKey, JSON.stringify({ serviceMessages, updatedAt: new Date().toISOString() }));
    setSaved(true);
  }

  if (!hydrated) return <p>{locale === "ar" ? "جارٍ تحميل تفضيلاتكم…" : "Chargement de vos préférences…"}</p>;

  return (
    <form
      className="mt-8 rounded-2xl border border-[#eadfce] bg-white p-6"
      onSubmit={(event) => {
        event.preventDefault();
        save();
      }}
    >
      <h2>{locale === "ar" ? "إدارة تفضيلاتي" : "Gérer mes préférences"}</h2>
      <label className="mt-4 flex min-h-11 items-start gap-3">
        <input type="checkbox" checked disabled className="mt-1 size-5" />
        <span>
          <strong>{locale === "ar" ? "ضرورية" : "Nécessaires"}</strong>
          <span className="mt-1 block text-sm text-slate-600">{locale === "ar" ? "اللغة والجلسة والأمن. لا يمكن تعطيلها." : "Langue, session et sécurité. Elles ne peuvent pas être désactivées."}</span>
        </span>
      </label>
      <label className="mt-4 flex min-h-11 items-start gap-3">
        <input type="checkbox" checked={serviceMessages} onChange={(event) => { setServiceMessages(event.target.checked); setSaved(false); }} className="mt-1 size-5 accent-[#6d3cc7]" />
        <span>
          <strong>{locale === "ar" ? "رسائل الخدمة" : "Messages de service"}</strong>
          <span className="mt-1 block text-sm text-slate-600">{locale === "ar" ? "قبول إعادة الاتصال لمعلومات غير تجارية حول مساركم." : "Accepter d’être recontacté pour des informations non commerciales liées à votre parcours."}</span>
        </span>
      </label>
      <button type="submit" className="journey-primary mt-6">{locale === "ar" ? "حفظ التفضيلات" : "Enregistrer mes préférences"}</button>
      {saved ? <p role="status" className="mt-3 text-sm text-emerald-800">{locale === "ar" ? "تم حفظ اختياراتكم على هذا الجهاز." : "Vos choix sont enregistrés sur cet appareil."}</p> : null}
    </form>
  );
}
