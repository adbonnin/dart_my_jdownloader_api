part of '_models.dart';

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.status,
  });

  final String id;
  final String name;
  final String status;

  Device.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        name = json['name'] as String,
        status = json['status'] as String? ?? 'UNKNOWN';

  static List<Device> fromJsonList(List<dynamic> list) => //
      list.map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
}
