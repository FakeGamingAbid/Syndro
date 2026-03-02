import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Route handler function type
typedef RouteHandler = Future<void> Function(HttpRequest request);

/// Router for handling HTTP requests with path-based routing.
///
/// This class provides a clean way to route HTTP requests to appropriate
/// handler methods, reducing complexity in the main transfer service.
///
/// ## Usage
///
/// ```dart
/// final router = RequestRouter();
///
/// router.get('/api/info', (request) async {
///   request.response.write('Info');
///   await request.response.close();
/// });
///
/// router.post('/api/data', (request) async {
///   // Handle POST request
/// });
///
/// // In request handler:
/// await router.handle(request);
/// ```
class RequestRouter {
  final Map<String, Map<String, RouteHandler>> _routes = {};

  /// Register a GET route handler
  void get(String path, RouteHandler handler) {
    _register('GET', path, handler);
  }

  /// Register a POST route handler
  void post(String path, RouteHandler handler) {
    _register('POST', path, handler);
  }

  /// Register a PUT route handler
  void put(String path, RouteHandler handler) {
    _register('PUT', path, handler);
  }

  /// Register a DELETE route handler
  void delete(String path, RouteHandler handler) {
    _register('DELETE', path, handler);
  }

  void _register(String method, String path, RouteHandler handler) {
    _routes[method] ??= {};
    _routes[method]![path] = handler;
  }

  /// Register a path prefix handler (matches all paths starting with prefix)
  void getPrefix(String prefix, RouteHandler handler) {
    _registerPrefix('GET', prefix, handler);
  }

  void postPrefix(String prefix, RouteHandler handler) {
    _registerPrefix('POST', prefix, handler);
  }

  void _registerPrefix(String method, String prefix, RouteHandler handler) {
    _routes[method] ??= {};
    // Store with special prefix marker
    _routes[method]!['PREFIX:$prefix'] = handler;
  }

  /// Handle an incoming HTTP request
  ///
  /// Routes the request to the appropriate handler based on method and path.
  /// Returns true if a handler was found and executed, false otherwise.
  Future<bool> handle(HttpRequest request) async {
    final method = request.method;
    final path = request.uri.path;

    // Try exact match first
    final exactHandler = _routes[method]?[path];
    if (exactHandler != null) {
      await _executeHandler(exactHandler, request);
      return true;
    }

    // Try prefix match
    final methodRoutes = _routes[method];
    if (methodRoutes != null) {
      for (final entry in methodRoutes.entries) {
        if (entry.key.startsWith('PREFIX:')) {
          final prefix = entry.key.substring(7);
          if (path.startsWith(prefix)) {
            await _executeHandler(entry.value, request);
            return true;
          }
        }
      }
    }

    return false;
  }

  Future<void> _executeHandler(RouteHandler handler, HttpRequest request) async {
    try {
      await handler(request);
    } catch (e, stackTrace) {
      debugPrint('Error in route handler: $e');
      debugPrint('Stack trace: $stackTrace');
      
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('Internal server error');
        await request.response.close();
      } catch (closeError) {
        debugPrint('Error closing response: $closeError');
      }
    }
  }
}

/// Helper class for parsing request bodies
class RequestParser {
  /// Parse JSON body from request
  static Future<Map<String, dynamic>?> parseJson(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) return null;
      
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      return null;
    }
  }

  /// Validate required fields in parsed JSON
  static bool validateFields(Map<String, dynamic>? data, List<String> requiredFields) {
    if (data == null) return false;
    
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        return false;
      }
    }
    return true;
  }
}

/// Helper class for sending HTTP responses
class ResponseHelper {
  /// Send a JSON response
  static Future<void> sendJson(
    HttpRequest request,
    Map<String, dynamic> data, {
    int statusCode = HttpStatus.ok,
  }) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    await request.response.close();
  }

  /// Send a text response
  static Future<void> sendText(
    HttpRequest request,
    String text, {
    int statusCode = HttpStatus.ok,
  }) async {
    request.response.statusCode = statusCode;
    request.response.write(text);
    await request.response.close();
  }

  /// Send a 404 Not Found response
  static Future<void> sendNotFound(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.notFound;
    request.response.write(message);
    await request.response.close();
  }

  /// Send a 400 Bad Request response
  static Future<void> sendBadRequest(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.badRequest;
    request.response.write(message);
    await request.response.close();
  }

  /// Send a 401 Unauthorized response
  static Future<void> sendUnauthorized(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.write(message);
    await request.response.close();
  }

  /// Send a 500 Internal Server Error response
  static Future<void> sendError(HttpRequest request, String message) async {
    request.response.statusCode = HttpStatus.internalServerError;
    request.response.write(message);
    await request.response.close();
  }
}
