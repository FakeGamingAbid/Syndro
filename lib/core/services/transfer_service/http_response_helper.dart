import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
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

  /// Constant-time comparison of two byte arrays.
  ///
  /// Returns `false` when lengths differ (after processing the full
  /// short array to keep timing flat). This prevents length-based
  /// timing leaks on HMAC or token bytes.
  static bool secureBytesCompare(List<int> a, List<int> b) {
    final lenA = a.length;
    final lenB = b.length;
    if (lenA != lenB) {
      // Iterate through the shorter list to avoid out-of-bounds while
      // keeping the loop count bounded.
      int result = lenA ^ lenB;
      final minLen = lenA < lenB ? lenA : lenB;
      for (int i = 0; i < minLen; i++) {
        result |= a[i] ^ b[i];
      }
      return result == 0;
    }

    int result = 0;
    for (int i = 0; i < lenA; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  /// Derive and verify the bound token for a pinned device.
  ///
  /// `boundToken = HMAC-SHA256(senderToken, pinnedPubKey)` (32 bytes, base64url).
  /// The receiver computes it from the stored pinned public key and the
  /// trusted device's static token, then compares it against the presented
  /// value in constant time.
  ///
  /// Returns `true` when the presented bound token matches.
  static Future<bool> verifyBoundToken({
    required String presentedToken,
    required String trustedDeviceToken,
    required String pinnedPubKeyBase64Url,
  }) async {
    if (pinnedPubKeyBase64Url.isEmpty || trustedDeviceToken.isEmpty) {
      return false;
    }
    if (presentedToken.isEmpty) {
      return false;
    }

    try {
      final hmac = Hmac.sha256();
      final keyBytes = utf8.encode(trustedDeviceToken);
      final secretKey = SecretKey(keyBytes);
      final messageBytes = utf8.encode(pinnedPubKeyBase64Url);

      final mac = await hmac.calculateMac(
        messageBytes,
        secretKey: secretKey,
      );

      return secureTokenCompare(presentedToken, base64Url.encode(mac.bytes));
    } catch (_) {
      return false;
    }
  }
}
