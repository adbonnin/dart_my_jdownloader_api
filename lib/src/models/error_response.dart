part of '_models.dart';

class ErrorResponse {
  const ErrorResponse({
    required this.src,
    required this.type,
  });

  final String src;
  final String type;

  ErrorResponse.fromJson(Map<String, dynamic> json)
      : src = json['src'] as String,
        type = json['type'] as String;
}
