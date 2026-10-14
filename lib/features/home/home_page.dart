import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/device_model.dart';
import 'home_controller.dart';
import 'home_prompt_colors.dart';

/// 页面结构锚点。widget 测试靠这些 key 取"实际绘制的表面与文字颜色"，
/// 所以改名或删掉会直接让验收断言失效，不是可选装饰。
const homeBackgroundKey = Key('homeBackground');
const statusCardKey = Key('statusCard');
const statusIconChipKey = Key('statusIconChip');
const primaryActionKey = Key('primaryAction');
const layoutToggleKey = Key('layoutToggle');
const reorderToggleKey = Key('reorderToggle');
const deviceManageSheetKey = Key('deviceManageSheet');
const settingsSheetKey = Key('settingsSheet');
const aboutAppIconKey = Key('aboutAppIcon');
const emptyScanActionKey = Key('emptyScanAction');

Key deviceTileKey(String id) => Key('deviceTile-$id');

/// 设备项右侧的备注编辑按钮容器：命中区基线就钉在这个 key 上。
Key deviceEditKey(String id) => Key('deviceEdit-$id');

/// 选中角标的底色容器。角标是选中态的第二语言，测试要能单独取到它的面，
/// 而 find.ancestor 在一串同类型容器里给不出"最内层"的稳定顺序。
Key deviceCheckMarkerKey(String id) => Key('deviceCheckMarker-$id');

/// 排序模式提示条自己的面：规格要求它和平常浏览分开。
const reorderHintKey = Key('reorderHint');

/// 抽屉顶部的拖拽条。两个抽屉各开各的，同一时刻只会有一个在树上。
const sheetGrabberKey = Key('sheetGrabber');

/// 首页专用视觉 token，数值与推导见
/// docs/openspec/changes/refactor-home-page-ui/design.md 的 D3/D4/D8。
///
/// 刻意不写进 AppTheme：那会连带改掉登录页与扫码页的全局默认值。
/// 每个"承载文字的面 / 文字"配对都按 WCAG 相对亮度实算过，改动数值必须
/// 同步重跑 test/features/home/home_page_ui_test.dart 的对比度断言。
abstract final class _HomeT {
  // 浅色：页面本体比卡片暗一档，白卡片才浮得起来（page→card 1.174）。
  static const pageLight = Color(0xFFE4EEF8);
  static const cardLight = Color(0xFFFFFFFF);
  static const tintLight = Color(0xFFDCEBF9);
  static const bandTopLight = Color(0xFFC5E0F7);
  // α.18 的淡边压在白卡 1.133 / 本体 1.099 / 品牌带 1.079，三条全在 1.15 以下：
  // 描边画了但看不出画，"两条通道"实际只剩一档填充差。提到 α.30 才有第二条。
  static const hairlineLight = Color(0x4D7E96AE);

  // 深色：靠"抬亮"分层，但卡片必须比它真正压着的那条带也亮一档。
  // 上一版是 page #0F1417 / band #15293C / card #1A222B，带比卡片还亮，
  // 状态卡坐在带上只有 1.082，看着像被挖了个洞。现在 page < band < card，
  // 卡片永远是最亮的一块：card/band 1.189、card/page 1.303、
  // selected/card 1.198、tint/selected 1.160。
  static const pageDark = Color(0xFF0A0F14);
  static const cardDark = Color(0xFF1E2934);
  static const selectedDark = Color(0xFF283645);
  // 深色图标底与选中底必须分开：两者都取同一块时，选中条目的图标底糊成一片。
  static const tintDark = Color(0xFF31404F);
  static const bandTopDark = Color(0xFF0D1A28);
  // α.24 的旧描边压在新卡片上合成后只差 1.11，等于没画；提到 α.35 才有第二条通道。
  static const hairlineDark = Color(0x594C6076);

  // 强调面：白色标签在最浅停靠点仍有 4.80，旧 #00D4FF 只有 1.77。
  static const accentStart = Color(0xFF0277BD);
  static const accentEnd = Color(0xFF00619E);
  static const settle = HomePromptColors.warning;

  // 墨色：次要文字用 α.60，因为主题里的 black54 压在新页面本体上只有 4.44。
  static const inkLight = Color(0xDD000000);
  static const inkSecondaryLight = Color(0x99000000);
  // 顶带 #C5E0F7 比页面本体更深，标签压在上面是下限：#1565A8 只有 4.45。
  static const brandInkLight = Color(0xFF0F5C99);
  static const neutralGlyphLight = Color(0xFF5A6B7B);
  static const inkDark = Color(0xFFFFFFFF);
  static const inkSecondaryDark = Color(0xB3FFFFFF);
  static const brandInkDark = Color(0xFF64B5F6);
  static const neutralGlyphDark = Color(0xFF9AA7B4);

  // 不可用态：按 WCAG 1.4.3 属于豁免，但仍要与可用态一眼可辨。
  // 危险操作用 red800/red200 一档：Colors.red 压在白卡片上只有 3.68:1。
  // 浅色取提示条的错误色同一份，两处不能各写一个红。
  static const destructiveLight = HomePromptColors.error;
  static const destructiveDark = Color(0xFFFF8A80);

  static const disabledLight = Color(0xFFC6D3DE);
  static const disabledInkLight = Color(0xFF4A5765);
  static const disabledDark = Color(0xFF232B33);
  static const disabledInkDark = Color(0xFF9AA7B4);

  static const radiusCard = 24.0;
  static const radiusTile = 14.0;
  static const radiusChip = 12.0;
}

/// 首页表面色的按主题分支取值，避免每处都写三元判断。
class _HomePalette {
  const _HomePalette.dark()
    : page = _HomeT.pageDark,
      card = _HomeT.cardDark,
      selected = _HomeT.selectedDark,
      tint = _HomeT.tintDark,
      bandTop = _HomeT.bandTopDark,
      hairline = _HomeT.hairlineDark,
      ink = _HomeT.inkDark,
      inkSecondary = _HomeT.inkSecondaryDark,
      brandInk = _HomeT.brandInkDark,
      neutralGlyph = _HomeT.neutralGlyphDark,
      disabled = _HomeT.disabledDark,
      disabledInk = _HomeT.disabledInkDark,
      destructive = _HomeT.destructiveDark,
      isDark = true;

  const _HomePalette.light()
    : page = _HomeT.pageLight,
      card = _HomeT.cardLight,
      selected = _HomeT.cardLight,
      tint = _HomeT.tintLight,
      bandTop = _HomeT.bandTopLight,
      hairline = _HomeT.hairlineLight,
      ink = _HomeT.inkLight,
      inkSecondary = _HomeT.inkSecondaryLight,
      brandInk = _HomeT.brandInkLight,
      neutralGlyph = _HomeT.neutralGlyphLight,
      disabled = _HomeT.disabledLight,
      disabledInk = _HomeT.disabledInkLight,
      destructive = _HomeT.destructiveLight,
      isDark = false;

  static _HomePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const _HomePalette.dark()
      : const _HomePalette.light();

  /// 小屏或大字号时收紧留白：固定 padding 配固定高度在这种尺寸会直接把
  /// 卡片顶出可视区（RenderFlex overflow），收紧一档即可回到可容纳范围。
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 640 ||
      MediaQuery.textScalerOf(context).scale(14) > 16.8;

  final Color page;
  final Color card;
  final Color selected;
  final Color tint;
  final Color bandTop;
  final Color hairline;
  final Color ink;
  final Color inkSecondary;
  final Color brandInk;
  final Color neutralGlyph;
  final Color disabled;
  final Color disabledInk;
  final Color destructive;
  final bool isDark;

  /// 选中态是否用提亮填充表达。浅色下不换填充：当年试过的淡蓝 `#F5FAFF`
  /// 相对页面本体只有 1.118，选中反而把卡片粘回背景，所以浅色改用
  /// 描边+勾选+抬升两个通道。
  bool get selectionTintsFill => isDark;

  Color tileFill({required bool isSelected}) =>
      isSelected && selectionTintsFill ? selected : card;

  /// 选中角标的面与符号色。浅色用品牌渐变起手色压在白卡上是 4.80，
  /// 深色反过来：品牌蓝底配白勾在 #283645 上只有 2.57，所以深色改成
  /// 亮品牌蓝底配页面墨色（面 5.57、符号 8.69）。
  Color get markerFill => isDark ? brandInk : _HomeT.accentStart;
  Color get markerInk => isDark ? page : Colors.white;

  LinearGradient get idleBackground => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bandTop, Color.lerp(bandTop, page, 0.55)!, page],
    stops: const [0.0, 0.42, 1.0],
  );

  LinearGradient get activeBackground => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.alphaBlend(_HomeT.accentStart.withValues(alpha: 0.28), page),
      Color.alphaBlend(_HomeT.accentEnd.withValues(alpha: 0.18), page),
      page,
    ],
    stops: const [0.0, 0.5, 1.0],
  );

  LinearGradient get accentFill => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_HomeT.accentStart, _HomeT.accentEnd],
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // build 可能被反复调用，控制器只在首次注册时创建；
    // 测试先注入替身再泵页面，这里的分支保证它不被真实单例顶掉。
    final controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController());

    return Scaffold(
      // 本体色由页面自己给定，不用全局 scaffoldBackgroundColor：
      // 加载态、overscroll 发光和抽屉底衬都跟着走，才不会露出第二层灰。
      backgroundColor: _HomePalette.of(context).page,
      body: Stack(
        children: [
          // 背景渐变：空闲=品牌锚点，接水中=水色渐变；两者都以本体色收尾。
          Positioned.fill(
            child: Obx(() => AnimatedContainer(
              key: homeBackgroundKey,
              duration: const Duration(milliseconds: 800),
              decoration: BoxDecoration(
                gradient: _HomePalette.of(context).idleBackground,
              ),
              foregroundDecoration: controller.isDrinking.value
                  ? BoxDecoration(
                      gradient: _HomePalette.of(context).activeBackground,
                    )
                  : null,
            )),
          ),

          // 气泡动画
          Obx(() => controller.isDrinking.value
              ? const _BubbleAnimation()
              : const SizedBox.shrink()),

          // 主要内容
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, controller),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _buildContent(context, controller);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildAppBar(BuildContext context, HomeController controller) {
    final p = _HomePalette.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.tint,
                  borderRadius: BorderRadius.circular(_HomeT.radiusChip),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: p.brandInk,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '智能饮水',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: controller.loadDevices,
                icon: Icon(Ionicons.refresh_outline, color: p.neutralGlyph),
                tooltip: '刷新',
              ),
              IconButton(
                onPressed: () => _showSettingsSheet(context, controller),
                icon: Icon(Ionicons.settings_outline, color: p.neutralGlyph),
                tooltip: '设置',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 主要内容
  Widget _buildContent(BuildContext context, HomeController controller) {
    final compact = _HomePalette.isCompact(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: compact ? 8 : 20),

          // 状态显示
          _buildStatusCard(context, controller),

          SizedBox(height: compact ? 14 : 24),

          // 设备选择区域
          _buildDeviceSection(context, controller),

          SizedBox(height: compact ? 12 : 20),

          // 操作按钮
          _buildActionButton(context, controller),

          SizedBox(height: compact ? 10 : 20),

          // 底部功能按钮
          _buildBottomActions(context, controller),

          SizedBox(height: compact ? 10 : 20),
        ],
      ),
    );
  }

  /// 状态卡片
  Widget _buildStatusCard(BuildContext context, HomeController controller) {
    return Obx(() {
      final isDrinking = controller.isDrinking.value;
      final p = _HomePalette.of(context);

      return AnimatedContainer(
        key: statusCardKey,
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(_HomePalette.isCompact(context) ? 16 : 22),
        decoration: BoxDecoration(
          // 承载文字的面只在接水中用渐变，且浅色对为 #0277BD→#00619E：
          // 白色标签在最浅一端仍有 4.80:1。
          gradient: isDrinking ? p.accentFill : null,
          color: isDrinking ? null : p.card,
          borderRadius: BorderRadius.circular(_HomeT.radiusCard),
          border: isDrinking
              ? null
              : Border.all(color: p.hairline, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDrinking
                  ? _HomeT.accentEnd.withValues(alpha: 0.28)
                  : p.ink.withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  key: statusIconChipKey,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDrinking
                        ? Colors.white.withValues(alpha: 0.18)
                        : p.tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isDrinking ? Ionicons.water : Ionicons.water_outline,
                    // 图标是非文字元素，底线 3.0：tint 底上要用深一档的品牌墨，
                    // 主题主色 #2196F3 压在淡蓝底上只有 2.57，深一档才够 3.0。
                    color: isDrinking
                        ? Colors.white
                        : p.brandInk,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDrinking ? '正在接水中' : '准备就绪',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDrinking ? Colors.white : p.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDrinking ? '接完后点击结算' : '选择设备开始接水',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        // 降层级靠字号与字重，不靠透明度：白色 α.85 压在强调面上
                        // 只有 3.92:1。
                        color: isDrinking ? Colors.white : p.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isDrinking) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                backgroundColor: Colors.white.withValues(alpha:0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ],
        ),
      );
    });
  }

  /// 设备选择区域
  Widget _buildDeviceSection(BuildContext context, HomeController controller) {
    final p = _HomePalette.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '我的设备',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
              Obx(() {
                final isGrid = controller.layoutMode.value == 'grid';
                return IconButton(
                  key: layoutToggleKey,
                  tooltip: isGrid ? '单列布局' : '双列布局',
                  onPressed: controller.isReordering.value
                      ? null
                      : () => controller.setLayoutMode(isGrid ? 'list' : 'grid'),
                  icon: Icon(
                    isGrid ? Ionicons.list_outline : Ionicons.grid_outline,
                    size: 20,
                    color: p.neutralGlyph,
                  ),
                );
              }),
              Obx(() {
                final reordering = controller.isReordering.value;
                return IconButton(
                  key: reorderToggleKey,
                  tooltip: reordering ? '完成排序' : '调整顺序',
                  onPressed: controller.toggleReorderMode,
                  icon: Icon(
                    reordering
                        ? Ionicons.checkmark
                        : Ionicons.swap_vertical_outline,
                    size: 20,
                    color: reordering ? p.brandInk : p.neutralGlyph,
                  ),
                );
              }),
              TextButton.icon(
                onPressed: controller.scanAndAddDevice,
                style: TextButton.styleFrom(foregroundColor: p.brandInk),
                icon: const Icon(Ionicons.add_circle_outline, size: 20),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.deviceList.isEmpty) {
                return _buildEmptyDeviceCard(context, controller);
              }
              if (controller.isReordering.value) {
                return _buildReorderList(context, controller);
              }
              if (controller.layoutMode.value == 'grid') {
                return _buildDeviceGridLayout(context, controller);
              }
              return _buildDeviceCompactList(context, controller);
            }),
          ),
        ],
      ),
    );
  }

  /// 空设备卡片
  Widget _buildEmptyDeviceCard(BuildContext context, HomeController controller) {
    final p = _HomePalette.of(context);
    final compact = _HomePalette.isCompact(context);

    // 外层可滚 + 居中：小屏或大字号下这张固定内容的卡顶不住时，
    // 让它能滚而不是把 Column 撑爆。
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.all(compact ? 20 : 32),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(_HomeT.radiusTile),
            border: Border.all(color: p.hairline, width: 1),
            boxShadow: [
              BoxShadow(
                color: p.ink.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Ionicons.hardware_chip_outline,
                size: 48,
                color: p.neutralGlyph,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无设备',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '扫描设备上的二维码添加',
                style: TextStyle(
                  fontSize: 13,
                  color: p.inkSecondary,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: emptyScanActionKey,
                style: FilledButton.styleFrom(
                  backgroundColor: _HomeT.accentStart,
                ),
                onPressed: controller.scanAndAddDevice,
                icon: const Icon(Ionicons.scan_outline),
                label: const Text('扫码添加'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 紧凑单列设备列表
  Widget _buildDeviceCompactList(
    BuildContext context,
    HomeController controller,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: controller.deviceList.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildCompactDeviceItem(context, controller, index),
        );
      },
    );
  }

  /// 紧凑设备项
  Widget _buildCompactDeviceItem(
    BuildContext context,
    HomeController controller,
    int index, {
    bool showDragHandle = false,
  }) {
    return Obx(() {
      final device = controller.deviceList[index];
      final isSelected = controller.selectedDeviceIndex.value == index;
      final p = _HomePalette.of(context);

      return GestureDetector(
        onTap: controller.isReordering.value
            ? null
            : () => controller.selectDevice(index),
        onLongPress: controller.isReordering.value
            ? null
            : () => _showNoteEditDialog(context, controller, device),
        child: Container(
          key: deviceTileKey(device.id),
          // vertical 11：命中面积只增不减 —— 测试把 60.0（选中）/ 57.0（未选）
          // 钉成下限。这两个数是改版后实测的，不是从旧几何推的：Container 的
          // 装饰描边不参与布局，改版前无论 2px 还是 1.6px 描边，行高都是
          // 36 + 2×10 = 56，所以这道护栏比要求更严，而不是"等于旧值"。
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            // 浅色下选中不换填充（当年那版淡蓝 `#F5FAFF` 对页面只有 1.118，选中反而糊回去），
            // 由描边 + 勾选 + 抬升两个通道表达；深色仍提亮一档。
            color: p.tileFill(isSelected: isSelected),
            borderRadius: BorderRadius.circular(_HomeT.radiusTile),
            border: Border.all(
              // 选中描边是非文字指示元素，底线 3.0：primary 蓝压在本体色上只有 2.66。
              color: isSelected ? p.brandInk : p.hairline,
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? _HomeT.accentStart.withValues(alpha: 0.22)
                    : p.ink.withValues(alpha: 0.06),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.tint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Ionicons.hardware_chip_outline,
                  color: isSelected ? p.brandInk : p.neutralGlyph,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  device.note?.isNotEmpty == true
                      ? device.note!
                      : device.formattedName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: p.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!controller.isReordering.value) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      _showNoteEditDialog(context, controller, device),
                  child: Container(
                    key: deviceEditKey(device.id),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      // 静止条目本身就是 card 面，再铺 card 等于隐形，只剩一条描边。
                      color: p.tint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.hairline, width: 1),
                    ),
                    child: Icon(
                      Ionicons.create_outline,
                      size: 14,
                      color: p.neutralGlyph,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    key: deviceCheckMarkerKey(device.id),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: p.markerFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Ionicons.checkmark,
                      size: 14,
                      color: p.markerInk,
                    ),
                  ),
                ],
              ],
              if (showDragHandle) ...[
                const SizedBox(width: 8),
                Icon(
                  Ionicons.menu_outline,
                  size: 20,
                  color: p.neutralGlyph,
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  /// 双列密集网格
  Widget _buildDeviceGridLayout(
    BuildContext context,
    HomeController controller,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.4,
      ),
      itemCount: controller.deviceList.length,
      itemBuilder: (context, index) {
        return _buildGridDeviceItem(context, controller, index);
      },
    );
  }

  Widget _buildGridDeviceItem(
    BuildContext context,
    HomeController controller,
    int index,
  ) {
    return Obx(() {
      final device = controller.deviceList[index];
      final isSelected = controller.selectedDeviceIndex.value == index;
      final p = _HomePalette.of(context);

      return GestureDetector(
        onTap: () => controller.selectDevice(index),
        onLongPress: () =>
            _showNoteEditDialog(context, controller, device),
        child: Container(
          key: deviceTileKey(device.id),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: p.tileFill(isSelected: isSelected),
            borderRadius: BorderRadius.circular(_HomeT.radiusTile),
            border: Border.all(
              // 选中描边是非文字指示元素，底线 3.0：primary 蓝压在本体色上只有 2.66。
              color: isSelected ? p.brandInk : p.hairline,
              width: isSelected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? _HomeT.accentStart.withValues(alpha: 0.22)
                    : p.ink.withValues(alpha: 0.06),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Ionicons.hardware_chip_outline,
                size: 18,
                color: isSelected ? p.brandInk : p.neutralGlyph,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device.note?.isNotEmpty == true
                      ? device.note!
                      : device.formattedName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: p.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Icon(
                  Ionicons.checkmark_circle,
                  size: 16,
                  color: p.markerFill,
                ),
            ],
          ),
        ),
      );
    });
  }

  /// 排序模式：单列可拖列表
  Widget _buildReorderList(
    BuildContext context,
    HomeController controller,
  ) {
    final p = _HomePalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          // 规格要求排序提示落在"和平常浏览不同的一块面"上。card 底 + hairline
          // 描边和静止条目长得一模一样，看着像浏览态本身；这里改成品牌色模式条，
          // 离本体色 4.4、离白条目 4.6，白字压在最浅停靠点仍有 4.80。
          child: Container(
            key: reorderHintKey,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: p.accentFill,
              borderRadius: BorderRadius.circular(_HomeT.radiusChip),
              border: Border.all(color: p.brandInk, width: 1.2),
            ),
            child: const Text(
              '拖动调整顺序',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            return ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              buildDefaultDragHandles: false,
              itemCount: controller.deviceList.length,
              onReorder: controller.reorderDevices,
              itemBuilder: (context, index) {
                final device = controller.deviceList[index];
                return Padding(
                  key: ValueKey(device.id),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: _buildCompactDeviceItem(
                      context,
                      controller,
                      index,
                      showDragHandle: true,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  /// 显示备注编辑对话框
  void _showNoteEditDialog(
    BuildContext context,
    HomeController controller,
    DeviceModel device,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          _NoteEditDialog(device: device, controller: controller),
    );
  }

  /// 操作按钮
  ///
  /// 渐变由外层 DecoratedBox 绘制，按钮本身留透明底：
  /// 这样 FilledButton 的 onPressed==null 禁用语义、ripple、focus
  /// 和标签布局全部保留（见 design.md D6）。
  Widget _buildActionButton(BuildContext context, HomeController controller) {
    return Obx(() {
      final isDrinking = controller.isDrinking.value;
      final hasDevice = controller.currentDevice != null;
      final p = _HomePalette.of(context);
      final compact = _HomePalette.isCompact(context);
      final radius = BorderRadius.circular(compact ? 22 : 26);

      final decoration = !hasDevice
          ? BoxDecoration(
              color: p.disabled,
              borderRadius: radius,
            )
          : isDrinking
          ? BoxDecoration(
              color: _HomeT.settle,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: _HomeT.settle.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            )
          : BoxDecoration(
              gradient: p.accentFill,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: _HomeT.accentEnd.withValues(alpha: 0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            );

      final labelColor = hasDevice ? Colors.white : p.disabledInk;

      return DecoratedBox(
        key: primaryActionKey,
        decoration: decoration,
        child: SizedBox(
          width: double.infinity,
          height: compact ? 56 : 64,
          child: FilledButton(
            onPressed: hasDevice
                ? (isDrinking ? controller.stopDrinking : controller.startDrinking)
                : null,
            // 圆角必须与外层一致，否则 ripple 会按主题默认的 16 被裁掉一角。
            style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  // 不给 disabledBackgroundColor 的话，M3 默认会给禁用态铺一层
                  // onSurface@0.12，正好盖掉外层的中性底与标签配色。
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: radius),
                ).copyWith(
                  // 强调面上按压波纹要用白色，主题默认的 onSurface 叠色在深色
                  // 底上几乎是黑的。
                  overlayColor: WidgetStatePropertyAll(
                    Colors.white.withValues(alpha: 0.24),
                  ),
                ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isDrinking ? Ionicons.stop_circle : Ionicons.play_circle,
                  size: 26,
                  color: labelColor,
                ),
                const SizedBox(width: 12),
                Text(
                  isDrinking ? '结算' : '开始接水',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// 底部功能按钮
  Widget _buildBottomActions(BuildContext context, HomeController controller) {
    final p = _HomePalette.of(context);
    final style = TextButton.styleFrom(
      // 次级入口是文字，压在本体色上必须过 4.5；默认 primary 蓝只有 2.66。
      foregroundColor: p.brandInk,
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          style: style,
          onPressed: () => _showDeviceManageSheet(context, controller),
          icon: const Icon(Ionicons.grid_outline, size: 18),
          label: const Text('管理设备'),
        ),
        const SizedBox(width: 20),
        TextButton.icon(
          style: style,
          onPressed: controller.scanAndAddDevice,
          icon: const Icon(Ionicons.scan_outline, size: 18),
          label: const Text('扫码添加'),
        ),
      ],
    );
  }

  /// 显示设备管理弹窗
  void _showDeviceManageSheet(BuildContext context, HomeController controller) {
    final p = _HomePalette.of(context);

    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        key: deviceManageSheetKey,
        // 抽屉面 = 卡片面：沿用全局 scaffold 底会和新的本体色只差 1.06。
        color: p.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                key: sheetGrabberKey,
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  // 拖拽条走 tint：比抽屉面深 1.214（深色 1.390）。
                  // 它当初定下来时 hairline 压在白卡上只有 1.133，肉眼看不见；
                  // round 3 把 hairline 提到 1.34 之后 tint 仍是更深的那一档。
                  color: p.tint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '设备管理',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.deviceList.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Ionicons.hardware_chip_outline,
                          size: 48,
                          color: p.neutralGlyph,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无设备',
                          style: TextStyle(fontSize: 15, color: p.ink),
                        ),
                      ],
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.deviceList.length,
                    itemBuilder: (context, index) {
                      final device = controller.deviceList[index];

                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: p.tint,
                            borderRadius: BorderRadius.circular(_HomeT.radiusChip),
                          ),
                          child: Icon(
                            Ionicons.hardware_chip_outline,
                            color: p.neutralGlyph,
                          ),
                        ),
                        title: Text(
                          device.formattedName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                        subtitle: Text(
                          device.note?.isNotEmpty == true
                              ? '${device.note} · ID: ${device.id}'
                              : 'ID: ${device.id}',
                          style: TextStyle(fontSize: 13, color: p.inkSecondary),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Ionicons.trash_outline,
                            color: p.destructive,
                          ),
                          onPressed: () {
                            _showDeleteConfirm(context, controller, device);
                          },
                        ),
                      );
                    },
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    controller.scanAndAddDevice();
                  },
                  icon: const Icon(Ionicons.add),
                  label: const Text('添加新设备'),
                  style: FilledButton.styleFrom(
                    // 主题的 primary 底配白字只有 3.12:1，实色按钮统一深一档。
                    backgroundColor: _HomeT.accentStart,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 删除确认
  void _showDeleteConfirm(BuildContext context, HomeController controller, device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // 对话框底色取自页面 token：主题的 surface 是全局 #F5F9FF，
        // 在新的本体色旁边会露出第三层灰。
        backgroundColor: _HomePalette.of(context).card,
        title: const Text('确认删除'),
        content: Text('确定要删除设备 "${device.formattedName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            // 不吃主题 primary（#2196F3 压在白色对话框面上只有 3.12），
            // 统一到页面自己的品牌墨：浅色 6.97，深色 6.67。
            style: TextButton.styleFrom(
              foregroundColor: _HomePalette.of(context).brandInk,
            ),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.removeDevice(device);
            },
            style: TextButton.styleFrom(
              foregroundColor: _HomePalette.of(context).destructive,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示设置弹窗
  void _showSettingsSheet(BuildContext context, HomeController controller) {
    final p = _HomePalette.of(context);

    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        key: settingsSheetKey,
        color: p.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                key: sheetGrabberKey,
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  // 拖拽条走 tint：比抽屉面深 1.214（深色 1.390）。
                  // 它当初定下来时 hairline 压在白卡上只有 1.133，肉眼看不见；
                  // round 3 把 hairline 提到 1.34 之后 tint 仍是更深的那一档。
                  color: p.tint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '设置',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Ionicons.information_circle_outline,
                  color: p.brandInk,
                ),
                title: Text(
                  '关于',
                  style: TextStyle(fontSize: 15, color: p.ink),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog(context);
                },
              ),
              ListTile(
                leading: Icon(Ionicons.log_out_outline, color: p.destructive),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: p.destructive),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutConfirm(context, controller);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 关于对话框
  void _showAboutDialog(BuildContext context) {
    final p = _HomePalette.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // 对话框底色取自页面 token：主题的 surface 是全局 #F5F9FF，
        // 在新的本体色旁边会露出第三层灰。
        backgroundColor: p.card,
        title: Row(
          children: [
            Container(
              key: aboutAppIconKey,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: p.tint,
                borderRadius: BorderRadius.circular(_HomeT.radiusChip),
              ),
              child: Icon(
                Icons.water_drop_rounded,
                color: p.brandInk,
              ),
            ),
            const SizedBox(width: 12),
            const Text('智能饮水'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('版本: 1.0.4'),
            const SizedBox(height: 8),
            const Text('惠生活798喝水功能的第三方客户端'),
            const SizedBox(height: 4),
            Text(
              '官方广告太多，所以做了这个简洁版',
              style: TextStyle(
                fontSize: 13,
                color: p.inkSecondary,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _launchUrl('https://github.com/tunecc/drink_798'),
              child: Row(
                children: [
                  Icon(Ionicons.logo_github, size: 18, color: p.brandInk),
                  const SizedBox(width: 8),
                  Text(
                    'GitHub 开源地址',
                    style: TextStyle(
                      color: p.brandInk,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _HomePalette.of(context).brandInk,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 打开URL
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 退出登录确认
  void _showLogoutConfirm(BuildContext context, HomeController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // 对话框底色取自页面 token：主题的 surface 是全局 #F5F9FF，
        // 在新的本体色旁边会露出第三层灰。
        backgroundColor: _HomePalette.of(context).card,
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            // 不吃主题 primary（#2196F3 压在白色对话框面上只有 3.12），
            // 统一到页面自己的品牌墨：浅色 6.97，深色 6.67。
            style: TextButton.styleFrom(
              foregroundColor: _HomePalette.of(context).brandInk,
            ),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.logout();
            },
            style: TextButton.styleFrom(
              foregroundColor: _HomePalette.of(context).destructive,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

/// 备注编辑对话框。
///
/// 原来是对话框 builder 里手建的 TextEditingController，路由关掉也没人回收；
/// 交给 State 持有，dispose 里还掉。
class _NoteEditDialog extends StatefulWidget {
  const _NoteEditDialog({required this.device, required this.controller});

  final DeviceModel device;
  final HomeController controller;

  @override
  State<_NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<_NoteEditDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.device.note ?? '',
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _HomePalette.of(context);
    // 主题的输入框底是纯白 / #1F1F1F，压在对话框上分不出边界；这里用本体色，
    // 比对话框面低一档，副文字压在上面仍然达标。
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_HomeT.radiusChip),
      borderSide: BorderSide(color: p.hairline),
    );

    return AlertDialog(
      // 对话框底色取自页面 token：主题的 surface 是全局 #F5F9FF，
      // 在新的本体色旁边会露出第三层灰。
      backgroundColor: p.card,
      title: Text(
        '编辑备注 - ${widget.device.formattedName}',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
      ),
      content: TextField(
        controller: _text,
        style: TextStyle(color: p.ink),
        decoration: InputDecoration(
          hintText: '为设备添加备注',
          hintStyle: TextStyle(color: p.inkSecondary),
          prefixIcon: Icon(Ionicons.create_outline, color: p.neutralGlyph),
          filled: true,
          fillColor: p.page,
          counterStyle: TextStyle(color: p.inkSecondary),
          enabledBorder: fieldBorder,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_HomeT.radiusChip),
            borderSide: BorderSide(color: p.brandInk, width: 1.6),
          ),
        ),
        maxLength: 20,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: p.brandInk),
          child: const Text('取消'),
        ),
        FilledButton(
          // 主题的 primary 底配白字只有 3.12:1，实色按钮统一走深一档的品牌蓝。
          style: FilledButton.styleFrom(backgroundColor: _HomeT.accentStart),
          onPressed: () {
            widget.controller.saveDeviceNote(widget.device.id, _text.text);
            Navigator.pop(context);
            Get.snackbar(
              '成功',
              '备注已保存',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 1),
              backgroundColor: HomePromptColors.success,
              colorText: HomePromptColors.label,
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

/// 气泡动画组件
class _BubbleAnimation extends StatefulWidget {
  const _BubbleAnimation();

  @override
  State<_BubbleAnimation> createState() => _BubbleAnimationState();
}

class _BubbleAnimationState extends State<_BubbleAnimation>
    with TickerProviderStateMixin {
  final List<_Bubble> _bubbles = [];
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (mounted && _bubbles.length < 30) {
        setState(() {
          _bubbles.add(_Bubble(
            x: _random.nextDouble() * (MediaQuery.of(context).size.width - 50),
            size: _random.nextDouble() * 30 + 10,
            controller: AnimationController(
              duration: Duration(seconds: (_random.nextInt(3) + 2)),
              vsync: this,
            )..forward(),
          ));
        });

        // 移除已完成的气泡
        _bubbles.removeWhere((bubble) {
          if (bubble.controller.isCompleted) {
            bubble.controller.dispose();
            return true;
          }
          return false;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var bubble in _bubbles) {
      bubble.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _bubbles.map((bubble) {
        return AnimatedBuilder(
          animation: bubble.controller,
          builder: (context, child) {
            final progress = bubble.controller.value;
            return Positioned(
              left: bubble.x + sin(progress * 4 * pi) * 20,
              bottom: progress * MediaQuery.of(context).size.height,
              child: Opacity(
                opacity: 1 - progress,
                child: Container(
                  width: bubble.size,
                  height: bubble.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // 气泡压在新的深水渐变上，用白色系才读得出"水里冒泡"；
                    // 旧的 primary 蓝半透明在新底色上几乎看不见。
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.34),
                        Colors.white.withValues(alpha: 0.14),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.42),
                      width: 1,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _Bubble {
  final double x;
  final double size;
  final AnimationController controller;

  _Bubble({
    required this.x,
    required this.size,
    required this.controller,
  });
}
