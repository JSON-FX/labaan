import 'dart:io';

const minimumLineCoverage = 59.0;

void main(List<String> arguments) {
  if (arguments.length > 1) {
    stderr.writeln('Usage: dart run tool/check_coverage.dart [lcov-file]');
    exitCode = 64;
    return;
  }

  final path = arguments.isEmpty ? 'coverage/lcov.info' : arguments.single;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exitCode = 66;
    return;
  }

  try {
    final summary = parseLcov(file.readAsStringSync());
    stdout.writeln(
      'Line coverage: ${summary.percentage.toStringAsFixed(2)}% '
      '(${summary.coveredLines}/${summary.totalLines})',
    );

    if (summary.percentage < minimumLineCoverage) {
      stderr.writeln(
        'Coverage is below the ${minimumLineCoverage.toStringAsFixed(1)}% '
        'minimum.',
      );
      exitCode = 1;
      return;
    }

    stdout.writeln(
      'Coverage meets the ${minimumLineCoverage.toStringAsFixed(1)}% minimum.',
    );
  } on FormatException catch (error) {
    stderr.writeln('Invalid LCOV data in $path: ${error.message}');
    exitCode = 65;
  }
}

CoverageSummary parseLcov(String source) {
  var files = 0;
  var totalLines = 0;
  var coveredLines = 0;

  for (final line in source.split('\n')) {
    if (line.startsWith('SF:')) files++;
    if (line.startsWith('LF:')) {
      totalLines += _parseCount(line, 'LF:');
    }
    if (line.startsWith('LH:')) {
      coveredLines += _parseCount(line, 'LH:');
    }
  }

  if (files == 0 || totalLines == 0) {
    throw const FormatException('no instrumented source lines found');
  }
  if (coveredLines > totalLines) {
    throw const FormatException('covered line count exceeds total line count');
  }

  return CoverageSummary(totalLines: totalLines, coveredLines: coveredLines);
}

int _parseCount(String line, String prefix) {
  final value = int.tryParse(line.substring(prefix.length));
  if (value == null || value < 0) {
    throw FormatException('invalid ${prefix.substring(0, 2)} count: $line');
  }
  return value;
}

class CoverageSummary {
  const CoverageSummary({required this.totalLines, required this.coveredLines});

  final int totalLines;
  final int coveredLines;

  double get percentage => coveredLines * 100 / totalLines;
}
