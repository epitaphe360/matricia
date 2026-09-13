# V4.1 — Incident sécurité

1. Créer un incident avec corrélation, sévérité et résumé expurgé. Ne jamais placer PII, secret, prompt ou credential dans les logs.
2. Contenir : révoquer les sessions/tokens concernés, suspendre les jobs/provider et préserver les preuves append-only.
3. Qualifier les cas RIB frauduleux, takeover admin, replay webhook, prompt injection, export massif, privilege drift, malware ou exposition.
4. Escalader aux rôles sécurité/conformité; déclencher les obligations légales/CNDP applicables sans affirmer qu’elles sont accomplies avant preuve.
5. Corriger, faire auditer indépendamment, restaurer le service, puis fermer avec hashes d’artefacts et chronologie.

Toute action sensible exige AAL2. Les changements de droits, exports et reprocess DLQ suivent le four-eyes. Les scans SBOM/SAST/secrets/RLS/CSP/SSRF/antivirus/chiffrement restent `REQUIRED_NOT_COMPLETED` tant que leur artefact n’est pas enregistré.
