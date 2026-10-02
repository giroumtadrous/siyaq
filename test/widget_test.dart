import 'package:flutter_test/flutter_test.dart';
import 'package:siyaq/data/curriculum.dart';

void main() {
  test('every grade has at least one subject', () {
    for (final s in stages) {
      for (final g in s.grades) {
        expect(g.subjects, isNotEmpty, reason: g.name);
      }
    }
  });
}
