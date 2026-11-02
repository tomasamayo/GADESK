import 'package:flutter/material.dart';
import 'gadesk_surface.dart';

class GadeskEmptyState extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const GadeskEmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GadeskPalette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minHeight:
                  constraints.hasBoundedHeight ? constraints.maxHeight : 0),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 180,
                      height: 120,
                      child: Stack(children: [
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: GadeskPalette.turquoise.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 34,
                          bottom: 17,
                          child: Container(
                            width: 112,
                            height: 78,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: colors.muted.withOpacity(0.65),
                                  width: 3),
                            ),
                            child: Icon(icon, size: 36, color: colors.muted),
                          ),
                        ),
                        Positioned(
                          bottom: 16,
                          left: 27,
                          right: 27,
                          child: Container(
                            height: 7,
                            decoration: BoxDecoration(
                              color: colors.muted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 0,
                          right: 20,
                          child: Icon(Icons.auto_awesome_rounded,
                              color: GadeskPalette.turquoise, size: 28),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.text, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: colors.muted, height: 1.5)),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
