import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/features/login/login_controller.dart';

import 'fake_drink_api_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  testWidgets('injected service drives onInit, and the image decodes', (
    tester,
  ) async {
    final api = FakeDrinkApiService();
    final controller = LoginController(apiService: api);

    // Get.put 同步触发 onInit，但 getCaptcha 是 await 的，
    // 图片要等一个微任务才落到 Rx 上，因此这里用 Obx 而不是直接取值。
    Get.put(controller);
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Obx(() {
            final image = controller.captchaImage.value;
            return image == null
                ? const SizedBox.shrink()
                : SizedBox(height: 60, child: Image.memory(image));
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.captchaCalls, 1);
    expect(controller.captchaImage.value, kTestPngBytes);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
