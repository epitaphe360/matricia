export function casablancaToday(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Africa/Casablanca",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

export function isDocumentExpired(expiresOn: string | null | undefined, today = casablancaToday()) {
  return Boolean(expiresOn && expiresOn < today);
}

export function expiredDocuments<T extends { expiresOn: string | null }>(documents: T[], today = casablancaToday()) {
  return documents.filter((document) => isDocumentExpired(document.expiresOn, today));
}

export function reusableDocuments<T extends { expiresOn: string | null }>(documents: T[], today = casablancaToday()) {
  return documents.filter((document) => !isDocumentExpired(document.expiresOn, today));
}
