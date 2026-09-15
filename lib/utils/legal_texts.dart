// lib/utils/legal_texts.dart
// Textes légaux BASYAM
//
// Le texte réel des CGU affiché dans l'app vit dans assets/legal/terms.txt
// (chargé par legal_terms_screen.dart) ; la politique de confidentialité est
// hébergée sur le site (basyam.com/legal/privacy), ouverte via un lien
// externe depuis les réglages. Seuls les textes courts ci-dessous (bandeau
// et message SOS) sont réellement utilisés dans l'app.

class LegalTexts {

  // ─── Disclaimer médical court (bandeau affiché en haut de l'écran) ──────────
  static const String medicalDisclaimer = '''
Information importante

BASYAM est un outil de soutien au bien-être. Il n'est pas médecin, psychologue ou thérapeute.

Les informations fournies ne constituent pas un diagnostic médical ni un avis thérapeutique. Pour toute situation de crise ou besoin médical, consulte un professionnel de santé.

En cas d'urgence : SAMU 15, disponible 24h/24
''';

  // ─── Disclaimer court (bandeau) ──────────────────────────────────────────────
  static const String wellnessShortDisclaimer =
      'BASYAM ne remplace pas un professionnel de santé';

  // ─── MESSAGE SOS ─────────────────────────────────────────────────────────────
  static const String sosMessage = '''
🆘 Tu traverses une crise ?

Tu n'es pas seul(e). Des personnes sont là pour t'aider maintenant.

📞 SAMU — 15 (urgences médicales)
📞 Police secours — 17
📞 Pompiers — 18

Si tu as des pensées de te faire du mal, appelle le 15 immédiatement ou demande à quelqu'un de confiance de t'accompagner aux urgences.

Ton bien-être est notre priorité.
''';
}