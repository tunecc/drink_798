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
