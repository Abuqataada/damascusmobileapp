import 'package:flutter_test/flutter_test.dart';

import 'package:webview_wrapper/main.dart';

void main() {
  group('URL routing', () {
    test('keeps app.damascusprojects.com inside the WebView', () {
      expect(
        shouldOpenExternally(Uri.parse('https://app.damascusprojects.com/dashboard')),
        isFalse,
      );
    });

    test('opens external HTTP links outside the WebView', () {
      expect(
        shouldOpenExternally(Uri.parse('https://example.com')),
        isTrue,
      );
    });

    test('opens tel links outside the WebView', () {
      expect(
        shouldOpenExternally(Uri.parse('tel:+2340000000000')),
        isTrue,
      );
    });

    test('keeps data URLs inside the WebView', () {
      expect(
        shouldOpenExternally(Uri.parse('data:text/plain;base64,SGVsbG8=')),
        isFalse,
      );
    });
  });
}
