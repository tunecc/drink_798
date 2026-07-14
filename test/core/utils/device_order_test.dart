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
