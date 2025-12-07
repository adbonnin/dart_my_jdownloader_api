part of '_models.dart';

class ConnectResponse {
  const ConnectResponse({
    required this.sessionToken,
    required this.regainToken,
  });

  final String sessionToken;
  final String regainToken;

  ConnectResponse.fromJson(Map<String, dynamic> json)
      : sessionToken = json['sessiontoken'] as String,
        regainToken = json['regaintoken'] as String;
}
