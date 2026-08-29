import 'dart:async';

/// File d'attente partagée pour le stockage sécurisé (FlutterSecureStorage).
///
/// ⚠️ Pourquoi ce fichier existe : sur le web, FlutterSecureStorage s'appuie
/// sur IndexedDB. Quand deux parties de l'app écrivent CHACUNE leur propre
/// jeton EN MÊME TEMPS (par ex. connexion testeur + connexion pro lancées en
/// parallèle via Future.wait), les deux écritures concurrentes peuvent entrer
/// en collision au niveau du navigateur — l'une des deux échoue alors
/// silencieusement, même si les identifiants étaient corrects et que l'appel
/// réseau a bien réussi.
///
/// La solution : ne jamais laisser deux opérations de stockage s'exécuter
/// réellement en même temps, peu importe quel service (ApiService,
/// ProApiService, ou un autre à l'avenir) les déclenche. Chaque appel passe
/// par cette file d'attente unique, qui les exécute un par un, dans l'ordre
/// d'arrivée — les appels réseau, eux, restent pleinement parallèles ; seule
/// la toute dernière étape (l'écriture elle-même) est sérialisée.
class SecureStorageQueue {
  static Future<void> _queue = Future.value();

  static Future<T> run<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    // On avale l'erreur ici uniquement pour ne jamais bloquer les opérations
    // suivantes dans la file — l'erreur reste normalement propagée à
    // l'appelant via `result`, qu'on retourne tel quel juste après.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }
}