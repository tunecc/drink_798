import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/services/drink_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrinkApiService token init', () {
    test('valid stored token loads and reports logged in', () async {
      SharedPreferences.setMockInitialValues({
        'drink_water_app_token': '{"uid":"u1","eid":"e1","token":"t1"}',
        'drink_water_app_is_login': true,
      });

      final api = DrinkApiService();

      expect(await api.isLoggedIn(), isTrue);
    });
  });
}
