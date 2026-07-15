/// 设备数据模型
class DeviceModel {
  final String id;
  final String name;
  String? note; // 用户备注

  DeviceModel({
    required this.id,
    required this.name,
    this.note,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      note: json['note']?.toString(),
    );
  }

  /// 格式化设备名称 (如: "1栋101" -> "1-101")
  String get formattedName {
    if (name.contains("栋")) {
      return name.replaceAll("栋", "-");
    }
    return name;
  }
}
