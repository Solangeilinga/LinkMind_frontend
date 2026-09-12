// Tests unitaires des fonctions utilitaires de la communauté.
//
// Remplace le smoke test "compteur" par défaut de Flutter (qui référençait
// `package:BASYAM/main.dart` et une classe `MyApp` inexistantes) : l'app
// n'a pas de compteur, et un vrai smoke test de `BASYAMApp` demanderait de
// mocker Hive, le stockage sécurisé et SharedPreferences. On teste ici des
// fonctions pures, sans dépendance de plateforme.

import 'package:flutter_test/flutter_test.dart';
import 'package:basyam/screens/main/community/utils/helpers.dart';

void main() {
  group('anonName', () {
    test('renvoie l\'alias quand il est fourni et non vide', () {
      expect(anonName('post1', alias: 'Lumière'), 'Lumière');
    });

    test('trim l\'alias', () {
      expect(anonName('post1', alias: '  Lumière  '), 'Lumière');
    });

    test('retombe sur "Anonyme" si l\'alias est null, vide ou blanc', () {
      expect(anonName('post1'), '👤 Anonyme');
      expect(anonName('post1', alias: ''), '👤 Anonyme');
      expect(anonName('post1', alias: '   '), '👤 Anonyme');
    });
  });

  group('fmtDate', () {
    test('renvoie une chaîne vide pour null ou une date invalide', () {
      expect(fmtDate(null), '');
      expect(fmtDate('pas une date'), '');
    });

    test('"à l\'instant" pour il y a moins d\'une minute', () {
      final now = DateTime.now().toIso8601String();
      expect(fmtDate(now), "à l'instant");
    });

    test('exprime l\'écart en minutes / heures / jours / semaines', () {
      final now = DateTime.now();
      expect(fmtDate(now.subtract(const Duration(minutes: 5)).toIso8601String()), '5 min');
      expect(fmtDate(now.subtract(const Duration(hours: 3)).toIso8601String()), '3h');
      expect(fmtDate(now.subtract(const Duration(days: 2)).toIso8601String()), '2j');
      expect(fmtDate(now.subtract(const Duration(days: 21)).toIso8601String()), '3sem');
    });
  });

  group('deepCastComment', () {
    test('caste récursivement les réponses imbriquées', () {
      final raw = {
        '_id': 'c1',
        'content': 'top',
        'replies': [
          {'_id': 'c2', 'content': 'réponse', 'replies': []},
        ],
      };
      final casted = deepCastComment(raw);
      expect(casted['_id'], 'c1');
      expect(casted['replies'], isA<List<Map<String, dynamic>>>());
      expect(casted['replies'][0]['content'], 'réponse');
      expect(casted['replies'][0]['replies'], isEmpty);
    });

    test('gère une clé replies absente', () {
      final casted = deepCastComment({'_id': 'c1', 'content': 'seul'});
      expect(casted['replies'], isEmpty);
    });
  });
}
