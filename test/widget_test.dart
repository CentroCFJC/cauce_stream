import 'package:flutter_test/flutter_test.dart';

import 'package:cauce_stream/main.dart';

void main() {
  testWidgets('App shows CAUCE Stream splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CauceStreamApp());

    expect(find.text('CAUCE Stream'), findsOneWidget);
    expect(find.text('Sistema de distribución de contenido'), findsOneWidget);
  });
}
