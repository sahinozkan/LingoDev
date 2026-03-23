import 'package:flutter_test/flutter_test.dart';
import 'package:lingodev/main.dart';

void main() {
  testWidgets('LingoDev app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LingoDev());

    // LoginView'ın yüklendiğini kontrol et
    expect(find.text('LingoDev'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsOneWidget);
  });
}
