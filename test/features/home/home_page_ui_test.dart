import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/models/device_model.dart';
import 'package:drink_water_app/core/theme/app_theme.dart';
import 'package:drink_water_app/features/home/home_controller.dart';
import 'package:drink_water_app/features/home/home_page.dart';

import 'fake_home_api_service.dart';

const _twoDevices = [
  {'id': '101', 'name': '1栋101'},
  {'id': '102', 'name': '1栋102'},
];

/// 首页 widget 测试公共装置。
///
/// 控制器由测试构造后经 Get 注册，`HomePage.build` 的 isRegistered 分支复用
/// 它，因此注入的替身一路生效，测试内不会发出任何真实请求。
///
/// 这里用 `pump()` 而不是 `pumpAndSettle()`：接水中状态下页面的气泡动画每 200ms
/// 造一个新 bubble、progress 动画又持续产帧，settle 永远等不到空闲会超时。
Future<FakeHomeApiService> pumpHomePage(
  WidgetTester tester, {
  List<Map<String, dynamic>> devices = _twoDevices,
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 900),
  double textScale = 1.0,
  FakeHomeApiService? api,
}) async {
  // 只套一层 MediaQuery 不会改变真实绘制尺寸（测试窗口仍是 800x600），
  // 列表因此只排得下一项，断言会摸到被裁掉的第二个设备项。
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = api ?? FakeHomeApiService(devices: devices);
  Get.put(HomeController(apiService: service));
  final theme = brightness == Brightness.dark
      ? AppTheme.darkTheme
      : AppTheme.lightTheme;

  await tester.pumpWidget(
    GetMaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const HomePage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  return service;
}

/// GetX 的 snackbar 会排自动收起 Timer，队列里还可能压着下一条，
/// 固定清空两轮再确认树里没有残留，和登录页装置保持一致。
Future<void> dismissSnack(WidgetTester tester) async {
  for (var i = 0; i < 2; i++) {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 900));
  }
  expect(find.byType(GetSnackBar), findsNothing);
}

// ---- 对比度装置：与 design.md 记录的 WCAG 公式同源，断言关系而不是字面 hex ----

double _lin(int c) {
  final v = c / 255.0;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double luminance(Color color) {
  final c = color.withValues(alpha: 1.0);
  return 0.2126 * _lin((c.r * 255).round()) +
      0.7152 * _lin((c.g * 255).round()) +
      0.0722 * _lin((c.b * 255).round());
}

/// 半透明前景先压到背景上，再算比值 —— 与实机合成顺序一致。
Color composite(Color fg, Color bg) {
  final f = fg.withValues(alpha: 1.0);
  final b = bg.withValues(alpha: 1.0);
  return Color.fromRGBO(
    (f.r * 255 * fg.a + b.r * 255 * (1 - fg.a)).round(),
    (f.g * 255 * fg.a + b.g * 255 * (1 - fg.a)).round(),
    (f.b * 255 * fg.a + b.b * 255 * (1 - fg.a)).round(),
    1,
  );
}

double contrast(Color a, Color b) {
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 背景本身可能半透明（接水中状态卡的图标底就是 white@0.18）：先把背景压平到
/// 它身后的面上再算，否则任何半透明都会被读成纯白，断言就白做。
double contrastOn(Color fg, Color bg, {Color backdrop = Colors.white}) {
  final flat = bg.a >= 0.999 ? bg : composite(bg, backdrop);
  return contrast(composite(fg, flat), flat);
}

/// 落在页面本体上的文字，实际背景是顶部带色到本体色之间的一段渐变，
/// 取两个极端里更差的那个才算稳。
double contrastOnPageText(Color ink, Color base, Color band) => math.min(
  contrastOn(ink, base),
  contrastOn(ink, band),
);

/// 收集页面上所有实色/渐变着色，Container 内部渲染成 DecoratedBox，
/// 一起扫会重复但 Set 去重后不会留盲区。
Set<BoxDecoration> paintedDecorations(WidgetTester tester) => {
  for (final w in tester.widgetList(
    find.byWidgetPredicate((e) => decorationOf(e) is BoxDecoration),
  ))
    if (decorationOf(w) case final BoxDecoration d)
      d,
};

/// 页面上所有实际绘制的渐变停靠色。
List<Color> paintedGradientStops(WidgetTester tester) => [
  for (final d in paintedDecorations(tester))
    if (d.gradient case final LinearGradient g)
      for (final c in g.colors)
        if (c.a > 0) c,
];

/// 从任意绘制类 widget 上取装饰；AnimatedContainer 不是 Container 的子类，
/// 所以三类都要认。
Decoration? decorationOf(Widget w) => switch (w) {
  Container() => w.decoration,
  AnimatedContainer() => w.decoration,
  DecoratedBox() => w.decoration,
  Card() => null,
  _ => null,
};

/// 取某个 key 自身（优先）或其后代第一个带 BoxDecoration 的绘制容器。
BoxDecoration decorationAt(WidgetTester tester, Key key) {
  final self = find.byKey(key);
  expect(self, findsWidgets, reason: 'missing widget with key $key');

  for (final w in tester.widgetList(self)) {
    if (decorationOf(w) case final BoxDecoration d) return d;
  }
  for (final w in tester.widgetList(
    find.descendant(
      of: self,
      matching: find.byWidgetPredicate(
        (e) => decorationOf(e) is BoxDecoration,
      ),
    ),
  )) {
    return decorationOf(w)! as BoxDecoration;
  }
  throw StateError('widget $key paints no BoxDecoration');
}

/// 一个绘制装饰代表的那块"面"的主色：实色直接取，渐变取最浅的停靠色。
Color surfaceColor(BoxDecoration d) {
  if (d.color case final c?) return c;
  final g = d.gradient! as LinearGradient;
  return g.colors.reduce((a, b) => luminance(a) >= luminance(b) ? a : b);
}

/// 背景层的主色（取渐变的终止停靠，即页面本体色）。
Color pageBaseColor(WidgetTester tester) {
  final d = decorationAt(tester, homeBackgroundKey);
  if (d.color case final c?) return c;
  return (d.gradient! as LinearGradient).colors.last;
}

/// 顶带最饱和的一端，页面上半部分的文字其实压在这一带与本体色之间。
Color pageBandColor(WidgetTester tester) {
  final d = decorationAt(tester, homeBackgroundKey);
  if (d.color case final c?) return c;
  return (d.gradient! as LinearGradient).colors.first;
}

/// 某个 key 子树里的文字颜色，按文本内容取。
Color textColorIn(WidgetTester tester, Key key, String text) {
  final found = find.descendant(
    of: find.byKey(key),
    matching: find.text(text),
  );
  expect(found, findsOneWidget, reason: 'no "$text" inside $key');
  final t = tester.widget<Text>(found);
  final color = t.style?.color;
  if (color == null) throw StateError('"$text" carries no explicit color');
  return color;
}

/// 找到某个文字身后那块真正的"面"：对话框底是 MaterialType.card，
/// 按钮自己的 Material 不是，所以按类型取才不会再拿错透明底。
Color surfaceBehind(WidgetTester tester, String text) {
  final f = find.ancestor(of: find.text(text), matching: find.byType(Material));
  for (final m in tester.widgetList<Material>(f)) {
    if (m.type == MaterialType.card && (m.color?.a ?? 0) > 0.99) return m.color!;
  }
  throw StateError('no opaque card surface behind "$text"');
}

/// 文字真正吃到的颜色：按钮标签的颜色是经 DefaultTextStyle 下发的，
/// Text.style 上不留 color，但绘制结果就是那个颜色。
Color textColorAt(WidgetTester tester, Finder f) {
  expect(f, findsOneWidget, reason: 'expected exactly one Text');
  final t = tester.widget<Text>(f);
  if (t.style?.color case final c?) return c;
  final inherited = DefaultTextStyle.of(tester.element(f)).style.color;
  if (inherited case final c?) return c;
  throw StateError('that Text resolves to no color');
}

Color effectiveTextColor(WidgetTester tester, String text) =>
    textColorAt(tester, find.text(text));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Get.reset);

  group('test seam', () {
    testWidgets('page renders the injected controller and issues no real request', (
      tester,
    ) async {
      final api = await pumpHomePage(tester);

      expect(find.text('1-101'), findsOneWidget);
      expect(api.deviceListCalls, 1);
    });

    testWidgets('fake serves the empty list and the delete round-trip', (
      tester,
    ) async {
      final api = await pumpHomePage(tester, devices: const []);
      final controller = Get.find<HomeController>();

      expect(find.text('暂无设备'), findsOneWidget);
      expect(api.deviceListCalls, 1);

      // 删除走的是收藏开关接口：计数与参数都由替身记录，页面不许偷发真实请求。
      await controller.removeDevice(DeviceModel(id: '9', name: '9栋9'));
      await tester.pump();

      expect(api.toggleCalls, 1);
      expect(api.lastToggleDeviceId, '9');
      expect(api.lastToggleIsRemove, isTrue);
      expect(controller.deviceList, isEmpty);
      await dismissSnack(tester);
    });
  });

  group('in-flight state', () {
    testWidgets('the loading screen survives until the list actually arrives', (
      tester,
    ) async {
      final api = HangingDeviceListApiService();
      await pumpHomePage(tester, api: api);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      api.release();
      await tester.pump(const Duration(milliseconds: 900));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('refresh while a request is in flight starts no second one', (
      tester,
    ) async {
      final api = HangingDeviceListApiService();
      await pumpHomePage(tester, api: api);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byTooltip('刷新'));
      await tester.pump();

      // 回归点：在途时再点刷新会并发第二条请求，两条结果谁后到谁覆盖列表。
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(api.deviceListCalls, 1);

      api.release();
      await tester.pump(const Duration(milliseconds: 900));
    });
  });

  group('surface layer', () {
    testWidgets('idle page anchors the top instead of one flat fill', (tester) async {
      await pumpHomePage(tester);

      // 退化模式禁止：同色两端 = 没有层次的整块底。
      for (final d in paintedDecorations(tester)) {
        if (d.gradient case final LinearGradient g) {
          expect(
            Set.of(g.colors).length,
            greaterThan(1),
            reason: 'flat gradient ${g.colors.map((c) => c.toARGB32()).toList()}',
          );
        }
      }

      final base = pageBaseColor(tester);
      expect(
        base,
        isNot(AppTheme.lightTheme.scaffoldBackgroundColor),
        reason: '页面本体仍等于全局 #F5F9FF，卡片不可能浮起来',
      );
      // 顶部锚点：比本体更饱和的一层必须存在。
      expect(
        paintedGradientStops(tester).where((c) => luminance(c) < luminance(base)),
        isNotEmpty,
      );
    });

    testWidgets('resting card separates from the page by fill plus a second channel', (
      tester,
    ) async {
      await pumpHomePage(tester);

      final base = pageBaseColor(tester);
      final card = decorationAt(tester, statusCardKey);
      expect(
        contrast(surfaceColor(card), base),
        greaterThanOrEqualTo(1.15),
        reason: 'card fill too close to the page base',
      );
      final secondChannel =
          card.border != null || (card.boxShadow?.isNotEmpty ?? false);
      expect(secondChannel, isTrue, reason: 'no border or elevation on the card');
    });

    testWidgets('dark mode keeps the same separation', (tester) async {
      await pumpHomePage(tester, brightness: Brightness.dark);

      final base = pageBaseColor(tester);
      final card = decorationAt(tester, statusCardKey);
      expect(contrast(surfaceColor(card), base), greaterThanOrEqualTo(1.15));
      expect(card.border != null || (card.boxShadow?.isNotEmpty ?? false), isTrue);
    });

    testWidgets('selection changes two channels and never glues the tile back', (
      tester,
    ) async {
      await pumpHomePage(tester);
      final base = pageBaseColor(tester);

      final resting = decorationAt(tester, deviceTileKey('102'));
      final selected = decorationAt(tester, deviceTileKey('101'));

      var channels = 0;
      if (surfaceColor(resting) != surfaceColor(selected)) channels++;
      if (resting.border?.top.color != selected.border?.top.color ||
          resting.border?.top.width != selected.border?.top.width) {
        channels++;
      }
      Color? firstShadowColor(BoxDecoration d) =>
          (d.boxShadow?.isEmpty ?? true) ? null : d.boxShadow!.first.color;
      if (firstShadowColor(resting) != firstShadowColor(selected) ||
          (resting.boxShadow?.isEmpty ?? true) !=
              (selected.boxShadow?.isEmpty ?? true)) {
        channels++;
      }
      expect(
        find.descendant(
          of: find.byKey(deviceTileKey('101')),
          matching: find.byIcon(Ionicons.checkmark),
        ),
        findsOneWidget,
      );
      expect(channels, greaterThanOrEqualTo(2));
      expect(
        contrast(surfaceColor(selected), base),
        greaterThanOrEqualTo(1.15),
        reason: '选中态把卡片贴回背景，反而更糊',
      );
    });

    testWidgets('text on its own surface clears the contrast floors', (tester) async {
      await pumpHomePage(tester);
      final base = pageBaseColor(tester);
      final card = surfaceColor(decorationAt(tester, statusCardKey));

      expect(
        contrastOn(textColorIn(tester, statusCardKey, '选择设备开始接水'), card),
        greaterThanOrEqualTo(4.5),
      );
      // 标题必须比副标题更抢眼
      expect(
        contrastOn(textColorIn(tester, statusCardKey, '准备就绪'), card),
        greaterThan(
          contrastOn(textColorIn(tester, statusCardKey, '选择设备开始接水'), card),
        ),
      );

      // 落在页面本体上的次要文字（排序提示）同样要过 4.5
      final band = pageBandColor(tester);
      await tester.tap(find.byTooltip('调整顺序'));
      await tester.pump();
      expect(find.text('拖动调整顺序'), findsOneWidget);
      expect(
        contrastOnPageText(
          tester.widget<Text>(find.text('拖动调整顺序')).style!.color!,
          base,
          band,
        ),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(find.byTooltip('完成排序'));
      await tester.pump();

      // 三个次级入口的文字也压在本体色上：默认 primary 蓝只有 2.66:1。
      for (final label in ['我的设备', '添加', '管理设备', '扫码添加']) {
        expect(
          contrastOnPageText(effectiveTextColor(tester, label), base, band),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
      }
    });

    testWidgets('brand glyph on a tinted chip clears the 3.0 non-text floor', (
      tester,
    ) async {
      await pumpHomePage(tester);

      final chip = decorationAt(tester, statusIconChipKey);
      final icon = tester.widget<Icon>(
        find.descendant(of: find.byKey(statusIconChipKey), matching: find.byType(Icon)),
      );
      expect(
        contrast(icon.color ?? Colors.black, surfaceColor(chip)),
        greaterThanOrEqualTo(3.0),
      );
    });

    testWidgets('accent state stays readable at the lightest point of its gradient', (
      tester,
    ) async {
      await pumpHomePage(tester);
      Get.find<HomeController>().isDrinking.value = true;
      await tester.pump(const Duration(milliseconds: 900));

      final accent = decorationAt(tester, statusCardKey);
      expect(accent.gradient, isNotNull, reason: 'in-progress card lost its accent');
      final lightest = surfaceColor(accent); // 取最浅停靠
      expect(
        contrastOn(textColorIn(tester, statusCardKey, '正在接水中'), lightest),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastOn(textColorIn(tester, statusCardKey, '接完后点击结算'), lightest),
        greaterThanOrEqualTo(4.5),
      );
      // 旧的浅青 #00D4FF 不再承载任何文字
      expect(
        paintedGradientStops(tester).where((c) => c.toARGB32() == const Color(0xFF00D4FF).toARGB32()),
        isEmpty,
      );
    });
  });

  group('type scale', () {
    Future<double> sizeOf(WidgetTester tester, String text) async {
      final f = find.text(text);
      expect(f, findsOneWidget, reason: 'no "$text" on the page');
      return tester.widget<Text>(f).style!.fontSize!;
    }

    testWidgets('the page carries five distinct hierarchy levels', (tester) async {
      await pumpHomePage(tester);

      expect(await sizeOf(tester, '准备就绪'), 22.0);
      expect(await sizeOf(tester, '智能饮水'), 20.0);
      expect(await sizeOf(tester, '我的设备'), 17.0);
      expect(await sizeOf(tester, '1-101'), 15.0);
      expect(await sizeOf(tester, '选择设备开始接水'), 13.0);

      final sizes = {
        await sizeOf(tester, '准备就绪'),
        await sizeOf(tester, '智能饮水'),
        await sizeOf(tester, '我的设备'),
        await sizeOf(tester, '1-101'),
        await sizeOf(tester, '选择设备开始接水'),
      };
      expect(sizes.length, greaterThanOrEqualTo(4));
      expect(
        tester.widget<Text>(find.text('准备就绪')).style!.fontWeight,
        FontWeight.w700,
      );
    });
  });

  group('device tiles', () {
    testWidgets('touch targets stay at or above the recorded baseline', (
      tester,
    ) async {
      await pumpHomePage(tester);

      // 基线来自改版前的实现，不是抄新代码的量出来的：
      // 行内容高 36 + 纵向 padding 10×2 + 描边（选中 2.0×2 / 常态 0.5×2）
      // ⇒ 选中 60.0、常态 57.0；备注按钮 6+14+6 = 26；工具栏 IconButton 40×40。
      expect(tester.getRect(find.byKey(deviceTileKey('101'))).height,
          greaterThanOrEqualTo(60.0));
      expect(tester.getRect(find.byKey(deviceTileKey('102'))).height,
          greaterThanOrEqualTo(57.0));
      final edit = tester.getRect(find.byKey(deviceEditKey('101')));
      expect(edit.width, greaterThanOrEqualTo(26.0));
      expect(edit.height, greaterThanOrEqualTo(26.0));
      for (final tip in ['刷新', '双列布局', '调整顺序']) {
        final r = tester.getRect(find.byTooltip(tip));
        expect(r.width, greaterThanOrEqualTo(40.0), reason: tip);
        expect(r.height, greaterThanOrEqualTo(40.0), reason: tip);
      }
      // 主按钮的 key 在 group 5 落地；这里先按 widget 类型量，避免把基线绑到未来改动上。
      expect(tester.getRect(find.byType(FilledButton).last).height,
          greaterThanOrEqualTo(64.0));
    });

    testWidgets('grid layout expresses the same selection language', (tester) async {
      await pumpHomePage(tester);

      await tester.tap(find.byTooltip('双列布局'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final base = pageBaseColor(tester);
      final selected = decorationAt(tester, deviceTileKey('101'));
      final resting = decorationAt(tester, deviceTileKey('102'));
      expect(selected.border!.top.width > resting.border!.top.width, isTrue);
      expect(contrast(surfaceColor(selected), base),
          greaterThanOrEqualTo(1.15));
      expect(
        find.descendant(
          of: find.byKey(deviceTileKey('101')),
          matching: find.byIcon(Ionicons.checkmark_circle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('reorder mode keeps handles and the selected device', (
      tester,
    ) async {
      await pumpHomePage(tester);
      final controller = Get.find<HomeController>();
      controller.selectDevice(1);
      expect(controller.currentDevice!.id, '102');

      await tester.tap(find.byTooltip('调整顺序'));
      await tester.pump();
      expect(find.text('拖动调整顺序'), findsOneWidget);
      expect(find.byIcon(Ionicons.menu_outline), findsNWidgets(2));

      controller.reorderDevices(0, 2);
      await tester.pump();
      expect(controller.currentDevice!.id, '102');

      await tester.tap(find.byTooltip('完成排序'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('拖动调整顺序'), findsNothing);
      expect(find.byIcon(Ionicons.menu_outline), findsNothing);
    });

    testWidgets('empty state survives a small screen at large text scale', (
      tester,
    ) async {
      await pumpHomePage(
        tester,
        devices: const [],
        size: const Size(320, 568),
        textScale: 1.3,
      );

      expect(find.text('暂无设备'), findsOneWidget);
      // 底部入口也是"扫码添加"，所以按 key 只认空状态卡片里那个实色按钮。
      _expectSolidActionLegible(tester, key: emptyScanActionKey);
      expect(tester.takeException(), isNull, reason: '小屏 + 大字号溢出');
    });

    testWidgets('device list survives a small screen at large text scale', (
      tester,
    ) async {
      await pumpHomePage(
        tester,
        size: const Size(320, 568),
        textScale: 1.3,
      );

      expect(tester.takeException(), isNull, reason: '小屏 + 大字号溢出');
      expect(find.byKey(deviceTileKey('101')), findsOneWidget);
      expect(
        tester.getRect(find.byType(FilledButton).last).height,
        greaterThanOrEqualTo(56.0),
      );
      // 主操作、布局切换、添加入口都还得点得到
      expect(find.byTooltip('双列布局'), findsOneWidget);
      expect(find.text('添加'), findsOneWidget);
    });
  });

  group('primary action', () {
    FilledButton actionButton(WidgetTester tester) => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(primaryActionKey),
        matching: find.byType(FilledButton),
      ),
    );

    testWidgets('enabled action is the focal control and its label clears 4.5', (
      tester,
    ) async {
      await pumpHomePage(tester);

      final wrapper = decorationAt(tester, primaryActionKey);
      expect(wrapper.gradient, isNotNull, reason: '主操作丢了品牌渐变');
      expect(
        contrastOn(
          textColorIn(tester, primaryActionKey, '开始接水'),
          surfaceColor(wrapper),
        ),
        greaterThanOrEqualTo(4.5),
        reason: '白色标签压在渐变最浅一端仍要过 4.5',
      );

      final rect = tester.getRect(find.byKey(primaryActionKey));
      expect(rect.height, greaterThanOrEqualTo(64.0));
      expect(rect.width, greaterThanOrEqualTo(320.0), reason: '主操作必须占满一行');
    });

    testWidgets('unselected device leaves the action inactive and untappable', (
      tester,
    ) async {
      final api = await pumpHomePage(tester);
      Get.find<HomeController>().selectedDeviceIndex.value = -1;
      await tester.pump();

      expect(actionButton(tester).onPressed, isNull);
      final wrapper = decorationAt(tester, primaryActionKey);
      expect(wrapper.gradient, isNull, reason: '不可用态不该有品牌渐变');
      expect(
        surfaceColor(wrapper),
        isNot(AppTheme.primaryColor),
        reason: '不可用态仍穿着可用色的皮，看不出能不能点',
      );

      await tester.tap(find.byKey(primaryActionKey));
      await tester.pump();
      expect(api.startCalls, 0);
    });

    testWidgets('settle state keeps its label readable', (tester) async {
      await pumpHomePage(tester);
      Get.find<HomeController>().isDrinking.value = true;
      await tester.pump(const Duration(milliseconds: 900));

      final wrapper = decorationAt(tester, primaryActionKey);
      expect(
        contrastOn(
          textColorIn(tester, primaryActionKey, '结算'),
          surfaceColor(wrapper),
        ),
        greaterThanOrEqualTo(4.5),
      );
      // 旧的 Colors.orange 白字只有 2.16:1
      expect(
        surfaceColor(wrapper).toARGB32(),
        isNot(const Color(0xFFFFA000).toARGB32()),
      );
      expect(find.text('结算'), findsOneWidget);
    });

    testWidgets('tapping starts and settles through the injected service', (
      tester,
    ) async {
      final api = await pumpHomePage(tester);
      final controller = Get.find<HomeController>();

      await tester.tap(find.byKey(primaryActionKey));
      await tester.pump();
      expect(api.startCalls, 1);
      expect(controller.isDrinking.value, isTrue);

      await tester.tap(find.byKey(primaryActionKey));
      await tester.pump();
      expect(api.stopCalls, 1);
      expect(controller.isDrinking.value, isFalse);
      await dismissSnack(tester);
    });
  });

  group('sheets and dialogs', () {
    Future<void> closeOverlay(WidgetTester tester) async {
      await tester.tapAt(const Offset(200, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('device management sheet sits on its own surface role', (
      tester,
    ) async {
      await pumpHomePage(tester);
      await tester.tap(find.text('管理设备'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final sheet = find.byKey(deviceManageSheetKey);
      expect(sheet, findsOneWidget);
      expect(find.text('设备管理'), findsOneWidget);
      expect(find.byIcon(Ionicons.trash_outline), findsNWidgets(2));
      expect(find.text('添加新设备'), findsOneWidget);

      final base = pageBaseColor(tester);
      final material = tester.widget<Material>(sheet);
      expect(
        contrast(material.color!, base),
        greaterThanOrEqualTo(1.15),
        reason: '抽屉沿用全局 #F5F9FF，和新的本体色只差 1.06，浮不起来',
      );
      await closeOverlay(tester);
    });

    testWidgets('settings sheet keeps 关于 and 退出登录 on the same surface', (
      tester,
    ) async {
      await pumpHomePage(tester);
      await tester.tap(find.byTooltip('设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final sheet = find.byKey(settingsSheetKey);
      expect(sheet, findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
      final base = pageBaseColor(tester);
      expect(
        contrast(tester.widget<Material>(sheet).color!, base),
        greaterThanOrEqualTo(1.15),
      );

      await tester.tap(find.text('关于'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('惠生活798'), findsOneWidget);
      // AlertDialog 的底色来自 colorScheme.surface，也得换成抽屉面
      final dialogMaterial = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Material),
      );
      expect(
        contrast(tester.widget<Material>(dialogMaterial.last).color ?? base, base),
        greaterThanOrEqualTo(1.15),
        reason: '对话框仍是全局 #F5F9FF',
      );
      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await closeOverlay(tester);
    });

    testWidgets('delete still asks before removing a device', (tester) async {
      final api = await pumpHomePage(tester);
      await tester.tap(find.text('管理设备'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.byIcon(Ionicons.trash_outline).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('确认删除'), findsOneWidget);
      expect(api.toggleCalls, 0, reason: '没确认前不许发删除请求');

      await tester.tap(find.text('删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.toggleCalls, 1);
      expect(api.lastToggleIsRemove, isTrue);
      await dismissSnack(tester);
    });
  });

  group('interaction sweep', () {
    testWidgets('every entry the page had before is still reachable', (tester) async {
      final api = await pumpHomePage(tester);
      final controller = Get.find<HomeController>();

      // 1. 刷新：再发一次列表请求
      await tester.tap(find.byTooltip('刷新'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(api.deviceListCalls, 2);

      // 2. 选中另一台设备
      await tester.tap(find.byKey(deviceTileKey('102')));
      await tester.pump();
      expect(controller.currentDevice!.id, '102');

      // 3. 备注：长按条目打开编辑框并保存
      await tester.longPress(find.byKey(deviceTileKey('102')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('编辑备注 - 1-102'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '二楼水房');
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('二楼水房'), findsWidgets);
      await dismissSnack(tester);

      // 4. 布局切换
      await tester.tap(find.byTooltip('双列布局'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(controller.layoutMode.value, 'grid');

      // 5. 排序进出
      await tester.tap(find.byTooltip('调整顺序'));
      await tester.pump();
      expect(find.text('拖动调整顺序'), findsOneWidget);
      await tester.tap(find.byTooltip('完成排序'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 6. 接水与结算
      await tester.tap(find.byKey(primaryActionKey));
      await tester.pump();
      expect(api.startCalls, 1);
      await tester.tap(find.byKey(primaryActionKey));
      await tester.pump();
      expect(api.stopCalls, 1);
      await dismissSnack(tester);

      // 7. 设备管理抽屉
      await tester.tap(find.text('管理设备'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byKey(deviceManageSheetKey), findsOneWidget);
      await tester.tapAt(const Offset(200, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // 8. 设置 → 退出登录：确认框出现，取消后不登出
      await tester.tap(find.byTooltip('设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('退出登录'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('确认退出'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 9. 页面上没有任何未捕获异常
      expect(tester.takeException(), isNull);
    });

    testWidgets('selection border and dialog link clear their own floors', (
      tester,
    ) async {
      await pumpHomePage(tester);
      final base = pageBaseColor(tester);

      // 选中描边是非文字元素，底线 3.0：primary 蓝压在本体色上只有 2.66。
      final selected = decorationAt(tester, deviceTileKey('101'));
      expect(
        contrast(selected.border!.top.color, base),
        greaterThanOrEqualTo(3.0),
      );

      await tester.tap(find.byTooltip('设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.text('关于'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final dialogColor = surfaceBehind(tester, 'GitHub 开源地址');
      expect(
        contrastOn(effectiveTextColor(tester, 'GitHub 开源地址'), dialogColor),
        greaterThanOrEqualTo(4.5),
        reason: '对话框里的链接仍是 primary 蓝，只有 3.13:1',
      );
      expect(
        contrast(
          tester.widget<Icon>(
            find.descendant(
              of: find.byKey(aboutAppIconKey),
              matching: find.byType(Icon),
            ),
          ).color!,
          dialogColor,
        ),
        greaterThanOrEqualTo(3.0),
      );

      await tester.tap(find.text('确定'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 设备管理抽屉里的实色按钮：主题给的 primary 底配白字只有 3.13:1。
      await tester.tap(find.text('管理设备'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      _expectSolidActionLegible(tester, label: '添加新设备');
      await tester.tapAt(const Offset(200, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // 设置抽屉里的危险文字也要过 4.5，然后走一遍退出确认的取消分支。
      await tester.tap(find.byTooltip('设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        contrastOn(
          effectiveTextColor(tester, '退出登录'),
          tester.widget<Material>(find.byKey(settingsSheetKey)).color!,
        ),
        greaterThanOrEqualTo(4.5),
        reason: 'Colors.red 压在卡片白上只有 3.72:1',
      );
      await tester.tap(find.text('退出登录'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('确认退出'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 备注编辑对话框的"保存"。
      await tester.longPress(find.byKey(deviceTileKey('101')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      _expectSolidActionLegible(tester, label: '保存');
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });
  });

  group('states and dark mode', () {
    testWidgets('in-progress background and bubbles survive the new palette', (
      tester,
    ) async {
      await pumpHomePage(tester);
      Get.find<HomeController>().isDrinking.value = true;
      await tester.pump();  // 先建出 _BubbleAnimation，它的气泡计时器在这一帧才创建
      await tester.pump(const Duration(milliseconds: 900));

      // 接水中的水色走 AnimatedContainer 的 foregroundDecoration，
      // decorationOf 只看 decoration，这里单独取证。
      final bg = tester.widget<AnimatedContainer>(find.byKey(homeBackgroundKey));
      final active = bg.foregroundDecoration;
      expect(active, isA<BoxDecoration>(), reason: '接水中背景没换成水色层');
      final stops = (active! as BoxDecoration).gradient! as LinearGradient;
      expect(
        stops.colors.last,
        pageBaseColor(tester),
        reason: '水色层收口必须落在本体色上，否则底部出现硬边',
      );

      final circles = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle)
          .length;
      expect(circles, greaterThan(0), reason: '接水中的气泡丢了');

      // 强调面上的图标底是 white@0.18，压平到底色再算，不能当纯白。
      final chip = decorationAt(tester, statusIconChipKey);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(statusIconChipKey),
          matching: find.byType(Icon),
        ),
      );
      final accentFace = surfaceColor(decorationAt(tester, statusCardKey));
      expect(
        contrastOn(icon.color!, chip.color!, backdrop: accentFace),
        greaterThanOrEqualTo(3.0),
      );
    });

    testWidgets('the disabled action paints nothing of its own', (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await pumpHomePage(tester, brightness: brightness);
        Get.find<HomeController>().selectedDeviceIndex.value = -1;
        await tester.pump();

        final btn = tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(primaryActionKey),
            matching: find.byType(FilledButton),
          ),
        );
        // M3 默认会给禁用态铺一层 onSurface@0.12，正好盖掉 token 的中性底。
        for (final states in [
          const <WidgetState>{},
          const <WidgetState>{WidgetState.disabled},
        ]) {
          expect(
            btn.style?.backgroundColor?.resolve(states)?.a ?? 1.0,
            0.0,
            reason: '$brightness / $states 下按钮自己铺了底色',
          );
        }

        final wrapper = decorationAt(tester, primaryActionKey);
        expect(wrapper.gradient, isNull);
        expect(
          contrastOn(
            textColorIn(tester, primaryActionKey, '开始接水'),
            wrapper.color!,
            backdrop: pageBaseColor(tester),
          ),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness 不可用态的标签仍要读得出',
        );
        Get.reset();
      }
    });

    testWidgets('dark mode carries the same floors for tiles, sheets and glyphs', (
      tester,
    ) async {
      await pumpHomePage(tester, brightness: Brightness.dark);
      final base = pageBaseColor(tester);

      final resting = decorationAt(tester, deviceTileKey('102'));
      final selected = decorationAt(tester, deviceTileKey('101'));
      expect(
        contrast(surfaceColor(selected), surfaceColor(resting)),
        greaterThanOrEqualTo(1.05),
        reason: '深色选中靠提亮，这一档必须真的看得见',
      );

      final chip = iconChipOf(tester, '101');
      expect(
        contrast(surfaceColor(chip), surfaceColor(selected)),
        greaterThanOrEqualTo(1.05),
        reason: '图标底与条目底色撞成同一块，图标就糊进背景了',
      );

      for (final tip in ['刷新', '双列布局', '调整顺序']) {
        final icon = tester.widget<Icon>(
          find.descendant(of: find.byTooltip(tip), matching: find.byType(Icon)),
        );
        expect(
          contrastOnPageText(icon.color!, base, pageBandColor(tester)),
          greaterThanOrEqualTo(3.0),
          reason: tip,
        );
      }

      await tester.tap(find.text('管理设备'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final manage = tester.widget<Material>(find.byKey(deviceManageSheetKey));
      expect(contrast(manage.color!, base), greaterThanOrEqualTo(1.15));
      await tester.tapAt(const Offset(200, 60));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.byTooltip('设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final sheet = tester.widget<Material>(find.byKey(settingsSheetKey));
      expect(
        contrastOn(effectiveTextColor(tester, '退出登录'), sheet.color!),
        greaterThanOrEqualTo(4.5),
        reason: '深色里危险文字要用亮一档的红，暗红会沉进背景',
      );
    });

    testWidgets('a reload requested while in flight is coalesced, not dropped', (
      tester,
    ) async {
      final api = HangingDeviceListApiService();
      await pumpHomePage(tester, api: api);

      await tester.tap(find.byTooltip('刷新'));
      await tester.pump();
      expect(api.deviceListCalls, 1, reason: '在途时不该再发一条');

      api.release();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      // 被排队的那次必须补跑，否则扫码添加回来的新设备永远不上屏。
      expect(api.deviceListCalls, 2);
    });
  });
}

/// 断言页面上的实色操作按钮：自带底色 token（不落回主题的 primary 底，
/// 那里白字只有 3.13:1），且标签相对该底色过 4.5:1。
///
/// `FilledButton.icon` 的实际 runtime type 是私有子类，`find.byType(FilledButton)`
/// 认不出它，所以按 `is FilledButton` 谓词找。
void _expectSolidActionLegible(WidgetTester tester, {Key? key, String? label}) {
  final Finder action = key != null
      ? find.byKey(key)
      : find.ancestor(
          of: find.text(label!),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        );
  expect(action, findsOneWidget, reason: '$label$key');
  final btn = tester.widget<FilledButton>(action);
  final bg = btn.style?.backgroundColor?.resolve(const <WidgetState>{});
  expect(bg, isNotNull, reason: '$label 仍在用主题的 primary 底');
  expect(
    contrastOn(
      textColorAt(
        tester,
        find.descendant(of: action, matching: find.byType(Text)).last,
      ),
      bg!,
    ),
    greaterThanOrEqualTo(4.5),
    reason: '$label 的标签色压在自己的底上不达标',
  );
}

/// 取条目里那块图标底（非圆形、带颜色与圆角的那个容器）。
BoxDecoration iconChipOf(WidgetTester tester, String id) {
  final tile = find.byKey(deviceTileKey(id));
  for (final c in tester.widgetList<Container>(
    find.descendant(of: tile, matching: find.byType(Container)),
  )) {
    final d = c.decoration;
    if (d is BoxDecoration && d.shape != BoxShape.circle && d.color != null) {
      return d;
    }
  }
  throw StateError('no icon chip inside tile $id');
}
