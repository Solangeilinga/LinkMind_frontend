// messaging_platform.dart — bascule automatiquement d'implémentation selon
// la plateforme de compilation. Web et mobile/desktop utilisent tous deux
// la vraie implémentation Firebase (l'ancien stub web désactivé n'est plus
// nécessaire depuis la mise à jour de firebase_messaging).
export 'messaging_platform_web.dart'
    if (dart.library.io) 'messaging_platform_io.dart';