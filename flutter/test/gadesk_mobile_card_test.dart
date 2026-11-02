import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/mobile/widgets/gadesk_connection_card.dart';

void main() {
  testWidgets(
      'mobile connection stays reachable above keyboard with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var connections = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: GadeskMobileConnectionCard(
            title: 'Controlar escritorio remoto',
            input: const TextField(),
            connectLabel: 'Conectar',
            onConnect: () => connections++,
          ),
        ),
      ),
    ));
    await tester.ensureVisible(find.text('Conectar'));
    await tester.tap(find.text('Conectar'));
    expect(connections, 1);
    expect(tester.takeException(), isNull);
  });
}
