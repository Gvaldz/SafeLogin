import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safelogin/main.dart';

void main() {
  testWidgets('Home counter increments when button is pressed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(usuario: 'admin')),
    );

    expect(find.text('Haz pulsado este boton 0 veces'), findsOneWidget);
    expect(find.text('Haz pulsado este boton 1 veces'), findsNothing);

    await tester.tap(find.text('Pulsar boton'));
    await tester.pump();

    expect(find.text('Haz pulsado este boton 0 veces'), findsNothing);
    expect(find.text('Haz pulsado este boton 1 veces'), findsOneWidget);
  });
}
