import 'package:flutter/material.dart';

ThemeMode gadeskThemePreference(String applicationName, String preference) {
  switch (preference) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case '':
      return applicationName == 'GADESK' ? ThemeMode.light : ThemeMode.system;
    default:
      return ThemeMode.system;
  }
}

class GadeskPalette {
  final Color background;
  final Color surface;
  final Color sidebar;
  final Color border;
  final Color text;
  final Color muted;
  static const teal = Color(0xff00999f);
  static const turquoise = Color(0xff62d1d1);
  static const blue = Color(0xff0077ff);

  const GadeskPalette({
    required this.background,
    required this.surface,
    required this.sidebar,
    required this.border,
    required this.text,
    required this.muted,
  });

  static GadeskPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const GadeskPalette(
              background: Color(0xff141a24),
              surface: Color(0xff1d2633),
              sidebar: Color(0xff18212d),
              border: Color(0xff344155),
              text: Color(0xffedf4ff),
              muted: Color(0xffb2c0d3),
            )
          : const GadeskPalette(
              background: Color(0xfff8fbff),
              surface: Colors.white,
              sidebar: Color(0xffeff5fb),
              border: Color(0xffdfe6ef),
              text: Color(0xff172338),
              muted: Color(0xff64748b),
            );
}

class GadeskSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accent;

  const GadeskSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GadeskPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface,
        gradient: accent
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.surface,
                  Color.alphaBlend(GadeskPalette.turquoise.withOpacity(0.18),
                      colors.surface),
                ],
              )
            : null,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
