# Device List Order & Dense Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users drag-reorder home devices (persisted locally) and switch between compact single-column and two-column dense layouts.

**Architecture:** Keep order and layout as client-side SharedPreferences preferences (same layer as device notes). After every API load, re-apply `device_order` via a pure `applyDeviceOrder` helper. UI adds header icons for layout toggle and reorder mode; reorder always uses Flutter `ReorderableListView` in single-column form, then restores the preferred layout on exit.

**Tech Stack:** Flutter, GetX, SharedPreferences, ionicons, flutter_test (no new dependencies)

**Spec:** `docs/superpowers/specs/2026-07-14-device-list-order-layout-design.md`

## Global Constraints

- No new third-party packages
- Do not change drink/start/stop/scan/delete API contracts
- Persist only: `device_order` (List<String> ids), `device_list_layout` (`list` | `grid`)
- Reorder mode always uses single-column drag list; layout preference is restored on exit
- While drinking: block entering reorder mode
- After reorder: re-resolve selection by device **id**, never by stale index
- Default layout on first launch: `list` (compact single column)
- Chinese UI copy only where user-facing; code identifiers stay English

## File Map

| File | Responsibility |
|------|----------------|
| `lib/core/utils/device_order.dart` | Pure `applyDeviceOrder` — no Flutter/GetX deps |
| `test/core/utils/device_order_test.dart` | Unit tests for order application |
| `lib/features/home/home_controller.dart` | Prefs load/save, layout mode, reorder mode, apply order after load, `reorderDevices` |
| `lib/features/home/home_page.dart` | Header icons, compact list, grid, reorder UI |

---

### Task 1: Pure order helper + unit tests

**Files:**
- Create: `lib/core/utils/device_order.dart`
- Create: `test/core/utils/device_order_test.dart`

**Interfaces:**
- Consumes: `DeviceModel` from `lib/core/models/device_model.dart`
- Produces:

```dart
/// Reorder [devices] according to [orderIds].
/// - Known ids keep relative order from [orderIds]
/// - Devices not in [orderIds] append in their original relative order
/// - Ids in [orderIds] missing from [devices] are ignored
List<DeviceModel> applyDeviceOrder(
  List<DeviceModel> devices,
  List<String> orderIds,
);
```

- [ ] **Step 1: Write the failing tests**

Create `test/core/utils/device_order_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drink_water_app/core/models/device_model.dart';
import 'package:drink_water_app/core/utils/device_order.dart';

DeviceModel d(String id, String name) => DeviceModel(id: id, name: name);

void main() {
  group('applyDeviceOrder', () {
    test('empty order keeps original order', () {
      final devices = [d('a', 'A'), d('b', 'B'), d('c', 'C')];
      final result = applyDeviceOrder(devices, []);
      expect(result.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('applies full custom order', () {
      final devices = [d('a', 'A'), d('b', 'B'), d('c', 'C')];
      final result = applyDeviceOrder(devices, ['c', 'a', 'b']);
      expect(result.map((e) => e.id).toList(), ['c', 'a', 'b']);
    });

    test('new devices not in order append at end in original relative order', () {
      final devices = [d('a', 'A'), d('b', 'B'), d('c', 'C'), d('d', 'D')];
      final result = applyDeviceOrder(devices, ['c', 'a']);
      expect(result.map((e) => e.id).toList(), ['c', 'a', 'b', 'd']);
    });

    test('stale order ids are ignored', () {
      final devices = [d('a', 'A'), d('b', 'B')];
      final result = applyDeviceOrder(devices, ['x', 'b', 'a', 'y']);
      expect(result.map((e) => e.id).toList(), ['b', 'a']);
    });

    test('does not mutate input list order identity beyond reordering copy', () {
      final devices = [d('a', 'A'), d('b', 'B')];
      final originalIds = devices.map((e) => e.id).toList();
      applyDeviceOrder(devices, ['b', 'a']);
      expect(devices.map((e) => e.id).toList(), originalIds);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/core/utils/device_order_test.dart
```

Expected: FAIL — `device_order.dart` missing / `applyDeviceOrder` not defined.

- [ ] **Step 3: Implement minimal helper**

Create `lib/core/utils/device_order.dart`:

```dart
import '../models/device_model.dart';

/// Reorder [devices] according to [orderIds].
/// - Known ids keep relative order from [orderIds]
/// - Devices not in [orderIds] append in their original relative order
/// - Ids in [orderIds] missing from [devices] are ignored
List<DeviceModel> applyDeviceOrder(
  List<DeviceModel> devices,
  List<String> orderIds,
) {
  if (devices.isEmpty) return <DeviceModel>[];
  if (orderIds.isEmpty) return List<DeviceModel>.from(devices);

  final byId = <String, DeviceModel>{
    for (final device in devices) device.id: device,
  };

  final ordered = <DeviceModel>[];
  final used = <String>{};

  for (final id in orderIds) {
    final device = byId[id];
    if (device == null || used.contains(id)) continue;
    ordered.add(device);
    used.add(id);
  }

  for (final device in devices) {
    if (used.contains(device.id)) continue;
    ordered.add(device);
    used.add(device.id);
  }

  return ordered;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:

```bash
flutter test test/core/utils/device_order_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/device_order.dart test/core/utils/device_order_test.dart
git commit -m "feat: add applyDeviceOrder helper with unit tests"
```

---

### Task 2: Controller — layout preference, order persistence, reorder API

**Files:**
- Modify: `lib/features/home/home_controller.dart`
- Test: manual + existing unit tests still pass (`flutter test test/core/utils/device_order_test.dart`)

**Interfaces:**
- Consumes: `applyDeviceOrder` from Task 1; `SharedPreferences` (existing)
- Produces on `HomeController`:

```dart
/// 'list' | 'grid'
final RxString layoutMode = 'list'.obs;
final RxBool isReordering = false.obs;

Future<void> setLayoutMode(String mode); // only 'list' or 'grid'
void toggleReorderMode();               // no-op / snackbar if drinking
void reorderDevices(int oldIndex, int newIndex);
```

Prefs keys (exact):
- `device_order` → `List<String>`
- `device_list_layout` → `String` (`list` | `grid`)

- [ ] **Step 1: Add imports and reactive fields**

At top of `home_controller.dart`, ensure:

```dart
import '../../core/utils/device_order.dart';
```

Inside `HomeController` class (near other Rx fields):

```dart
/// Device list layout: 'list' (compact single column) or 'grid' (two columns)
final RxString layoutMode = 'list'.obs;

/// Whether the home list is in drag-reorder mode
final RxBool isReordering = false.obs;
```

- [ ] **Step 2: Load layout preference during prefs init**

Replace `_initPrefs` with:

```dart
Future<void> _initPrefs() async {
  _prefs = await SharedPreferences.getInstance();
  final savedLayout = _prefs?.getString('device_list_layout');
  if (savedLayout == 'list' || savedLayout == 'grid') {
    layoutMode.value = savedLayout!;
  }
}
```

- [ ] **Step 3: Apply saved order after notes in `loadDevices`**

In `loadDevices`, after `await _loadDeviceNotes();` and before auto-select first device, insert:

```dart
await _applySavedOrder();
```

Add methods:

```dart
Future<void> _applySavedOrder() async {
  if (_prefs == null) {
    await _initPrefs();
  }
  final order = _prefs?.getStringList('device_order') ?? <String>[];
  if (order.isEmpty) return;

  final selectedId = currentDevice?.id;
  deviceList.value = applyDeviceOrder(deviceList.toList(), order);

  if (selectedId != null) {
    final newIndex = deviceList.indexWhere((d) => d.id == selectedId);
    selectedDeviceIndex.value = newIndex >= 0 ? newIndex : (deviceList.isEmpty ? -1 : 0);
  }
}

Future<void> _saveDeviceOrder() async {
  if (_prefs == null) {
    await _initPrefs();
  }
  final ids = deviceList.map((d) => d.id).toList();
  await _prefs?.setStringList('device_order', ids);
}
```

- [ ] **Step 4: Implement layout + reorder APIs**

```dart
Future<void> setLayoutMode(String mode) async {
  if (mode != 'list' && mode != 'grid') return;
  if (layoutMode.value == mode) return;
  layoutMode.value = mode;
  if (_prefs == null) {
    await _initPrefs();
  }
  await _prefs?.setString('device_list_layout', mode);
}

void toggleReorderMode() {
  if (isDrinking.value) {
    Get.snackbar(
      '提示',
      '正在接水中，请先结算',
      snackPosition: SnackPosition.BOTTOM,
    );
    return;
  }
  if (deviceList.isEmpty) return;
  isReordering.value = !isReordering.value;
}

void reorderDevices(int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= deviceList.length) return;
  // ReorderableListView moves down: adjust index when removing first
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  if (target < 0 || target >= deviceList.length) return;

  final selectedId = currentDevice?.id;
  final item = deviceList.removeAt(oldIndex);
  deviceList.insert(target, item);

  if (selectedId != null) {
    selectedDeviceIndex.value = deviceList.indexWhere((d) => d.id == selectedId);
  }

  _saveDeviceOrder();
}
```

Also update `removeDevice` success path so selection stays id-safe (already mostly is). After successful remove, optionally prune order by calling `_saveDeviceOrder()` so deleted ids leave prefs:

```dart
// inside removeDevice success branch, after deviceList.removeWhere(...):
await _saveDeviceOrder();
```

Ensure `removeDevice` is still `async` and uses `await` if not already for that call.

- [ ] **Step 5: Verify analysis + unit tests**

Run:

```bash
flutter analyze lib/features/home/home_controller.dart lib/core/utils/device_order.dart
flutter test test/core/utils/device_order_test.dart
```

Expected: no errors in those files; unit tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_controller.dart
git commit -m "feat: persist device order and layout mode in home controller"
```

---

### Task 3: Home UI — header controls + dense list/grid layouts

**Files:**
- Modify: `lib/features/home/home_page.dart` (`_buildDeviceSection`, device item builders)

**Interfaces:**
- Consumes: `controller.layoutMode`, `controller.isReordering`, `controller.setLayoutMode`, `controller.toggleReorderMode`
- Produces: compact list + two-column grid UI; header icons for layout and reorder

- [ ] **Step 1: Update device section header**

Replace `_buildDeviceSection` header row so right side has layout toggle, reorder, and add:

```dart
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
                  reordering ? Ionicons.checkmark : Ionicons.swap_vertical_outline,
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
```

Note: `_buildReorderList` is implemented in Task 4; for this task, temporarily call `_buildDeviceCompactList` from the reordering branch **or** implement a stub that returns the compact list — Task 4 replaces it fully. Preferred for clean Task 3 compile: leave reordering branch calling `_buildDeviceCompactList` until Task 4.

- [ ] **Step 2: Implement compact single-column list**

Rename/replace current large-card list with denser version. Keep selection + long-press note + edit button behavior.

```dart
/// Compact single-column device list
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
```

- [ ] **Step 3: Implement two-column grid**

```dart
/// Two-column dense grid
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
```

- [ ] **Step 4: Remove or stop using the old large-card `_buildDeviceGrid` / `_buildDeviceGridItem`**

Delete the old large-padding list builders if unused, or leave temporarily unused and remove after Task 4 to avoid dead code. Prefer delete once compact builders replace them.

- [ ] **Step 5: Static check**

Run:

```bash
flutter analyze lib/features/home/home_page.dart lib/features/home/home_controller.dart
```

Expected: no errors. (Warn-only deprecations like `withOpacity` may already exist project-wide — do not expand cleanup scope.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_page.dart
git commit -m "feat: add compact list and grid layouts with header toggles"
```

---

### Task 4: Home UI — drag reorder mode

**Files:**
- Modify: `lib/features/home/home_page.dart` (add `_buildReorderList`, wire reordering branch)

**Interfaces:**
- Consumes: `controller.reorderDevices`, `controller.isReordering`, `_buildCompactDeviceItem(..., showDragHandle: true)`
- Produces: single-column `ReorderableListView` while reordering

- [ ] **Step 1: Implement reorder list**

```dart
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
```

- [ ] **Step 2: Wire reordering branch in `_buildDeviceSection`**

In the `Obx` body of the device area:

```dart
if (controller.isReordering.value) {
  return _buildReorderList(context, controller);
}
```

(Must come before layout list/grid branches.)

- [ ] **Step 3: Manual verification checklist**

Run the app on a device/simulator:

```bash
flutter run
```

Verify:

1. Default compact single column is denser than before.
2. Layout icon toggles list ↔ grid; kill app and reopen — layout restored.
3. Reorder icon enters mode; list shows drag handles + “拖动调整顺序”.
4. Drag device A above B; exit reorder; order sticks after pull-to-refresh / kill+reopen.
5. Add a new device → appears at end of custom order.
6. Delete a device → remaining order still correct; selection stays valid.
7. Start drinking → reorder icon shows snackbar “正在接水中，请先结算”.
8. In reorder mode, tap does not change selection; long-press does not open note dialog.
9. Selected device remains correct after drag (id-based).

- [ ] **Step 4: Final analyze + unit tests**

```bash
flutter analyze lib/features/home lib/core/utils
flutter test test/core/utils/device_order_test.dart
```

Expected: no new errors; unit tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/home_page.dart
git commit -m "feat: enable drag-to-reorder for home device list"
```

---

## Spec Coverage Checklist

| Spec requirement | Task |
|------------------|------|
| Drag reorder + local persist | Task 1, 2, 4 |
| Compact single column denser list | Task 3 |
| Two-column grid toggle | Task 3 |
| Header icons: layout + sort | Task 3 |
| Sort mode always single-column drag | Task 4 |
| Reorder blocked while drinking | Task 2 |
| New devices append end | Task 1 + Task 2 `_applySavedOrder` |
| Stale order ids ignored | Task 1 |
| Selection by device id after reorder | Task 2 |
| Layout preference persist | Task 2 + Task 3 |
| No new dependencies | Global |
| Optional unit tests for applyDeviceOrder | Task 1 |

## Self-Review Notes

- No TBD/TODO placeholders in tasks.
- Signatures consistent: `applyDeviceOrder`, `setLayoutMode`, `toggleReorderMode`, `reorderDevices`, `layoutMode`, `isReordering`.
- Prefs keys match spec: `device_order`, `device_list_layout`.
- Existing dead `test/widget_test.dart` counter smoke test is out of scope; do not expand to fix unless it blocks CI.
