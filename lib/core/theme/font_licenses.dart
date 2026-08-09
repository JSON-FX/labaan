import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the bundled fonts' Open Font Licenses to Flutter's license registry.
void registerBundledFontLicenses() {
  _register(const [
    'Chakra Petch',
  ], 'assets/fonts/licenses/ChakraPetch-OFL.txt');
  _register(const [
    'IBM Plex Sans',
  ], 'assets/fonts/licenses/IBMPlexSans-OFL.txt');
  _register(const [
    'IBM Plex Mono',
  ], 'assets/fonts/licenses/IBMPlexMono-OFL.txt');
}

void _register(List<String> packages, String asset) {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(asset);
    yield LicenseEntryWithLineBreaks(packages, license);
  });
}
