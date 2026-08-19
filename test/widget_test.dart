import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meeparking/main.dart';

void main() {
  testWidgets('Mee Parking app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MeeParkingApp()));
    expect(find.text('Mee Parking'), findsOneWidget);
  });
}
