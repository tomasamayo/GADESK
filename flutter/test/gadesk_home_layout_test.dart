import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/widgets/gadesk_surface.dart';
import 'package:flutter_hbb/desktop/widgets/gadesk_home_layout.dart';

void main() {
  testWidgets(
      'desktop sidebar and Connect remain usable with large text at narrow width',
      (tester) async {
    tester.view.physicalSize = const Size(760, 620);
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
        body: GadeskHomeLayout(
          sidebar: const SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Tu escritorio'),
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: GadeskSurface(
                child: GadeskConnectActions(
                  label: 'Conectar',
                  onConnect: () => connections++,
                  menu: IconButton(
                      onPressed: () {}, icon: const Icon(Icons.expand_more)),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Tu escritorio'), findsOneWidget);
    await tester.tap(find.text('Conectar'));
    expect(connections, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short window scrolls the connection card to its primary action',
      (tester) async {
    tester.view.physicalSize = const Size(600, 400);
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
        body: GadeskHomeLayout(
          sidebar: const SingleChildScrollView(child: Text('Tu escritorio')),
          content: GadeskConnectionLayout(
            connectionCard: GadeskSurface(
              child: Column(children: [
                const Text('Controlar escritorio remoto',
                    style: TextStyle(fontSize: 24)),
                const SizedBox(height: 28),
                const TextField(),
                const SizedBox(height: 20),
                GadeskConnectActions(
                  label: 'Conectar',
                  onConnect: () => connections++,
                  menu: IconButton(
                      onPressed: () {}, icon: const Icon(Icons.expand_more)),
                ),
              ]),
            ),
            peers: const Center(child: Text('No hay conexiones recientes')),
            status: const Text('Listo'),
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
