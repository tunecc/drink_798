import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ionicons/ionicons.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import 'home_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      body: Stack(
        children: [
          // 背景渐变
          Obx(() => AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: controller.isDrinking.value
                    ? [
                        const Color(0xFF00D4FF).withOpacity(0.3),
                        const Color(0xFF0099CC).withOpacity(0.5),
                        Theme.of(context).scaffoldBackgroundColor,
                      ]
                    : [
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context).scaffoldBackgroundColor,
                      ],
                stops: controller.isDrinking.value
                    ? const [0.0, 0.5, 1.0]
                    : const [0.0, 1.0],
              ),
            ),
          )),

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
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '智能饮水',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: controller.loadDevices,
                icon: const Icon(Ionicons.refresh_outline),
                tooltip: '刷新',
              ),
              IconButton(
                onPressed: () => _showSettingsSheet(context, controller),
                icon: const Icon(Ionicons.settings_outline),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          
          // 状态显示
          _buildStatusCard(context, controller),
          
          const SizedBox(height: 24),
          
          // 设备选择区域
          _buildDeviceSection(context, controller),
          
          const Spacer(),
          
          // 操作按钮
          _buildActionButton(context, controller),
          
          const SizedBox(height: 20),
          
          // 底部功能按钮
          _buildBottomActions(context, controller),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// 状态卡片
  Widget _buildStatusCard(BuildContext context, HomeController controller) {
    return Obx(() {
      final isDrinking = controller.isDrinking.value;
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: isDrinking
              ? const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF0099CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isDrinking ? null : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: !isDrinking && isDark
              ? Border.all(
                  color: Colors.grey.shade800,
                  width: 0.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isDrinking
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDrinking
                        ? Colors.white.withOpacity(0.2)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isDrinking
                        ? Ionicons.water
                        : Ionicons.water_outline,
                    color: isDrinking ? Colors.white : AppTheme.primaryColor,
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
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDrinking ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDrinking ? '接完后点击结算' : '选择设备开始接水',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDrinking
                            ? Colors.white.withOpacity(0.8)
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isDrinking) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                backgroundColor: Colors.white.withOpacity(0.2),
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
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '我的设备',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Obx(() {
                final isGrid = controller.layoutMode.value == 'grid';
                return IconButton(
                  tooltip: isGrid ? '单列布局' : '双列布局',
                  onPressed: controller.isReordering.value
                      ? null
                      : () => controller.setLayoutMode(isGrid ? 'list' : 'grid'),
                  icon: Icon(
                    isGrid ? Ionicons.list_outline : Ionicons.grid_outline,
                    size: 20,
                  ),
                );
              }),
              Obx(() {
                final reordering = controller.isReordering.value;
                return IconButton(
                  tooltip: reordering ? '完成排序' : '调整顺序',
                  onPressed: controller.toggleReorderMode,
                  icon: Icon(
                    reordering
                        ? Ionicons.checkmark
                        : Ionicons.swap_vertical_outline,
                    size: 20,
                    color: reordering ? AppTheme.primaryColor : null,
                  ),
                );
              }),
              TextButton.icon(
                onPressed: controller.scanAndAddDevice,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.withOpacity(0.2),
          style: isDark ? BorderStyle.solid : BorderStyle.solid,
          width: isDark ? 1 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Ionicons.hardware_chip_outline,
            size: 48,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无设备',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '扫描设备上的二维码添加',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: controller.scanAndAddDevice,
            icon: const Icon(Ionicons.scan_outline),
            label: const Text('扫码添加'),
          ),
        ],
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
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return GestureDetector(
        onTap: controller.isReordering.value
            ? null
            : () => controller.selectDevice(index),
        onLongPress: controller.isReordering.value
            ? null
            : () => _showNoteEditDialog(context, controller, device),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isDark
                      ? Colors.grey.shade800
                      : Colors.grey.withOpacity(0.2)),
              width: isSelected ? 2 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : (isDark ? Colors.grey.shade800 : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Ionicons.hardware_chip_outline,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.grey[400] : Colors.grey),
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
                        isSelected ? FontWeight.bold : FontWeight.w600,
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800.withOpacity(0.8)
                          : Colors.grey[100]!.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Ionicons.create_outline,
                      size: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Ionicons.checkmark,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
              if (showDragHandle) ...[
                const SizedBox(width: 8),
                Icon(
                  Ionicons.menu_outline,
                  size: 20,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
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
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return GestureDetector(
        onTap: () => controller.selectDevice(index),
        onLongPress: () =>
            _showNoteEditDialog(context, controller, device),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isDark
                      ? Colors.grey.shade800
                      : Colors.grey.withOpacity(0.2)),
              width: isSelected ? 2 : 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Ionicons.hardware_chip_outline,
                size: 18,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.grey[400] : Colors.grey),
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
                        isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                const Icon(
                  Ionicons.checkmark_circle,
                  size: 16,
                  color: AppTheme.primaryColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '拖动调整顺序',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
    device,
  ) {
    final textController = TextEditingController(text: device.note ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑备注 - ${device.formattedName}'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: '为设备添加备注',
            prefixIcon: Icon(Ionicons.create_outline),
          ),
          maxLength: 20,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              controller.saveDeviceNote(device.id, textController.text);
              Navigator.pop(context);
              Get.snackbar(
                '成功',
                '备注已保存',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 1),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 操作按钮
  Widget _buildActionButton(BuildContext context, HomeController controller) {
    return Obx(() {
      final isDrinking = controller.isDrinking.value;
      final hasDevice = controller.currentDevice != null;
      
      return SizedBox(
        width: double.infinity,
        height: 64,
        child: FilledButton(
          onPressed: hasDevice
              ? (isDrinking ? controller.stopDrinking : controller.startDrinking)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: isDrinking ? Colors.orange : AppTheme.primaryColor,
            disabledBackgroundColor: Colors.grey[300],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isDrinking ? Ionicons.stop_circle : Ionicons.play_circle,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isDrinking ? '结算' : '开始接水',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// 底部功能按钮
  Widget _buildBottomActions(BuildContext context, HomeController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => _showDeviceManageSheet(context, controller),
          icon: const Icon(Ionicons.grid_outline, size: 18),
          label: const Text('管理设备'),
        ),
        const SizedBox(width: 20),
        TextButton.icon(
          onPressed: controller.scanAndAddDevice,
          icon: const Icon(Ionicons.scan_outline, size: 18),
          label: const Text('扫码添加'),
        ),
      ],
    );
  }

  /// 显示设备管理弹窗
  void _showDeviceManageSheet(BuildContext context, HomeController controller) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '设备管理',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text('暂无设备'),
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
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Ionicons.hardware_chip_outline,
                            color: isDark ? Colors.grey[400] : Colors.grey,
                          ),
                        ),
                        title: Text(device.formattedName),
                        subtitle: Text(
                          device.note?.isNotEmpty == true
                              ? '${device.note} · ID: ${device.id}'
                              : 'ID: ${device.id}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Ionicons.trash_outline,
                            color: Colors.red,
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
        title: const Text('确认删除'),
        content: Text('确定要删除设备 "${device.formattedName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.removeDevice(device);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示设置弹窗
  void _showSettingsSheet(BuildContext context, HomeController controller) {
    showCupertinoModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Ionicons.information_circle_outline),
                title: const Text('关于'),
                onTap: () {
                  Navigator.pop(context);
                  _showAboutDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Ionicons.log_out_outline, color: Colors.red),
                title: const Text('退出登录', style: TextStyle(color: Colors.red)),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.water_drop_rounded,
                color: AppTheme.primaryColor,
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
            const Text('版本: 1.0.3'),
            const SizedBox(height: 8),
            const Text('惠生活798喝水功能的第三方客户端'),
            const SizedBox(height: 4),
            Text(
              '官方广告太多，所以做了这个简洁版',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _launchUrl('https://github.com/tunecc/drink_798'),
              child: Row(
                children: [
                  Icon(Ionicons.logo_github, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'GitHub 开源地址',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
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
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('退出'),
          ),
        ],
      ),
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
            speed: _random.nextDouble() * 2 + 1,
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
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.3),
                        AppTheme.primaryColor.withOpacity(0.2),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.3),
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
  final double speed;
  final AnimationController controller;

  _Bubble({
    required this.x,
    required this.size,
    required this.speed,
    required this.controller,
  });
}
