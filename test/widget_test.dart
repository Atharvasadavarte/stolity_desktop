import 'package:flutter_test/flutter_test.dart';

import 'package:stolity_desktop/main.dart';
import 'package:stolity_desktop/webview_screen.dart';

void main() {
  testWidgets('App loads Stolity webview shell', (WidgetTester tester) async {
    await tester.pumpWidget(const StolityApp());

    expect(find.byType(StolityWebView), findsOneWidget);
  });
}
