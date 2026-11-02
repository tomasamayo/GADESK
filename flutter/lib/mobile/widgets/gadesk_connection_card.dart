import 'package:flutter/material.dart';
import '../../common/widgets/gadesk_surface.dart';

class GadeskMobileConnectionCard extends StatelessWidget {
  final String title;
  final Widget input;
  final String connectLabel;
  final VoidCallback onConnect;

  const GadeskMobileConnectionCard({
    super.key,
    required this.title,
    required this.input,
    required this.connectLabel,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GadeskPalette.of(context);
    return GadeskSurface(
      accent: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.desktop_windows_outlined,
                color: GadeskPalette.teal),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: colors.text)),
            ),
          ]),
          const SizedBox(height: 14),
          input,
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: GadeskPalette.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 50),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            child: Text(connectLabel, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
