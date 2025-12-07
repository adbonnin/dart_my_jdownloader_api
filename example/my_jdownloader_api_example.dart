import 'dart:io';

import 'package:my_jdownloader_api/my_jdownloader_api.dart' as jd;

Future<void> main() async {
  final email = Platform.environment['EMAIL'];
  final password = Platform.environment['PASSWORD'];

  assert(email != null, 'email must not be null');
  assert(password != null, 'password must not be null');

  jd.Client? client;

  try {
    client = jd.Client.fromCredentials(email!, password!);
    final api = jd.Api(client);

    final device = (await api.listDevices()).firstOrNull;
    stdout.write('device: ${device?.id}:${device?.name}');

    if (device != null) {
      final downloads = (await api.downloads.queryLinks(device.id));
      stdout.write(['downloads: ', ...downloads.map((d) => d.name)].join('\n'));
    }
  } //
  catch (e, st) {
    stderr.writeln('Unexpected error: $e');
    stderr.writeln(st);
  } //
  finally {
    try {
      await client?.close();
    } //
    catch (e) {
      stderr.writeln('Error closing client: $e');
    }
  }
}
