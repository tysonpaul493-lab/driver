import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liferoute_driver/main.dart';

void main() {
  testWidgets('App loads initial auth gatekeeper smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: A2IDriverApp(),
      ),
    );

    // Initial render shows connection or login gatekeeper
    expect(find.byType(A2IDriverApp), findsOneWidget);
  });
}
