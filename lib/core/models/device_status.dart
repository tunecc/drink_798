/// 设备运行状态（`ui/app/dev/status` 的解析结果）。
///
/// 服务端字段含义经上游项目实测确认：
/// - `device.status`：设备链路状态，0 表示离线
/// - `device.gene.status`：业务状态，99 空闲、98 禁用、其余视为运行中
class DeviceStatus {
  const DeviceStatus({
    required this.deviceStatus,
    required this.geneStatus,
  });

  /// 设备链路状态，0 表示离线。
  final int deviceStatus;

  /// 业务状态，99 空闲、98 禁用、其余视为运行中。
  final int geneStatus;

  bool get isOffline => deviceStatus == 0;

  bool get isDisabled => geneStatus == 98;

  /// 设备空闲，可以开始接水。
  bool get isAvailable => deviceStatus != 0 && geneStatus == 99;

  factory DeviceStatus.fromJson(dynamic data) {
    if (data is! Map) {
      return const DeviceStatus(deviceStatus: -1, geneStatus: -1);
    }
    final device = data['device'];
    final gene = device is Map ? device['gene'] : null;
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? -1;
    }

    return DeviceStatus(
      deviceStatus: toInt(device is Map ? device['status'] : null),
      geneStatus: toInt(gene is Map ? gene['status'] : null),
    );
  }
}
