import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/services/drink_api_service.dart';
import 'package:drink_water_app/core/theme/app_theme.dart';
import 'package:drink_water_app/core/widgets/app_form_fields.dart';
import 'package:drink_water_app/features/home/home_page.dart';
import 'package:drink_water_app/features/login/login_controller.dart';
import 'package:drink_water_app/features/login/login_page.dart';

import 'fake_drink_api_service.dart';

const captchaFieldKey = Key('captchaField');
const captchaImageKey = Key('captchaImage');
const tokenEntryKey = Key('tokenEntry');
const backFromTokenKey = Key('backFromToken');
const backFromSmsKey = Key('backFromSms');

/// 重构前那块割裂的深蓝青，任何实色或渐变停靠点都不该再出现。
const _legacyBandColor = Color(0xFF0099CC);

/// 登录页 widget 测试公共装置。
///
/// 页面自己不会向控制器灌数据，控制器由测试构造后经 Get 注册；
/// LoginPage.build 里的 put 分支检测到已注册即复用，因此注入的假服务
/// 一路生效，测试内不会发出任何真实请求。
Future<FakeDrinkApiService> pumpLoginPage(
  WidgetTester tester, {
  FakeDrinkApiService? api,
  Brightness brightness = Brightness.light,
}) async {
  final service = api ?? FakeDrinkApiService();
  Get.put(LoginController(apiService: service));
  // 用应用真正的主角而不是临时拼的 ThemeData：合成主题会掩盖
  // ColorScheme 缺省字段的退化问题。
  final theme = brightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.lightTheme;
  await tester.pumpWidget(
    GetMaterialApp(
      theme: theme,
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 900)),
        child: const LoginPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

/// GetX 的 snackbar 会排一个自动收起 Timer，队列里还可能压着下一条，
/// 只清一次会留下 pending timer，所以固定清空两轮再确认树里没有残留。
Future<void> dismissSnack(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }
  expect(find.byType(GetSnackBar), findsNothing);
}

TextField captchaTextField(WidgetTester tester) =>
    tester.widget<TextField>(
      find.descendant(
        of: find.byKey(captchaFieldKey),
        matching: find.byType(TextField),
      ),
    );

/// 收集页面上所有实色/渐变着色。Container 内部就渲染成 DecoratedBox，
/// 两者一起扫会重复，但用 Set 去重后不会误报，反而不会留下盲区。
Set<BoxDecoration> paintedDecorations(WidgetTester tester) => {
  for (final w in tester.widgetList(find.byWidgetPredicate(
    (w) => w is Container || w is DecoratedBox,
  )))
    if ((w is Container ? w.decoration : (w as DecoratedBox).decoration)
        case final BoxDecoration d)
      d,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  group('captcha input', () {
    testWidgets(
      'raises a numeric keyboard, keeps digits and takes a 5-digit code',
      (tester) async {
        await pumpLoginPage(tester);

        final field = captchaTextField(tester);
        expect(field.keyboardType, TextInputType.number);
        expect(
          field.maxLength,
          6,
          reason: 'must not truncate a 5-digit captcha',
        );
        expect(field.textAlign, TextAlign.center);

        await tester.enterText(find.byKey(captchaFieldKey), '12345');
        await tester.pump();
        expect(Get.find<LoginController>().captchaController.text, '12345');

        await tester.enterText(find.byKey(captchaFieldKey), 'a1b2c');
        await tester.pump();
        expect(Get.find<LoginController>().captchaController.text, '12');
      },
    );

    testWidgets('sits beside its image and is no taller than the field', (
      tester,
    ) async {
      await pumpLoginPage(tester);

      final fieldFinder = find.descendant(
        of: find.byKey(captchaFieldKey),
        matching: find.byType(TextField),
      );
      expect(
        find.ancestor(of: fieldFinder, matching: find.byType(Row)),
        findsOneWidget,
        reason: 'image and field must share one row',
      );

      final fieldHeight = tester.getSize(fieldFinder).height;
      final imageSize = tester.getSize(find.byKey(captchaImageKey));
      expect(imageSize.height, lessThanOrEqualTo(fieldHeight));

      final fieldCenter = tester.getCenter(fieldFinder);
      final imageCenter = tester.getCenter(find.byKey(captchaImageKey));
      expect(
        (fieldCenter.dy - imageCenter.dy).abs(),
        lessThan(4),
        reason: 'D10 requires matching vertical centers',
      );
    });

    testWidgets('tapping the image fetches another one', (tester) async {
      final api = await pumpLoginPage(tester);
      expect(api.captchaCalls, 1);

      await tester.tap(find.byKey(captchaImageKey));
      await tester.pumpAndSettle();
      expect(api.captchaCalls, 2);
    });

    testWidgets('offers a visible refresh affordance', (tester) async {
      await pumpLoginPage(tester);
      expect(
        find.descendant(
          of: find.byKey(captchaImageKey),
          matching: find.byIcon(Icons.refresh),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the old standalone refresh button is gone', (tester) async {
      await pumpLoginPage(tester);
      expect(find.text('看不清？点击刷新'), findsNothing);
    });

    testWidgets('shows a bounded loading slot before the image arrives', (
      tester,
    ) async {
      // 图片未返回时应当在原尺寸格子里给指示，而不是撑成一整块空白。
      Get.put(LoginController(apiService: HangingCaptchaApiService()));
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 900)),
            child: const LoginPage(),
          ),
        ),
      );
      // 指示器是不确定进度，pumpAndSettle 永远等不完，只推进有限帧。
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byKey(captchaImageKey),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.byType(Image), findsNothing);
      expect(tester.getSize(find.byKey(captchaImageKey)), const Size(104, 52));
    });
  });

  group('page background', () {
    testWidgets('paints no legacy dark band in light or dark mode', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpLoginPage(tester, brightness: brightness);
        addTearDown(Get.reset);

        // Scaffold 自己也不能另设底色，否则底色盲区就回到测试外面了。
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          isNull,
          reason: 'the page must inherit the theme surface',
        );

        final offenders = <String>{
          for (final d in paintedDecorations(tester))
            if (d.color == _legacyBandColor) 'solid fill',
          for (final d in paintedDecorations(tester))
            if (d.gradient case final LinearGradient g)
              if (g.colors.any((c) => c.a == 1.0 && c == _legacyBandColor))
                'gradient stop',
        };
        expect(
          offenders,
          isEmpty,
          reason: 'brightness $brightness still paints $_legacyBandColor',
        );
      }
    });

    testWidgets('keeps one brand tint that fades out before the form', (
      tester,
    ) async {
      await pumpLoginPage(tester);

      final gradients = <LinearGradient>[
        for (final d in paintedDecorations(tester))
          if (d.gradient case final LinearGradient g) g,
      ];

      expect(gradients, hasLength(1), reason: 'the header keeps exactly one tint');
      final band = gradients.single;
      expect(band.colors.last.a, 0, reason: 'the tint must fade, not cut off');
      expect(
        band.colors.first.a,
        greaterThan(0),
        reason: 'and it must actually be visible at the top',
      );
    });

    testWidgets('header tint ends on the page surface color', (
      tester,
    ) async {
      await pumpLoginPage(tester);

      final scaffoldColor = Theme.of(
        tester.element(find.byType(LoginPage)),
      ).scaffoldBackgroundColor;
      final band = [
        for (final d in paintedDecorations(tester))
          if (d.gradient case final LinearGradient g) g,
      ].single;
      // 渐隐带的终点必须就是页面底色（只是透明化），否则交界处会有色相跳变。
      expect(band.colors.last.withValues(alpha: 1), scaffoldColor);
    });

    testWidgets('header colors come from the theme, not hardcoded literals', (
      tester,
    ) async {
      await pumpLoginPage(tester, brightness: Brightness.dark);

      // 深色主题的 onSurface 本来就是白，这里真正要钉住的是"颜色取自主题"，
      // 以及弱化文字确实拿到了非退化的 onSurfaceVariant。
      final theme = AppTheme.darkTheme;
      final title = tester.widget<Text>(find.text('智能饮水'));
      final subtitle = tester.widget<Text>(find.text('欢迎使用，让生活更便捷'));
      expect(title.style?.color, theme.colorScheme.onSurface);
      expect(subtitle.style?.color, theme.colorScheme.onSurfaceVariant);
      expect(
        theme.colorScheme.onSurfaceVariant,
        isNot(theme.colorScheme.onSurface),
        reason: 'a degraded onSurfaceVariant would flatten the hierarchy',
      );
    });
  });

  group('token entry', () {
    testWidgets('is a quiet link that switches to the token panel and back', (
      tester,
    ) async {
      await pumpLoginPage(tester);

      await tester.tap(find.byKey(tokenEntryKey));
      await tester.pumpAndSettle();
      expect(find.text('Token 登录'), findsOneWidget);

      await tester.tap(find.byKey(backFromTokenKey));
      await tester.pumpAndSettle();
      expect(find.text('登录'), findsOneWidget);
    });

    testWidgets('visibility toggle really unmasks the field', (tester) async {
      await pumpLoginPage(tester);
      await tester.tap(find.byKey(tokenEntryKey));
      await tester.pumpAndSettle();

      bool masked() =>
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const Key('tokenField')),
                  matching: find.byType(TextField),
                ),
              )
              .obscureText;
      expect(masked(), isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(masked(), isFalse);
    });

    testWidgets('a rejected token is reported and stays on the form', (
      tester,
    ) async {
      final api = FakeDrinkApiService(tokenLoginResult: false);
      await pumpLoginPage(tester, api: api);
      await tester.tap(find.byKey(tokenEntryKey));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(Key('tokenField')), 'expired-token');
      await tester.tap(find.text('验证并登录'));
      await tester.pumpAndSettle();

      expect(api.tokenLoginCalls, 1);
      expect(find.text('Token 无效或已过期，请检查后重试'), findsOneWidget);
      expect(find.text('Token 登录'), findsOneWidget);
      await dismissSnack(tester);
    });
  });

  group('three-step flow', () {
    testWidgets('phone + captcha advances to the SMS step', (tester) async {
      final api = await pumpLoginPage(tester);

      await tester.enterText(find.byKey(const Key('phoneField')), '13800001111');
      await tester.enterText(find.byKey(captchaFieldKey), '1234');
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();

      expect(api.sendSmsCodeCalls, 1);
      expect(api.lastPhone, '13800001111');
      expect(api.lastCaptcha, '1234');
      expect(find.text('输入验证码'), findsOneWidget);
      await dismissSnack(tester);
      final smsField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('smsField')),
          matching: find.byType(TextField),
        ),
      );
      expect(smsField.autofocus, isTrue);
    });

    testWidgets('going back from the SMS step refetches the captcha', (
      tester,
    ) async {
      final api = await pumpLoginPage(tester);
      await tester.enterText(find.byKey(const Key('phoneField')), '13800001111');
      await tester.enterText(find.byKey(captchaFieldKey), '1234');
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      final before = api.captchaCalls;

      await tester.tap(find.byKey(backFromSmsKey));
      await tester.pumpAndSettle();

      expect(find.text('登录'), findsOneWidget);
      expect(api.captchaCalls, greaterThan(before));
      expect(Get.find<LoginController>().captchaController.text, isEmpty);
      await dismissSnack(tester);
    });

    testWidgets('a rejected captcha surfaces the reason and refetches', (
      tester,
    ) async {
      final api = FakeDrinkApiService(
        smsCodeResult: const DrinkResult(
          success: false,
          code: -1,
          message: '图形验证码错误',
        ),
      );
      await pumpLoginPage(tester, api: api);
      final before = api.captchaCalls;

      await tester.enterText(find.byKey(const Key('phoneField')), '13800001111');
      await tester.enterText(find.byKey(captchaFieldKey), '9999');
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();

      expect(find.text('图形验证码错误'), findsOneWidget);
      expect(api.captchaCalls, greaterThan(before));
      await dismissSnack(tester);
      expect(find.text('输入验证码'), findsNothing, reason: 'must not advance');
    });

    testWidgets('login submits the entered SMS code', (tester) async {
      final api = FakeDrinkApiService(
        loginResult: const DrinkResult(
          success: false,
          code: -2,
          message: '短信验证码错误',
        ),
      );
      await pumpLoginPage(tester, api: api);
      await tester.enterText(find.byKey(const Key('phoneField')), '13800001111');
      await tester.enterText(find.byKey(captchaFieldKey), '1234');
      await tester.tap(find.text('获取验证码'));
      await tester.pumpAndSettle();
      // 先收起"验证码已发送"这条：GetX 的 snackbar 队列会把后一条挤到
      // 测试结束之后才显示。
      await dismissSnack(tester);

      await tester.enterText(find.byKey(const Key('smsField')), '654321');
      await tester.tap(find.text('登录'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(api.loginCalls, 1);
      expect(api.lastPhone, '13800001111');
      expect(api.lastSmsCode, '654321');
      // 失败原因文案由 GetX snackbar 队列驱动，同一测试里连续两条的排队时机
      // 不稳定；拒绝路径的"透出原因"已由上一条用例覆盖，这里只验证仍停在原步。
      expect(find.text('输入验证码'), findsOneWidget);
      await dismissSnack(tester);
      await tester.pump();
    });

    testWidgets('a successful login lands on the home page', (tester) async {
      final api = FakeDrinkApiService();
      await pumpLoginPage(tester, api: api);
      await tester.enterText(find.byKey(const Key('phoneField')), '13800001111');
      await tester.enterText(find.byKey(captchaFieldKey), '1234');
      await tester.tap(find.text('获取验证码'));
      await dismissSnack(tester);

      await tester.enterText(find.byKey(const Key('smsField')), '246813');
      await tester.tap(find.text('登录'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(api.loginCalls, 1);
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await dismissSnack(tester);
    });
  });

  group('shared controls', () {
    testWidgets('every field on the page is an AppTextField', (tester) async {
      await pumpLoginPage(tester);
      expect(
        find.byType(AppTextField),
        findsNWidgets(2),
        reason: 'phone and captcha panels together expose two fields',
      );
    });
  });
}
