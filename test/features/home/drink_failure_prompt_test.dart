import 'package:flutter_test/flutter_test.dart';
import 'package:drink_water_app/core/services/drink_api_service.dart';
import 'package:drink_water_app/features/home/home_controller.dart';

void main() {
  group('drinkFailurePrompt', () {
    test('登录态过期时引导重新登录', () {
      final prompt = drinkFailurePrompt(
        const DrinkResult(success: false, code: -99, message: '登录状态已过期'),
        fallback: '设备无响应，请检查设备状态',
      );

      expect(prompt.isSessionExpired, isTrue);
      expect(prompt.title, '登录已过期');
      expect(prompt.message, '请重新登录后再试');
      expect(prompt.message, isNot(contains('设备无响应')));
    });

    test('其他业务错误透出服务端信息', () {
      final prompt = drinkFailurePrompt(
        const DrinkResult(success: false, code: -100, message: '系统错误'),
        fallback: '设备无响应，请检查设备状态',
      );

      expect(prompt.isSessionExpired, isFalse);
      expect(prompt.title, '失败');
      expect(prompt.message, '系统错误');
      expect(prompt.message, isNot(contains('设备无响应')));
    });

    test('无服务端信息时退回 fallback', () {
      final prompt = drinkFailurePrompt(
        const DrinkResult(success: false),
        fallback: '设备无响应，请检查设备状态',
      );

      expect(prompt.isSessionExpired, isFalse);
      expect(prompt.message, '设备无响应，请检查设备状态');
    });
  });
}
