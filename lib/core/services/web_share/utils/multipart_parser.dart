import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Represents a single part from multipart form data
class MultipartPart {
  final String? filename;
  final List<int> data;

  MultipartPart({this.filename, required this.data});
}

/// Utility class for parsing multipart form data
class MultipartParser {
  /// Parse multipart form data from bytes
  static List<MultipartPart> parse(List<int> bytes, String boundary) {
    final parts = <MultipartPart>[];
    final boundaryBytes = utf8.encode('--$boundary');

    int start = 0;

    while (true) {
      final boundaryIndex = _indexOf(bytes, boundaryBytes, start);
      if (boundaryIndex == -1) break;

      if (start > 0) {
        // Extract part data (excluding CRLF before boundary)
        final partBytes = bytes.sublist(start, boundaryIndex - 2);
        final part = _parsePart(partBytes);
        if (part != null) parts.add(part);
      }

      start = boundaryIndex + boundaryBytes.length + 2;

      // Check for final boundary (--boundary--)
      if (start < bytes.length - 2 &&
          bytes[start - 2] == 45 &&
          bytes[start - 1] == 45) {
        break;
      }
    }

    return parts;
  }

  /// Find pattern in bytes starting from given index
  static int _indexOf(List<int> bytes, List<int> pattern, int start) {
    for (int i = start; i <= bytes.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// Parse a single multipart part
  /// FIX (Bug #19): Parse headers from raw bytes to avoid UTF-8 corruption of binary data
  static MultipartPart? _parsePart(List<int> bytes) {
    // Find the header/body separator (\r\n\r\n) by scanning raw bytes
    int separatorIndex = -1;
    for (int i = 0; i <= bytes.length - 4; i++) {
      if (bytes[i] == 13 &&     // \r
          bytes[i + 1] == 10 && // \n
          bytes[i + 2] == 13 && // \r
          bytes[i + 3] == 10) { // \n
        separatorIndex = i;
        break;
      }
    }

    if (separatorIndex == -1) return null;

    // Only decode the headers portion as UTF-8 (headers are always ASCII-safe)
    final headerBytes = bytes.sublist(0, separatorIndex);
    final bodyBytes = bytes.sublist(separatorIndex + 4);

    final headers = utf8.decode(headerBytes, allowMalformed: true);

    String? filename;
    final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(headers);
    if (filenameMatch != null) {
      filename = filenameMatch.group(1);
      // Decode URL-encoded filename
      try {
        filename = Uri.decodeComponent(filename!);
      } catch (e) {
        debugPrint('Error decoding filename: $e');
        // Keep original filename if decoding fails
      }
    }

    return MultipartPart(filename: filename, data: bodyBytes);
  }
}
