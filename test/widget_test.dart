import 'package:flutter_test/flutter_test.dart';
import 'package:mood_sync_new/main.dart'; // Fixed package name

void main() {
  testWidgets('Mood Sync app loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the MyApp widget is present.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
