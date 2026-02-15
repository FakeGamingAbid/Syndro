import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// HTTP response helper methods for transfer server
class HttpResponseHelper {
  static Future<void> sendResponse(
      HttpRequest request, int statusCode, Map<String, dynamic> body) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  static Future<void> sendNotFound(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.notFound;
    request.response.write(message);
    await request.response.close();
  }

  static Future<void> sendBadRequest(
      HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.write(message);
    await request.response.close();
  }

  static Future<void> sendUnauthorized(
      HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.write(message);
    await request.response.close();
  }

  static Future<void> sendError(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.write(message);
    await request.response.close();
  }

  static Map<String, dynamic>? validateAndParseJson(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return data;
    } catch (e) {
      debugPrint('JSON parse error: $e');
      return null;
    }
  }

  static bool validateTransferData(Map<String, dynamic> data) {
    if (!data.containsKey('senderId') || data['senderId'] is! String) {
      return false;
    }
    if (!data.containsKey('id') || data['id'] is! String) return false;
    if (!data.containsKey('items') || data['items'] is! List) return false;
    if (!data.containsKey('senderToken') || data['senderToken'] is! String) {
      return false;
    }

    final senderId = data['senderId'] as String;
    if (senderId.isEmpty || senderId.length > 100) return false;

    final items = data['items'] as List;
    if (items.isEmpty || items.length > 1000) return false;

    return true;
  }

  static bool secureTokenCompare(String a, String b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
