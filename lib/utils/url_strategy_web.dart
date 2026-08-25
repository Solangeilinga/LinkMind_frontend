import 'package:flutter_web_plugins/url_strategy.dart';

/// Bascule Flutter web sur des URLs "propres" (/pro/setup-password?token=…)
/// au lieu du mode hash par défaut (/#/pro/setup-password?token=…).
///
/// Sans ça, tout lien profond envoyé par email (configuration du mot de
/// passe pro, refus de rendez-vous, confirmation de rendez-vous pro) est
/// silencieusement ignoré par GoRouter au premier chargement : le routeur
/// ne lit que ce qu'il y a après le "#", qui est vide sur un lien classique
/// — l'app retombe alors sur son point de départ par défaut (déconnecté →
/// écran de connexion), sans jamais avoir vu la vraie destination.
void configurePathUrlStrategy() {
  usePathUrlStrategy();
}
