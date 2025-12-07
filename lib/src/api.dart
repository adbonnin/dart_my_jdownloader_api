import 'package:my_jdownloader_api/src/client.dart';
import 'package:my_jdownloader_api/src/models/_models.dart';
import 'package:my_jdownloader_api/src/models/download_link.dart';

class Api {
  Api(Client client)
      : _client = client,
        downloads = DownloadsApi(client),
        linkGrabber = LinkGrabberApi(client);

  final Client _client;
  final DownloadsApi downloads;
  final LinkGrabberApi linkGrabber;

  Future<List<Device>> listDevices() async {
    final json = await _client.sendServerRequest('/my/listdevices');
    return Device.fromJsonList(json['list'] as List<dynamic>);
  }
}

class DownloadsApi {
  const DownloadsApi(Client client) //
      : _client = client;

  final Client _client;

  Future<List<DownloadLink>> queryLinks(String deviceId) async {
    final json = await _client.sendDeviceRequest(deviceId, '/downloadsV2/queryLinks', params: {});
    return DownloadLink.fromJsonList(json);
  }
}

class LinkGrabberApi {
  const LinkGrabberApi(Client client) //
      : _client = client;

  final Client _client;

  Future<List<DownloadLink>> queryLinks(String deviceId) async {
    final json = await _client.sendDeviceRequest(deviceId, '/linkgrabberv2/queryLinks', params: {});
    return DownloadLink.fromJsonList(json);
  }

  Future<int> addLinks(
    String deviceId, {
    bool? assignJobId,
    bool? autoExtract,
    bool? autostart,
    String? dataUrls,
    bool? deepDecrypt,
    String? destinationFolder,
    String? downloadPassword,
    String? extractPassword,
    List<String>? links,
    bool? overwritePackagizerRules,
    String? packageName,
    String? priority,
    String? sourceUrl,
  }) async {
    final json = await _client.sendDeviceRequest<Map<String, dynamic>>(
      deviceId,
      '/linkgrabberv2/addLinks',
      params: {
        if (assignJobId != null) 'assignJobID': assignJobId,
        if (autoExtract != null) 'autoExtract': autoExtract,
        if (autostart != null) 'autostart': autostart,
        if (dataUrls != null) 'dataURLs': dataUrls,
        if (deepDecrypt != null) 'deepDecrypt': deepDecrypt,
        if (destinationFolder != null) 'destinationFolder': destinationFolder,
        if (downloadPassword != null) 'downloadPassword': downloadPassword,
        if (extractPassword != null) 'extractPassword': extractPassword,
        if (links != null) 'links': links.join(' '),
        if (overwritePackagizerRules != null) 'overwritePackagizerRules': overwritePackagizerRules,
        if (packageName != null) 'packageName': packageName,
        if (priority != null) 'priority': priority,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      },
    );

    return json['id'] as int;
  }
}
