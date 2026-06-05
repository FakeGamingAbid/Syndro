import 'package:flutter_test/flutter_test.dart';
import 'package:syndro/core/database/database_helper.dart';

void main() {
  group('DatabaseHelper', () {
    test('should be a singleton', () {
      final instance1 = DatabaseHelper.instance;
      final instance2 = DatabaseHelper.instance;
      
      expect(identical(instance1, instance2), isTrue);
    });
  });
}
