// messaging_platform.dart — bascule automatiquement d'implémentation selon
// la plateforme de compilation. Par défaut (web), le stub sans dépendance
// firebase_messaging est utilisé ; sur mobile/desktop (dart.library.io
// disponible), la vraie implémentation Firebase est utilisée à la place.
export 'messaging_platform_web.dart'
    if (dart.library.io) 'messaging_platform_io.dart';
