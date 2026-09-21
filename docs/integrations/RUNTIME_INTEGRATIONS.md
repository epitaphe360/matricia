# Intégrations runtime — état vérifié

Date de vérification : 2026-09-15.

Ce document décrit uniquement les contrats de configuration. Il ne contient aucune valeur de secret.

## Courriel transactionnel

Le worker de notifications échoue fermé par défaut. Deux adaptateurs sont disponibles :

- Resend natif, avec `RESEND_API_KEY`, `RESEND_FROM_EMAIL` et éventuellement `RESEND_FROM_NAME` ;
- fournisseur HTTP générique strictement allowlisté, avec `EMAIL_PROVIDER_ENDPOINT`, `EMAIL_PROVIDER_ENDPOINT_ALLOWLIST` et `EMAIL_PROVIDER_TOKEN`.

Les deux exigent `EMAIL_DELIVERY_MODE=EXTERNAL`, `EMAIL_LIVE_DELIVERY_ENABLED=true` et une destination autorisée par `EMAIL_RECIPIENT_ALLOWLIST`. Le mode `DEMO` est interdit lorsque `NODE_ENV=production`. L'idempotence logique est transmise au fournisseur. Une réponse fournisseur sans identifiant valide reste un échec réessayable : elle n'est jamais présentée comme livrée.

## Event Outbox

Les événements `DocumentUploadedV1` sont consommés par le worker de scan documentaire. Les autres événements sont envoyés à `/api/internal/outbox`, qui est désormais explicitement identifié comme consommateur terminal `TERMINAL_OBSERVABILITY`.

Ce consommateur :

- authentifie la requête avec `INTERNAL_WEBHOOK_SECRET` ;
- valide strictement l'enveloppe et sa taille ;
- écrit uniquement les métadonnées minimales de corrélation dans le journal structuré ;
- n'écrit jamais le payload métier dans les logs ;
- répond `OUTBOX_EVENT_OBSERVED`, sans prétendre avoir exécuté un effet métier.

Tout nouvel effet asynchrone métier doit être implémenté comme consommateur dédié avant que l'événement correspondant puisse être considéré traité par cet effet. Le terminal d'observabilité ne remplace ni une notification, ni un paiement, ni une signature.

## URL publique et SEO

L'URL canonique est résolue dans cet ordre : `NEXT_PUBLIC_APP_URL`, `VERCEL_PROJECT_PRODUCTION_URL`, puis `VERCEL_URL`. En production, seules les URL HTTPS sans identifiants intégrés sont acceptées. Une configuration absente ou invalide fait échouer la construction des métadonnées au lieu de publier des liens `localhost`.

## Signature électronique

`@matricia/signature-v41` définit le contrat `SignatureProvider` et une garde de readiness. Le mock fourni est limité au développement, au niveau `SIMPLE`, et est refusé en production.

Une mise en service réelle reste une décision externe : sélectionner un fournisseur compatible avec le niveau juridique requis au Maroc, obtenir ses identifiants et implémenter son adaptateur. La garde attend uniquement les noms de configuration `SIGNATURE_PROVIDER_MODE` et `SIGNATURE_PROVIDER_CODE`; elle ne résout, n'affiche et ne journalise aucun secret. Aucun adaptateur réel n'est simulé dans le dépôt.

