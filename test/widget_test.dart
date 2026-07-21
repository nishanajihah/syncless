// This is a basic Flutter widget test.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncless/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: SynclessApp(),
      ),
    );

    // Verify that our app builds and loads the WorkspacePage.
    expect(find.byType(SynclessApp), findsOneWidget);
  });
}
