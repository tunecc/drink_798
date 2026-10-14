import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drink_water_app/core/models/device_model.dart';
import 'package:drink_water_app/core/services/drink_api_service.dart';
import 'package:drink_water_app/core/theme/app_theme.dart';
import 'package:drink_water_app/features/home/home_controller.dart';
import 'package:drink_water_app/features/home/home_page.dart';
import 'package:drink_water_app/features/home/home_prompt_colors.dart';
import 'package:drink_water_app/features/scanner/scanner_page.dart';

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

/// 渐变面里离 `base` 最近的那一档。
///
/// 白色文字压在渐变上要用最浅端算（最不利），但两块面**分不分得开**要反过来，
/// 按离对方最近的那端算 —— 取最浅端等于永远在比最好的情况。
Color closestStop(BoxDecoration d, Color base) {
  if (d.color case final c?) return c;
  final lb = luminance(base);
  return (d.gradient! as LinearGradient).colors.reduce(
    (a, b) => (luminance(a) - lb).abs() <= (luminance(b) - lb).abs() ? a : b,
  );
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

/// 渐变在归一化位置 t 上的实际绘制色（stops 缺省按均匀分布）。
Color sampleGradient(LinearGradient g, double t) {
  final stops = g.stops ??
      List.generate(g.colors.length, (i) => i / (g.colors.length - 1));
  for (var i = 0; i < stops.length - 1; i++) {
    if (t <= stops[i + 1]) {
      final local = (t - stops[i]) / (stops[i + 1] - stops[i]);
      return Color.lerp(g.colors[i], g.colors[i + 1], local.clamp(0.0, 1.0))!;
    }
  }
  return g.colors.last;
}

/// 某个绘制位置身后那段页面底色，按 Finder 取，便于量没有 key 的对话框面。
Color backgroundAt(WidgetTester tester, Finder target) {
  final d = decorationAt(tester, homeBackgroundKey);
  final bg = tester.getRect(find.byKey(homeBackgroundKey));
  final dy = tester.getRect(target).center.dy;
  return sampleGradient(
    d.gradient! as LinearGradient,
    ((dy - bg.top) / bg.height).clamp(0.0, 1.0),
  );
}

/// 抬升面的圆角半径。
///
/// AlertDialog 的圆角走 `Material.shape`，抽屉那种手搭的 Material 走
/// `borderRadius`，只读后者会把已经画出来的圆角判成 0。
double cornerRadius(Material m) {
  final s = m.shape;
  if (s is RoundedRectangleBorder && s.borderRadius is BorderRadius) {
    return (s.borderRadius as BorderRadius).topLeft.x;
  }
  final r = m.borderRadius;
  if (r is BorderRadius) return r.topLeft.x;
  return 0.0;
}

/// 抽屉、对话框这类用 Material 直接画出来的抬升面，`channelsOf` 认不到（它只读
/// BoxDecoration），所以给它同一把尺子的三个可测项：离页面本色的档位、
/// 圆角顶边、以及身后页面确实被压暗或盖住。按面上任一段文字定位，
/// 对话框没有 key。
void expectElevatedSurface(WidgetTester tester, String onSurface) {
  // textContaining 而不是 text：这一行带着版本号，用前缀定位的话，每次发版都要
  // 顺手改测试；只认「版本:」就能一直测下去。
  final label = find.textContaining(onSurface);
  Material? face;
  tester.element(label).visitAncestorElements((e) {
    final w = e.widget;
    if (w is Material && (w.color?.a ?? 0) >= 0.99) {
      face = w;
      return false;
    }
    return true;
  });
  final m = face;
  if (m == null) throw StateError('no opaque surface behind "$onSurface"');
  expect(
    contrast(m.color!, backgroundAt(tester, label)),
    greaterThanOrEqualTo(1.15),
    reason: '$onSurface 所在的面离它盖住的页面底色分不开',
  );
  final radius = cornerRadius(m);
  expect(radius, greaterThan(0.0), reason: '$onSurface 所在的面没有圆角边');
  expect(
    tester
        .widgetList<ModalBarrier>(find.byType(ModalBarrier))
        .any((b) => (b.color?.a ?? 0) > 0),
    isTrue,
    reason: '$onSurface 身后的页面没被压暗，像是同层的一部分',
  );
}

/// 某个 key 真正压在的那块页面底色。
///
/// 背景是 topCenter→bottomCenter 的三段渐变，本体色只出现在最底端；
/// 用 pageBaseColor 当卡片的背景等于宣称上半屏那条品牌带不存在，
/// 而状态卡恰恰就落在带上。
Color backgroundBehind(WidgetTester tester, Key key) =>
    backgroundAt(tester, find.byKey(key));

/// 三个分离通道里哪些是真的：填充档位、看得见的描边、真实的投影。
///
/// "border != null" 不是通道 —— 描边色合成后和身后的面几乎同亮度时，
/// 它画了等于没画；投影同理，全透明或 blur/offset 都是零就不算抬升。
({bool fill, bool border, bool elevation}) channelsOf(
  WidgetTester tester,
  Key key, {
  Color? behind,
}) {
  final d = decorationAt(tester, key);
  final base = behind ?? backgroundBehind(tester, key);
  final line = d.border?.top;
  return (
    fill: contrast(closestStop(d, base), base) >= 1.15,
    border: line != null &&
        line.color.a > 0 &&
        contrast(composite(line.color, base), base) >= 1.15,
    // 一层 7% 的投影肉眼看不出抬升，不能算通道：既要有实际扩散与偏移，
    // 也要它在身后那块面上真的落下一点痕迹。
    elevation: (d.boxShadow ?? []).any(
      (s) =>
          s.color.a >= 0.12 &&
          s.blurRadius > 0 &&
          s.offset != const Offset(0, 0) &&
          contrast(composite(s.color, base), base) >= 1.05,
    ),
  );
}

int channelCount({bool fill = false, bool border = false, bool elevation = false}) =>
    [fill, border, elevation].where((c) => c).length;

String _channelText(({bool fill, bool border, bool elevation}) c) =>
    'fill=${c.fill} border=${c.border} elevation=${c.elevation}';

/// 文字真正吃到的那块"面"：**最内层**的不透明 Material。
///
/// 只认 MaterialType.card 会把实色按钮的底算成它身后那块面；按不透明度筛才对。
/// 注意 M3 的 FilledButton 底色并不落在祖先 Material 上（它由 ButtonStyle 自己绘制），
/// 所以实色按钮的标签要用 `_expectSolidActionLegible` 读 `style.backgroundColor`。
/// 这里沿 `visitAncestorElements` 从近往远走，第一个不透明命中就停，
/// 不依赖 Finder 的返回顺序。
Color surfaceBehind(WidgetTester tester, String text) {
  Color? found;
  tester.element(find.text(text)).visitAncestorElements((e) {
    final w = e.widget;
    if (w is Material && (w.color?.a ?? 0) >= 0.99) {
      found = w.color;
      return false;
    }
    return true;
  });
  if (found case final c?) return c;
  throw StateError('no opaque surface behind "$text"');
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

      final behind = backgroundBehind(tester, statusCardKey);
      final card = decorationAt(tester, statusCardKey);
      final c = channelsOf(tester, statusCardKey);
      expect(
        c.fill,
        isTrue,
        reason: '卡片填充离它真正压着的那段渐变不足 1.15',
      );
      expect(
        channelCount(fill: c.fill, border: c.border, elevation: c.elevation),
        greaterThanOrEqualTo(2),
        reason: '单靠填充不满足分离要求：${_channelText(c)}',
      );
      expect(
        contrast(surfaceColor(card), behind),
        greaterThanOrEqualTo(1.15),
      );
    });

    testWidgets('dark mode keeps the same separation', (tester) async {
      await pumpHomePage(tester, brightness: Brightness.dark);

      // 状态卡落在顶部品牌带上，比的是带而不是本体色。
      final c = channelsOf(tester, statusCardKey);
      expect(
        c.fill,
        isTrue,
        reason: '深色卡片压在本体色上勉强够，压到品牌带上就糊成一片',
      );
      expect(
        channelCount(fill: c.fill, border: c.border, elevation: c.elevation),
        greaterThanOrEqualTo(2),
        reason: _channelText(c),
      );

      final tile = channelsOf(tester, deviceTileKey('102'));
      expect(
        channelCount(
          fill: tile.fill,
          border: tile.border,
          elevation: tile.elevation,
        ),
        greaterThanOrEqualTo(2),
        reason: '深色设备项 ${_channelText(tile)}',
      );
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
      // 标题压过副标题靠字号与字重，不靠对比度：两条都读得出时对比度差毫无意义。
      Text textStyleOf(String s) => tester.widget<Text>(
        find.descendant(of: find.byKey(statusCardKey), matching: find.text(s)),
      );
      final head = textStyleOf('准备就绪').style!;
      final caption = textStyleOf('选择设备开始接水').style!;
      final headRank =
          (head.fontSize ?? 0) * 100 + (head.fontWeight?.index ?? 0);
      final captionRank =
          (caption.fontSize ?? 0) * 100 + (caption.fontWeight?.index ?? 0);
      expect(
        headRank,
        greaterThan(captionRank),
        reason: '状态卡标题没有靠字号或字重压过副标题',
      );

      // 排序提示条现在是品牌色面，文字压在自己的最浅停靠点上算，不再比页面底色
      await tester.tap(find.byTooltip('调整顺序'));
      await tester.pump();
      expect(find.text('拖动调整顺序'), findsOneWidget);
      expect(
        contrastOn(
          tester.widget<Text>(find.text('拖动调整顺序')).style!.color!,
          surfaceColor(decorationAt(tester, reorderHintKey)),
        ),
        greaterThanOrEqualTo(4.5),
      );
      await tester.tap(find.byTooltip('完成排序'));
      await tester.pump();

      final band = pageBandColor(tester);

      // 三个次级入口的文字也压在本体色上：默认 primary 蓝只有 2.66:1。
      for (final label in ['我的设备', '添加', '管理设备', '扫码添加']) {
        expect(
          contrastOnPageText(effectiveTextColor(tester, label), base, band),
          greaterThanOrEqualTo(4.5),
          reason: label,
        );
      }

      // 规格那句 "headings MUST reach at least 3:1" 点名的是标题档，之前只枚举了
      // 正文与次级文字。页面上站得住的两个标题是状态卡标题和页面主标题，逐个补进
      // 这份枚举 —— 我们的验收口径就是"枚举即契约"，漏一行等于没这条。
      expect(
        contrastOn(textColorIn(tester, statusCardKey, '准备就绪'), card),
        greaterThanOrEqualTo(3.0),
        reason: '状态卡标题达不到标题档的 3.0 下限',
      );
      expect(
        contrastOnPageText(effectiveTextColor(tester, '智能饮水'), base, band),
        greaterThanOrEqualTo(3.0),
        reason: '页面主标题达不到标题档的 3.0 下限',
      );
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
      // 五个层级逐个钉死就是 D8 的字号常量，"层级互不相同"由这五个值本身保证，
      // 不需要再套一句永远成立的集合大小检查。
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

      // 基线：Container 的 BoxDecoration.border 画在盒子内部，不给布局加高度，
      // 所以改版前条目实际是 36 内容 + 10×2 padding = 56。这里的 60.0 / 57.0 是
      // 改版后量出来的值，比"不得缩小"的底线更严，不是从旧几何推出来的。
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

      // 规格那句"两种布局都保持条目状态"里含交互：点条目仍选中、长按仍开备注框。
      // 整轮回归只在单列里走过这两步，双列的处理器此前没人碰过。
      await tester.tap(find.byKey(deviceTileKey('102')));
      await tester.pump();
      expect(Get.find<HomeController>().currentDevice!.id, '102');
      expect(
        find.descendant(
          of: find.byKey(deviceTileKey('102')),
          matching: find.byIcon(Ionicons.checkmark_circle),
        ),
        findsOneWidget,
        reason: '双列里选中的条目没换上同一套选中表达',
      );

      await tester.longPress(find.byKey(deviceTileKey('102')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        find.text('编辑备注 - 1-102'),
        findsOneWidget,
        reason: '双列里长按打不开备注编辑器',
      );
      await tester.tap(find.text('取消'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
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
      // 主操作、布局切换、添加入口都还得点得到 —— "在树上"不算点得到，
      // 必须整块落在 320x568 视口内，并且真按一次能生效。
      final view = const Rect.fromLTWH(0, 0, 320, 568);
      for (final key in [primaryActionKey, layoutToggleKey]) {
        final rect = tester.getRect(find.byKey(key));
        expect(view.contains(rect.center), isTrue, reason: '$key 跑出了视口');
      }
      await tester.tap(find.byKey(layoutToggleKey));
      await tester.pump();
      expect(Get.find<HomeController>().layoutMode.value, 'grid');

      await tester.tap(find.byKey(layoutToggleKey));
      await tester.pump();
      expect(find.text('添加'), findsOneWidget);
      final addRect = tester.getRect(find.text('添加'));
      expect(
        view.contains(addRect.center),
        isTrue,
        reason: '添加入口在小屏上被挤出了可视区',
      );
      // 只量矩形还算不上"点得到"。真按一次之前把绘制尺寸放回常态：
      // 扫码页自己在 320 宽 + 1.3 字号下横向溢出 12px（`scanner_page.dart:108`，
      // 改版前就存在，不在本次边界内），不该让它替首页背一条异常。
      // 首页侧的"小屏可点"由上面两条视口内断言负责。
      await tester.binding.setSurfaceSize(const Size(400, 900));
      await tester.pump();
      await tester.tap(find.text('添加'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(ScannerPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      // 这个 app 用 Material 的返回键，tester.pageBack() 找的是 iOS 那条。
      Navigator.of(tester.element(find.byType(ScannerPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
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

      // Requirement 4 的 *Device selected* 条款点名了播放图标，之前没人认它。
      expect(
        find.descendant(
          of: find.byKey(primaryActionKey),
          matching: find.byIcon(Ionicons.play_circle),
        ),
        findsOneWidget,
        reason: '可用态主操作少了规格点名的播放图标',
      );
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
      // 旧的 Colors.orange（#FF9800）白字只有 2.16:1
      expect(
        surfaceColor(wrapper).toARGB32(),
        isNot(const Color(0xFFFF9800).toARGB32()),
      );
      expect(find.text('结算'), findsOneWidget);
      // 同一个控件切到结算态要连图标一起切，规格那句"switches to the settle
      // state"讲的就是这一整组表达。
      expect(
        find.descendant(
          of: find.byKey(primaryActionKey),
          matching: find.byIcon(Ionicons.stop_circle),
        ),
        findsOneWidget,
        reason: '结算态没有换上自己的图标',
      );
      expect(
        find.descendant(
          of: find.byKey(primaryActionKey),
          matching: find.byIcon(Ionicons.play_circle),
        ),
        findsNothing,
        reason: '结算态仍挂着播放图标，切换没有真的发生',
      );
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
        reason: '抽屉沿用全局 #F5F9FF，离新本体色只有 1.111，浮不起来',
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
        reason: '对话框里的链接仍是 primary 蓝，只有 3.12:1',
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

      // 设备管理抽屉里的实色按钮：主题给的 primary 底配白字只有 3.12:1。
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
        reason: 'Colors.red 压在卡片白上只有 3.68:1',
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

      // 标题档的 3.0 在深色里也要过：规格那句 "no text pair falls below the contrast
      // floor above" 不带模式限定词，浅色补过的两条枚举这里同样得有一条。
      expect(
        contrastOn(
          textColorIn(tester, statusCardKey, '准备就绪'),
          surfaceColor(decorationAt(tester, statusCardKey)),
        ),
        greaterThanOrEqualTo(3.0),
        reason: '深色状态卡标题达不到标题档的 3.0 下限',
      );
      expect(
        contrastOnPageText(
          effectiveTextColor(tester, '智能饮水'),
          base,
          pageBandColor(tester),
        ),
        greaterThanOrEqualTo(3.0),
        reason: '深色页面主标题达不到标题档的 3.0 下限',
      );

      final resting = decorationAt(tester, deviceTileKey('102'));
      final selected = decorationAt(tester, deviceTileKey('101'));
      expect(
        contrast(surfaceColor(selected), surfaceColor(resting)),
        greaterThanOrEqualTo(1.15),
        reason: '深色选中靠提亮，但 1.15 才是相邻表面的底线',
      );

      final chip = iconChipOf(tester, '101');
      expect(
        contrast(surfaceColor(chip), surfaceColor(selected)),
        greaterThanOrEqualTo(1.15),
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

    testWidgets('an expired session leaves no queued reload behind', (
      tester,
    ) async {
      final api = HangingDeviceListApiService(
        devices: const [{'id': '0', 'name': '登录已过期'}],
      );
      await pumpHomePage(tester, api: api);

      // GetX 的 snackbar 队列有节流，条与条之间会隔帧，固定泵两轮不一定排空；
      // 这里按"还在就继续排"循环，否则残留守布会把 Ticker 泄漏到下一个测试。
      Future<void> drain() async {
        for (var i = 0; i < 6 && find.byType(GetSnackBar).evaluate().isNotEmpty; i++) {
          await tester.pump(const Duration(seconds: 5));
          await tester.pump(const Duration(milliseconds: 900));
        }
      }

      final controller = Get.find<HomeController>();
      // 初次加载仍在途，这一次只排队，不发请求。
      unawaited(controller.loadDevices());
      await tester.pump();
      expect(api.deviceListCalls, 1, reason: '在途时不该并发第二条');

      api.release();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await drain();
      expect(api.deviceListCalls, 1, reason: '过期分支跳登录页，不该顺手补跑队列');

      // 回到首页后重新加载：队列标记必须已经清掉，只发这一条。
      await controller.loadDevices();
      await tester.pump();
      expect(api.deviceListCalls, 2, reason: '过期分支残留了排队标记');
      await drain();
      expect(find.byType(GetSnackBar), findsNothing);
    });
  });

  group('round 2 regressions', () {
    testWidgets('note edit chip is a separate surface from the tile it sits in', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);

        final tile = surfaceColor(decorationAt(tester, deviceTileKey('102')));
        final chip = decorationAt(tester, deviceEditKey('102'));
        expect(
          contrast(surfaceColor(chip), tile),
          greaterThanOrEqualTo(1.15),
          reason:
              '$brightness 备注编辑按钮和条目同色，只剩一条 1px 描边撑着，看不出那是个可点的东西',
        );
      }
    });

    testWidgets('selection marker clears 3.0 against the tile and 4.5 for its glyph', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);

        final marker = decorationAt(tester, deviceCheckMarkerKey('101'));
        final tile = surfaceColor(decorationAt(tester, deviceTileKey('101')));
        expect(
          contrast(surfaceColor(marker), tile),
          greaterThanOrEqualTo(3.0),
          reason: '$brightness 角标本身在选中条目上不成形',
        );
        expect(
          contrastOn(
            tester
                .widget<Icon>(
                  find.descendant(
                    of: find.byKey(deviceCheckMarkerKey('101')),
                    matching: find.byType(Icon),
                  ),
                )
                .color!,
            surfaceColor(marker),
          ),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness 勾在角标上读不出来',
        );
      }
    });

    testWidgets('reorder hint sits on a surface distinct from normal browsing', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        await tester.tap(find.byTooltip('调整顺序'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final hint = decorationAt(tester, reorderHintKey);
        final behind = backgroundBehind(tester, reorderHintKey);
        final tile = surfaceColor(decorationAt(tester, deviceTileKey('101')));
        // 提示条是渐变面，分离度必须按离底色最近的那一档算，取最浅端是在比最好的情况。
        expect(
          contrast(closestStop(hint, behind), behind),
          greaterThanOrEqualTo(1.15),
          reason: '$brightness 提示面和页面底色分不开',
        );
        expect(
          contrast(closestStop(hint, tile), tile),
          greaterThanOrEqualTo(1.15),
          reason: '$brightness 提示面和静止条目同色，就等于浏览态本身',
        );
        final c = channelsOf(tester, reorderHintKey, behind: behind);
        expect(
          channelCount(fill: c.fill, border: c.border, elevation: c.elevation),
          greaterThanOrEqualTo(2),
          reason: '$brightness 提示条 ${_channelText(c)}',
        );
      }
    });

    testWidgets('selection still reads after the hue is stripped away', (
      tester,
    ) async {
      await pumpHomePage(tester);

      final resting = decorationAt(tester, deviceTileKey('102'));
      final selected = decorationAt(tester, deviceTileKey('101'));
      final base = backgroundBehind(tester, deviceTileKey('102'));
      // 灰度渲染只保留亮度：色相不同（淡蓝描边 vs 品牌蓝描边）在这里不算数。
      var gray = 0;
      if ((luminance(surfaceColor(resting)) - luminance(surfaceColor(selected)))
          .abs() >
          0.0005) {
        gray++;
      }
      double lineStrength(BoxDecoration d) =>
          contrast(composite(d.border!.top.color, base), base) *
          d.border!.top.width;
      if ((lineStrength(resting) - lineStrength(selected)).abs() >= 0.6) gray++;
      double lift(BoxDecoration d) {
        final s = d.boxShadow!.first;
        return s.color.a * (s.blurRadius + s.offset.dy.abs());
      }
      if ((lift(resting) - lift(selected)).abs() >= 1.0) gray++;
      // 角标算一个灰度通道的前提是它自己在灰度下也真的比条目底深/浅，
      // 只"存在一个角标"不算数 —— 否则这条断言永远不可能失败。
      final marker = decorationAt(tester, deviceCheckMarkerKey('101'));
      if (contrast(surfaceColor(marker), surfaceColor(selected)) >= 3.0) gray++;
      expect(
        find.byKey(deviceCheckMarkerKey('102')),
        findsNothing,
        reason: '未选中条目不该带角标',
      );

      expect(
        gray,
        greaterThanOrEqualTo(2),
        reason: '灰度下选中态与普通态只剩一个通道，色觉或灰度模式下分不出来',
      );
    });

    testWidgets('grid layout survives 320x568 at 1.3 text scale', (
      tester,
    ) async {
      await pumpHomePage(
        tester,
        size: const Size(320, 568),
        textScale: 1.3,
      );
      await tester.tap(find.byTooltip('双列布局'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(deviceTileKey('101')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '小屏宫格溢出');
      expect(
        tester.getRect(find.byKey(primaryActionKey)).height,
        greaterThanOrEqualTo(56.0),
      );
    });

    testWidgets('both sheets carry a grabber that reads against the sheet face', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final entry in [
          ('管理设备', find.text('管理设备'), deviceManageSheetKey, '设备管理'),
          ('设置', find.byTooltip('设置'), settingsSheetKey, '设置'),
        ]) {
          Get.reset();
          await pumpHomePage(tester, brightness: brightness);
          await tester.tap(entry.$2);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));

          final grabber = decorationAt(tester, sheetGrabberKey);
          final face = tester.widget<Material>(find.byKey(entry.$3)).color!;
          expect(
            contrast(composite(grabber.color!, face), face),
            greaterThanOrEqualTo(1.15),
            reason: '$brightness ${entry.$1} 的拖拽条和抽屉面一个色，等于没画',
          );
          final rect = tester.getRect(find.byKey(sheetGrabberKey));
          expect(rect.width, greaterThanOrEqualTo(40));
          expect(rect.height, greaterThanOrEqualTo(4));

          // 抽屉面本身也必须和它盖住的页面分得开 —— 规格这条没有模式限定词。
          expectElevatedSurface(tester, entry.$4);
        }
      }
    });

    testWidgets('reorder mode survives 320x568 at 1.3 text scale', (
      tester,
    ) async {
      await pumpHomePage(
        tester,
        size: const Size(320, 568),
        textScale: 1.3,
      );
      await tester.tap(find.byTooltip('调整顺序'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('拖动调整顺序'), findsOneWidget);
      expect(find.byIcon(Ionicons.menu_outline), findsWidgets);
      expect(tester.takeException(), isNull, reason: '小屏排序模式溢出');
    });

    testWidgets('the sheet covers the page behind it', (tester) async {
      await pumpHomePage(tester);
      await tester.tap(find.text('管理设备'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byKey(deviceManageSheetKey), findsOneWidget);
      final barriers = tester.widgetList<ModalBarrier>(
        find.byType(ModalBarrier),
      ).toList();
      expect(barriers, isNotEmpty, reason: '抽屉下面没有遮罩层');
      expect(
        barriers.any((b) => b.color != null && b.color!.a > 0),
        isTrue,
        reason: '页面背后的遮罩全透明，抽屉像是浮在原图上',
      );
    });
  });

  group('round 3 regressions', () {
    /// 对话框里的文字按钮标签不吃主题 primary：`#2196F3` 压在白色对话框面上
    /// 只有 3.12，浅色下每条"取消"都是糊的。深色没这个问题（6.67）。
    ///
    /// 只管 TextButton：实色 FilledButton 的底经 ButtonStyle 绘制，Material 上是
    /// null，标签由 `_expectSolidActionLegible` 按 style 取值来验。
    void expectDialogLabelsLegible(WidgetTester tester, List<String> labels) {
      for (final label in labels) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$label 不在当前对话框里',
        );
        expect(
          contrastOn(
            effectiveTextColor(tester, label),
            surfaceBehind(tester, label),
          ),
          greaterThanOrEqualTo(4.5),
          reason: '$label 的标签色压不住它所在的面',
        );
      }
    }

    Future<void> settleDialog(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('every dialog action label clears 4.5 on the dialog face', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);

        await tester.longPress(find.byKey(deviceTileKey('102')));
        await settleDialog(tester);
        expectDialogLabelsLegible(tester, ['取消']);
        _expectSolidActionLegible(tester, label: '保存');
        await tester.tap(find.text('取消'));
        await settleDialog(tester);

        await tester.tap(find.text('管理设备'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.tap(find.byIcon(Ionicons.trash_outline).first);
        await settleDialog(tester);
        expectDialogLabelsLegible(tester, ['取消', '删除']);
        await tester.tap(find.text('取消'));
        await settleDialog(tester);
        await tester.tapAt(const Offset(200, 60));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));

        // 「关于」这条 ListTile 自己会先关掉抽屉再弹对话框，所以退出确认框
        // 必须重新开一次设置抽屉，不能假设还停在原地。
        await tester.tap(find.byTooltip('设置'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.tap(find.text('关于'));
        await settleDialog(tester);
        expectDialogLabelsLegible(tester, ['确定']);
        await tester.tap(find.text('确定'));
        await settleDialog(tester);

        await tester.tap(find.byTooltip('设置'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.tap(find.text('退出登录'));
        await settleDialog(tester);
        expectDialogLabelsLegible(tester, ['取消', '退出']);
        await tester.tap(find.text('取消'));
        await settleDialog(tester);
      }
    });

    testWidgets('the hairline is a real channel, not a drawn-but-invisible line', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);

        for (final key in [statusCardKey, deviceTileKey('102')]) {
          final c = channelsOf(tester, key);
          expect(
            c.border,
            isTrue,
            reason: '$brightness / $key 的描边合成后离身后的面不足 1.15，'
                '那两条通道其实只剩投影',
          );
        }
      }
    });

    testWidgets('the note field is separated from the dialog by two channels', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        await tester.longPress(find.byKey(deviceTileKey('102')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final field = tester.widget<TextField>(find.byType(TextField));
        final face = surfaceBehind(tester, '为设备添加备注');
        final fill = field.decoration!.fillColor!;
        final line = field.decoration!.enabledBorder!.borderSide.color;
        expect(
          contrast(fill, face),
          greaterThanOrEqualTo(1.15),
          reason: '$brightness 输入框填充离对话框面不足 1.15',
        );
        // 描边画在填充自己身上，身后就是填充，不能拿页面渐变当背景算。
        expect(
          contrast(composite(line, fill), fill),
          greaterThanOrEqualTo(1.15),
          reason: '$brightness 输入框描边压在自身填充上看不见',
        );
      }
    });

    testWidgets('the in-card progress bar exists only while water is running', (
      tester,
    ) async {
      await pumpHomePage(tester);
      expect(
        find.byType(LinearProgressIndicator),
        findsNothing,
        reason: '空闲时状态卡里不该有条在跑',
      );

      Get.find<HomeController>().isDrinking.value = true;
      await tester.pump();
      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason: '接水中状态卡丢了进度条',
      );
    });

    testWidgets('the idle gradient lands exactly on the scaffold colour', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor;
        final d = decorationAt(tester, homeBackgroundKey);
        final last = sampleGradient(d.gradient! as LinearGradient, 1.0);
        expect(
          last,
          equals(scaffold),
          reason: '$brightness 渐变收口和 Scaffold 底色不同，安全区上方会出现一条硬边',
        );
      }
    });
  });

  group('round 4 coverage', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> openSheet(WidgetTester tester, Finder opener) async {
      await tester.tap(opener);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('every dialog face separates from the page in both modes', (
      tester,
    ) async {
      // 规格里"抽屉/对话框是一个独立的抬升面"没有模式限定词，
      // 而抬升面是 Material 画的，前面那套 BoxDecoration 尺子量不到它们。
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);

        await tester.longPress(find.byKey(deviceTileKey('102')));
        await settle(tester);
        expectElevatedSurface(tester, '编辑备注 - 1-102');
        await tester.tap(find.text('取消'));
        await settle(tester);

        await openSheet(tester, find.text('管理设备'));
        await tester.tap(find.byIcon(Ionicons.trash_outline).first);
        await settle(tester);
        expectElevatedSurface(tester, '确认删除');
        await tester.tap(find.text('取消'));
        await settle(tester);
        // 删除框是从设备管理抽屉里点出来的，取消之后抽屉还在，
        // 它的遮罩压住整页 —— 这时候点顶栏的"设置"会被吞掉。
        await tester.tapAt(const Offset(200, 60));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('设备管理'), findsNothing);

        await openSheet(tester, find.byTooltip('设置'));
        await tester.tap(find.text('关于'));
        await settle(tester);
        expectElevatedSurface(tester, '版本:');
        await tester.tap(find.text('确定'));
        await settle(tester);
        // 上一张还压着 AbsorbPointer 的话，下面那次开抽屉会被吞掉。
        expect(find.textContaining('版本:'), findsNothing);

        await openSheet(tester, find.byTooltip('设置'));
        await tester.tap(find.text('退出登录'));
        await settle(tester);
        expectElevatedSurface(tester, '确认退出');
        await tester.tap(find.text('取消'));
        await settle(tester);
      }
    });
  });

  group('round 5 prompts', () {
    GetSnackBar snack(WidgetTester tester) =>
        tester.widget<GetSnackBar>(find.byType(GetSnackBar));

    // GetSnackBar 没有 colorText 这个字段：Get.snackbar 的 colorText 是被揉进
    // 标题与正文的 TextStyle 里的，所以只能读渲染出来的那段文字。
    Color snackLabel(WidgetTester tester, String message) => textColorAt(
      tester,
      find.descendant(
        of: find.byType(GetSnackBar),
        matching: find.text(message),
      ),
    );

    /// 色相（度）。提示条靠颜色本身表达"是哪一类"，所以三色相必须分得开。
    double hueOf(Color c) {
      final max = [c.r, c.g, c.b].reduce(math.max);
      final min = [c.r, c.g, c.b].reduce(math.min);
      final d = max - min;
      if (d == 0) return 0.0;
      final h =
          max == c.r
              ? 60 * (((c.g - c.b) / d) % 6)
              : max == c.g
              ? 60 * (((c.b - c.r) / d) + 2)
              : 60 * (((c.r - c.g) / d) + 4);
      return (h + 360) % 360;
    }

    /// 彩度（0 = 纯灰，1 = 最饱和）。规格那句"中性提示不带任何语义色相"用它量：
    /// 灰的底 hueOf 也返回 0，单看色相会和错误色撞在一起。
    double chromaOf(Color c) {
      final max = [c.r, c.g, c.b].reduce(math.max);
      final min = [c.r, c.g, c.b].reduce(math.min);
      return max == 0 ? 0 : (max - min) / max;
    }

    testWidgets('the three prompt kinds are legible and keep distinct hues', (
      tester,
    ) async {
      // 规格那句没有模式限定词，"both colour schemes" 就得两种都量。
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final kinds = <String, ({Color bg, Color fg})>{};

        // 1. 会话过期 → 警告色
        Get.reset();
        final expired = HangingDeviceListApiService(
          devices: const [
            {'id': '0', 'name': '登录已过期'},
          ],
        );
        await pumpHomePage(tester, api: expired, brightness: brightness);
        expired.release();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        kinds['warning'] = (
          bg: snack(tester).backgroundColor,
          fg: snackLabel(tester, '登录已过期，请重新登录'),
        );
        await dismissSnack(tester);

        // 2. 开始接水被服务端拒绝 → 错误色
        Get.reset();
        await pumpHomePage(
          tester,
          brightness: brightness,
          api: FakeHomeApiService(
            startResult: const DrinkResult(
              success: false,
              code: -100,
              message: '系统错误',
            ),
          ),
        );
        await tester.tap(find.byKey(primaryActionKey));
        await tester.pump();
        kinds['error'] = (
          bg: snack(tester).backgroundColor,
          fg: snackLabel(tester, '系统错误'),
        );
        await dismissSnack(tester);

        // 3. 开始接水成功 → 成功色
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        await tester.tap(find.byKey(primaryActionKey));
        await tester.pump();
        kinds['success'] = (
          bg: snack(tester).backgroundColor,
          fg: snackLabel(tester, '开始接水'),
        );
        // 收个尾把接水状态关掉：轮询用的是周期 Timer，不解散会活到测试结束之后。
        await tester.tap(find.byKey(primaryActionKey));
        await dismissSnack(tester);

        for (final entry in kinds.entries) {
          expect(
            entry.value.bg.a,
            1.0,
            reason:
                '$brightness 下 ${entry.key} 提示的底是半透明的，标签实际压在哪一档背景上说不准',
          );
          expect(
            contrast(entry.value.fg, entry.value.bg),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness 下 ${entry.key} 提示的标签压在自己的底上读不出',
          );
          // 色相差要成立，先要每一块真的带色：三块灰的色相都是 0，
          // 只比色相距离的话，两块无色的底也能蒙过这一段。
          expect(
            chromaOf(entry.value.bg),
            greaterThanOrEqualTo(0.3),
            reason:
                '$brightness 下 ${entry.key} 的底几乎没有彩度，色相承载不了「是哪一类提示」',
          );
        }
        final names = kinds.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final a = hueOf(kinds[names[i]]!.bg);
            final b = hueOf(kinds[names[j]]!.bg);
            expect(
              (a - b).abs(),
              greaterThanOrEqualTo(20.0),
              reason:
                  '$brightness 下 ${names[i]} 与 ${names[j]} 色相差只有 ${(a - b).abs().round()}°，颜色不再表达是哪一类提示',
            );
          }
        }
      }
    });

    // 这三处提示在改造前根本没写底色，落到 GetX 的默认底 Colors.grey.withOpacity(0.2)：
    // 一层两成透明的灰 wash，标签颜色还不是我们自己定的（Get.snackbar 走
    // colorText ?? iconColor ?? Colors.black）。第 5 轮给它们各自钉上了 notice 面，
    // 所以这里量的不再是那块默认灰，而是规格点名的"中性提示"本身：实底、4.5、
    // 并且不带任何语义色相，不会被看成成功／警告／错误里的哪一种。
    testWidgets('the plain blocking notice stays legible and carries no hue', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        await tester.tap(find.byKey(primaryActionKey));
        await tester.pump();
        await dismissSnack(tester);

        await tester.tap(find.byKey(deviceTileKey('101')));
        await tester.pump();
        final s = snack(tester);
        expect(
          s.backgroundColor.a,
          1.0,
          reason: '$brightness 下中性提示的底不是实底，白字压在哪一档背景上说不准',
        );
        // 同一类中性提示共用同一块面：三处 guard 不能各挑一个灰。
        expect(
          s.backgroundColor.toARGB32(),
          HomePromptColors.notice.toARGB32(),
          reason: '$brightness 下中性提示没走 notice 这一块面',
        );
        expect(
          contrast(snackLabel(tester, '正在接水中，请先结算'), s.backgroundColor),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness 下中性提示的标签读不出',
        );
        // 规格里那句"中性提示不带任何语义色相"：这块底必须是无彩度的，
        // 不能让人把「请先结算」看成成功／警告／错误里的哪一种。
        expect(
          chromaOf(s.backgroundColor),
          lessThan(0.15),
          reason: '$brightness 下中性提示带上了彩度，会和三类语义提示撞色',
        );
        // 关掉接水，周期轮询的 Timer 不能留到测试结束之后。
        await tester.tap(find.byKey(primaryActionKey));
        await dismissSnack(tester);
      }
    });

    // 独立审查抓出来的第十一处：这条提示不在 HomeController 里，而是页面自己的
    // 备注对话框保存后 raised 的，前面十点全按控制器找就会整个漏掉它。
    testWidgets('the note-save prompt the page raises itself is legible', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        await tester.longPress(find.byKey(deviceTileKey('102')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.tap(find.text('保存'));
        await tester.pump();
        final s = snack(tester);
        expect(
          s.backgroundColor.a,
          1.0,
          reason: '$brightness 下备注保存提示的底是半透明的',
        );
        expect(
          contrast(snackLabel(tester, '备注已保存'), s.backgroundColor),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness 下备注保存提示的标签读不出',
        );
        // 同一类语义必须同一块底：这条和控制器里的成功提示不能各走各的。
        expect(
          hueOf(s.backgroundColor),
          closeTo(hueOf(HomePromptColors.success), 1),
          reason: '$brightness 下备注保存提示和成功提示不是同一类颜色',
        );
        await dismissSnack(tester);
      }
    });
  });

  group('round 6 claims', () {
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    // 集成审查指出：Requirement 3 那句"每个面一个命名角色，而不是一处一个透明度"
    // 和 Requirement 6 那句"行内容 + 图标"都没有断言撑着。前者是这条规格的立身之本
    // ——只要各调用点自己写 alpha，值就散，规格形同虚设，所以要量。
    testWidgets('de-emphasized text resolves through one role per face', (
      tester,
    ) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        final card = surfaceColor(decorationAt(tester, statusCardKey));
        final caption = textColorIn(tester, statusCardKey, '选择设备开始接水');

        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        await tester.tap(find.text('管理设备'));
        await settle(tester);
        final sheet = tester.widget<Material>(find.byKey(deviceManageSheetKey));
        final subtitle = textColorIn(tester, deviceManageSheetKey, 'ID: 101');
        await tester.tapAt(const Offset(200, 60));
        await settle(tester);

        Get.reset();
        await pumpHomePage(tester, devices: const [], brightness: brightness);
        final emptyHint = effectiveTextColor(tester, '扫描设备上的二维码添加');

        Get.reset();
        await pumpHomePage(tester, brightness: brightness);
        await tester.longPress(find.byKey(deviceTileKey('102')));
        await settle(tester);
        final field = tester.widget<TextField>(find.byType(TextField));
        final dialogHint = field.decoration!.hintStyle!.color!;
        final dialogCounter = field.decoration!.counterStyle!.color!;
        final fieldFill = field.decoration!.fillColor!;
        await tester.tap(find.text('取消'));
        await settle(tester);

        // 「关于」框里那行说明也压在同一块卡片面上，它是第六个弱化标签；
        // 不把它一起量，规格那句"一处一个透明度"就还有一个漏点。
        await tester.tap(find.byTooltip('设置'));
        await settle(tester);
        await tester.tap(find.text('关于'));
        await settle(tester);
        final aboutInk = effectiveTextColor(
          tester,
          '官方广告太多，所以做了这个简洁版',
        );
        await tester.tap(find.text('确定'));
        await settle(tester);

        // 抽屉面就是 card 角色，否则下面"同一档墨"的比较没有共同基准。
        expect(
          sheet.color!.toARGB32(),
          card.toARGB32(),
          reason: '$brightness 抽屉面已不是卡片角色',
        );
        expect(
          subtitle.toARGB32(),
          caption.toARGB32(),
          reason: '$brightness 抽屉行副标题自己另用了一档弱化墨',
        );
        expect(
          emptyHint.toARGB32(),
          caption.toARGB32(),
          reason: '$brightness 空态提示自己另用了一档弱化墨',
        );
        expect(
          dialogCounter.toARGB32(),
          dialogHint.toARGB32(),
          reason: '$brightness 备注框的计数器和提示文字不是同一档',
        );
        expect(
          dialogHint.toARGB32(),
          caption.toARGB32(),
          reason: '$brightness 对话框另起了一档弱化墨',
        );
        expect(
          aboutInk.toARGB32(),
          caption.toARGB32(),
          reason: '$brightness 「关于」框的说明文字另起了一档弱化墨',
        );
        expect(
          contrastOn(caption, card),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness 那一档弱化墨在自己的面上读不出（也是深色模式的门槛）',
        );
        // 提示与计数器实际压在备注框自己的填充面（p.page）上，不是对话框面，
        // 所以门槛要按它真正吃到的那块面算。
        expect(
          contrastOn(dialogHint, fieldFill, backdrop: card),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness 备注框的提示文字在自己的填面上读不出',
        );
      }
    });

    testWidgets('the sheets carry the rows and icons the spec names', (
      tester,
    ) async {
      Get.reset();
      SharedPreferences.setMockInitialValues({'device_note_101': '茶水间'});
      await pumpHomePage(tester);

      await tester.tap(find.text('管理设备'));
      await settle(tester);
      final sheet = find.byKey(deviceManageSheetKey);
      // 有备注的行是"备注 · ID"，没有的行只剩 ID：两条分支都要在场。
      // 行标题是 formattedName，它把"栋"换成"-"，所以这里是 1-101 而不是 1栋101。
      expect(
        find.descendant(of: sheet, matching: find.text('1-101')),
        findsOneWidget,
      );
      expect(find.text('茶水间 · ID: 101'), findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('1-102')),
        findsOneWidget,
      );
      expect(find.text('ID: 102'), findsOneWidget);
      await tester.tapAt(const Offset(200, 60));
      await settle(tester);

      await tester.tap(find.byTooltip('设置'));
      await settle(tester);
      for (final entry in {
        '关于': Ionicons.information_circle_outline,
        '退出登录': Ionicons.log_out_outline,
      }.entries) {
        final row = find.ancestor(
          of: find.text(entry.key),
          matching: find.byType(ListTile),
        );
        expect(row, findsOneWidget, reason: '${entry.key} 不在设置抽屉里');
        expect(
          find.descendant(of: row, matching: find.byIcon(entry.value)),
          findsOneWidget,
          reason: '${entry.key} 那一行少了它的图标',
        );
      }
    });

    // 覆盖护栏，不是观测到的 RED：这两对在深色里本来就达标，
    // 只是先前只在浅色量过，而设计记录写的是"两种模式"。
    testWidgets('the tinted chip glyph clears the non-text floor in dark', (
      tester,
    ) async {
      Get.reset();
      await pumpHomePage(tester, brightness: Brightness.dark);
      final chip = decorationAt(tester, statusIconChipKey);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(statusIconChipKey),
          matching: find.byType(Icon),
        ),
      );
      expect(
        contrastOn(
          icon.color ?? Colors.black,
          surfaceColor(chip),
          backdrop: surfaceColor(decorationAt(tester, statusCardKey)),
        ),
        greaterThanOrEqualTo(3.0),
        reason: '深色模式图标底把字形吃掉了',
      );
    });
  });
}

/// 断言页面上的实色操作按钮：自带底色 token（不落回主题的 primary 底，
/// 那里白字只有 3.12:1），且标签相对该底色过 4.5:1。
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
