import 'package:flutter_test/flutter_test.dart';
import 'package:afro_korea_pool/main.dart';
import 'package:afro_korea_pool/pages/login_screen.dart'; // import LoginScreen

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App starts and shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AfroKoreaApp());
    await tester.pumpAndSettle();

    // Verify that the LoginScreen is displayed (user not logged in)
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
