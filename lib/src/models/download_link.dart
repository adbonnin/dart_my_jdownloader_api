part of '_models.dart';

class DownloadLink {
  const DownloadLink({
    required this.name,
    required this.packageUuid,
    required this.uuid,
  });

  final String name;
  final int packageUuid;
  final int uuid;

  DownloadLink.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        packageUuid = json['packageUUID'] as int,
        uuid = json['uuid'] as int;

  static List<DownloadLink> fromJsonList(List<dynamic> list) => //
      list.map((e) => DownloadLink.fromJson(e)).toList();
}
