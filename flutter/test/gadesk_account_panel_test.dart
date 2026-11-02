import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/widgets/gadesk_account_panel.dart';

void main() {
  testWidgets(
      'public Google signup has a working provider action and no password form',
      (tester) async {
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GadeskAccountPanel(
          language: 'es',
          loading: false,
          errorMessage: null,
          providerButton: ElevatedButton(
            onPressed: () => starts++,
            child: const Text('Continuar con Google'),
          ),
          onRetry: () {},
        ),
      ),
    ));
    expect(find.textContaining('primera vez'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('Continuar con Google'));
    expect(starts, 1);
  });

  testWidgets(
      'unavailable provider offers retry instead of a fake sign-in action',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GadeskAccountPanel(
          language: 'es',
          loading: false,
          errorMessage: 'No pudimos conectar con el servidor.',
          providerButton: null,
          onRetry: () => retries++,
        ),
      ),
    ));
    expect(find.text('No pudimos conectar con el servidor.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    await tester.tap(find.text('Reintentar'));
    expect(retries, 1);
  });

  testWidgets(
      'small mobile dialog with large text can scroll to its retry action',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GadeskAccountPanel(
            language: 'es',
            loading: false,
            errorMessage: null,
            providerButton: null,
            onRetry: () {},
          ),
        ),
      ),
    ));
    await tester.ensureVisible(find.text('Reintentar'));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('disponible'), findsOneWidget);
  });
}
