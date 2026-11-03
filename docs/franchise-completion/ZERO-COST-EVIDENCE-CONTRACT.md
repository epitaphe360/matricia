# Frais ou réalisation réellement gratuits : preuve d’admission

Le rapprochement livré exige actuellement un coût HT issu d’un journal de charge positif et une revue Finance indépendante. Un coût absent reste « preuve à fournir ». Une part analytique peut être calculée à zéro par l’arrondi cumulatif d’un coût **réellement prouvé** ; cette situation est distincte d’une prestation ou d’une commission PSP réellement gratuite.

Un relevé fournisseur ou PSP peut réellement établir des frais nuls. Il ne faut ni inventer un journal de montant nul, ni traiter l’absence de ligne de charge comme une preuve de gratuité.

## Contrat d’admission à implémenter avec un coffre Finance adapté

Une proposition `ZERO_COST_DOCUMENT` doit désigner exactement le composant (`PSP_FEE` ou `FULFILLMENT_COST`), sa source canonique (financement vérifié ou réception de prestation), et une version précise d’une pièce privée. Aucun montant, hash, chemin de stockage ou booléen « zéro confirmé » envoyé par le navigateur ne fait autorité.

La pièce doit appartenir à l’organisation de la source financière autorisée, rester sous RLS, avoir ses octets, MIME, taille et SHA-256 vérifiés côté serveur, et disposer d’un résultat antivirus CLEAN issu d’un scanner de confiance. Le serveur fige son identité, son empreinte et le contexte financier réellement consulté. Pour une commission PSP, le document doit rattacher l’exemption ou les frais nuls à la capture ou au règlement exact. Pour la réalisation, il doit décrire la prise en charge ou la gratuité de la prestation reçue, sans déduire celle-ci du simple reçu de livraison.

La décision exige Finance AAL2, un approbateur distinct du proposant, de l’auteur de la pièce, de l’opérateur et du réceptionnaire concernés, sans appartenance à l’organisation bénéficiaire. Elle lie le hash exact de la proposition, sa justification et la pièce consultée. La reprise identique restitue la décision initiale ; une décision opposée échoue. Acceptation, refus et révocation doivent être immuables, audités et émis via l’outbox. Une preuve révoquée ou devenue non admissible bloque les nouvelles clôtures et distributions ; les factures, clôtures et paiements historiques restent conservés.

## Prérequis précisément manquant dans le dépôt

Le coffre Prestataire et ses preuves de paiement sont réservés aux organisations et rôles Prestataire : il serait incorrect d’ajouter ce rôle à un Franchisé pour téléverser une preuve de gratuité. Les pièces Client de conformité prouvent l’identité, pas des frais nuls. La messagerie possède bien un pipeline privé avec scan de confiance et téléchargement autorisé, mais ses fils sont rattachés à des demandes, RFQ, contrats ou missions ; ils ne constituent pas un registre de pièces Finance directement lié à une capture de crédits ou une réception d’avantage.

Il manque donc **un registre Finance de pièces justificatives versionnées, scannées et explicitement rattachées à ces deux types de sources**, avec son import réel et sa consultation lors de la revue indépendante. Aucun document d’identité n’est réutilisé comme exonération, aucune pièce d’un autre tenant n’est acceptée, et aucun hash libre ne remplace ce registre. Tant que ce prérequis n’est pas livré et testé, la gratuité réelle reste une exception de rapprochement visible ; elle ne devient jamais un zéro automatique. Aucun fournisseur, tarif, exonération commerciale ou fiscalité n’est décidé par ce contrat technique.
