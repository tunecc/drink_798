import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/services/drink_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrinkApiService token init', () {
    test('corrupt stored token json does not throw and is ignored', () async {
      SharedPreferences.setMockInitialValues({
        'drink_water_app_token': '{"uid": broken',
        'drink_water_app_is_login': true,
      });

      final api = DrinkApiService();

      expect(await api.isLoggedIn(), isFalse);
    });
  });
}
