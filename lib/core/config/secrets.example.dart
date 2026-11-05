// Copier ce fichier en "secrets.dart" et remplacer les valeurs par les vôtres.
// secrets.dart est ignoré par Git : les vraies clés ne partent jamais sur GitHub.

// ----- Google Gemini (assistant IA) -----
// Clé : https://aistudio.google.com/app/apikey
const String geminiApiKey = 'VOTRE_CLE_GEMINI_ICI';

// ----- EmailJS (emails sans backend) : https://dashboard.emailjs.com -----
// Laisser serviceId OU publicKey vide désactive proprement l'envoi d'emails.
const String emailJsServiceId = ''; // Email Services -> Service ID
const String emailJsPublicKey = ''; // Account -> Public Key
// Facultatif : si « API calls » est en mode strict côté EmailJS.
const String emailJsPrivateKey = '';
// Un modèle (Template ID) par type d'email. Les variables du modèle doivent
// correspondre aux clés envoyées dans template_params (voir EmailService).
const String emailJsTemplateReservation = ''; // confirmation de réservation
const String emailJsTemplateCancellation = ''; // confirmation d'annulation
const String emailJsTemplateWaitlist = ''; // place libérée (liste d'attente)

// ----- Google Calendar (OAuth) : https://console.cloud.google.com -----
// Android : créer un client OAuth « Android » (package com.esprit.mygym + SHA-1),
//           aucun identifiant à mettre ici.
// iOS     : client OAuth « iOS » + reversed client id dans Info.plist.
// serverClientId (client « Web ») est facultatif ; laisser vide sinon.
const String googleServerClientId = '';
