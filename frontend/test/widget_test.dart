import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('VoiceShield app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceShieldApp());
    expect(find.text('VoiceShield'), findsOneWidget);
  });
}
