import 'package:flutter/material.dart';
import '../../common/widgets/gadesk_surface.dart';

class GadeskHomeLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget? content;

  const GadeskHomeLayout({super.key, required this.sidebar, this.content});

  @override
  Widget build(BuildContext context) {
    final colors = GadeskPalette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = (constraints.maxWidth * 0.26).clamp(260.0, 320.0);
      return ColoredBox(
        color: colors.background,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: content == null ? constraints.maxWidth : width,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.sidebar,
                  border: Border(right: BorderSide(color: colors.border)),
                ),
                child: sidebar,
              ),
            ),
            if (content != null) Expanded(child: content!),
          ],
        ),
      );
    });
  }
}

class GadeskConnectionLayout extends StatelessWidget {
  final Widget connectionCard;
  final Widget peers;
  final Widget? status;

  const GadeskConnectionLayout({
    super.key,
    required this.connectionCard,
    required this.peers,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GadeskPalette.of(context);
    final card = Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: connectionCard,
    );
    final peerCard = Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: GadeskSurface(padding: const EdgeInsets.all(16), child: peers),
    );
    final footer = status == null
        ? const SizedBox.shrink()
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: status,
          );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxHeight < 560 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return SingleChildScrollView(
          child: Column(children: [
            card,
            SizedBox(height: 420, child: peerCard),
            footer,
          ]),
        );
      }
      return Column(children: [card, Expanded(child: peerCard), footer]);
    });
  }
}

class GadeskConnectActions extends StatelessWidget {
  final String label;
  final VoidCallback onConnect;
  final Widget menu;

  const GadeskConnectActions({
    super.key,
    required this.label,
    required this.onConnect,
    required this.menu,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 136, maxWidth: 220),
            child: ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: GadeskPalette.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(136, 50),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ),
        const SizedBox(width: 12),
        menu,
      ],
    );
  }
}
