import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/widgets/gadesk_surface.dart';
import 'package:flutter_hbb/common/widgets/gadesk_empty_state.dart';

void main() {
  testWidgets(
      'empty state remains readable in a narrow, short viewport with large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
        child: child!,
      ),
      home: const Scaffold(
        body: SizedBox(
          height: 260,
          child: GadeskSurface(
            child: GadeskEmptyState(
              title: 'No hay conexiones recientes',
              description:
                  'Cuando te conectes a otros equipos, aparecerán aquí.',
              icon: Icons.schedule_rounded,
            ),
          ),
        ),
      ),
    ));
    await tester.ensureVisible(
        find.text('Cuando te conectes a otros equipos, aparecerán aquí.'));
    expect(tester.takeException(), isNull);
    expect(find.text('No hay conexiones recientes'), findsOneWidget);
  });

  testWidgets('dark surface preserves a working child action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: GadeskSurface(
          accent: true,
          child: TextButton(
              onPressed: () => taps++, child: const Text('Conectar')),
        ),
      ),
    ));
    await tester.tap(find.text('Conectar'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  test('GADESK theme fallback preserves explicit and other-app preferences',
      () {
    expect(gadeskThemePreference('GADESK', ''), ThemeMode.light);
    expect(gadeskThemePreference('GADESK', 'dark'), ThemeMode.dark);
    expect(gadeskThemePreference('GADESK', 'light'), ThemeMode.light);
    expect(gadeskThemePreference('GADESK', 'system'), ThemeMode.system);
    expect(gadeskThemePreference('RustDesk', ''), ThemeMode.system);
  });
}
