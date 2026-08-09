import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_coverage.dart';

void main() {
  test('aggregates LCOV line totals across source files', () {
    final summary = parseLcov('''
SF:lib/a.dart
LF:10
LH:8
end_of_record
SF:lib/b.dart
LF:5
LH:3
end_of_record
''');

    expect(summary.totalLines, 15);
    expect(summary.coveredLines, 11);
    expect(summary.percentage, closeTo(73.33, 0.01));
  });

  test('rejects LCOV without instrumented source lines', () {
    expect(() => parseLcov('TN:\nend_of_record'), throwsFormatException);
  });

  test('rejects covered counts greater than total counts', () {
    expect(
      () => parseLcov('SF:lib/a.dart\nLF:2\nLH:3\nend_of_record'),
      throwsFormatException,
    );
  });
}
