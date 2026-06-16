/// 设备数据模型
class DeviceModel {
  final String id;
  final String name;
  final String? location;
  final bool isOnline;
  String? note; // 用户备注

  DeviceModel({
    required this.id,
    required this.name,
    this.location,
    this.isOnline = true,
    this.note,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      location: json['location']?.toString(),
      isOnline: json['isOnline'] ?? true,
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'isOnline': isOnline,
      'note': note,
    };
  }

  /// 格式化设备名称 (如: "1栋101" -> "1-101")
  String get formattedName {
    if (name.contains("栋")) {
      return name.replaceAll("栋", "-");
    }
    return name;
  }

  /// 获取设备简短名称
  String get shortName {
    if (formattedName.length > 10) {
      return '${formattedName.substring(0, 10)}...';
    }
    return formattedName;
  }
}
