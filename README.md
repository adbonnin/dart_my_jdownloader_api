# my_jdownloader_api

A Dart client for the MyJDownloader API.

[![Pub](https://img.shields.io/pub/v/my_jdownloader_api.svg)](https://pub.dartlang.org/packages/my_jdownloader_api)

## Getting started

In your library add the following import:

```dart
import 'package:my_jdownloader_api/my_jdownloader_api.dart' as jd;
```

Create a `Client` with your credentials, then build an `Api` instance:

```dart
final client = jd.Client.fromCredentials(email!, password!);
final api = jd.Api(client);
```

List your registered devices:

```dart
final devices = await api.listDevices();
```

This library exposes the main MyJDownloader endpoints and handles authentication, device selection,
and link-related operations.