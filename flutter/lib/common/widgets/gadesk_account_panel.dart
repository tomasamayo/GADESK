import 'package:flutter/material.dart';
import 'gadesk_strings.dart';

class GadeskAccountPanel extends StatelessWidget {
  final bool loading;
  final String? errorMessage;
  final Widget? providerButton;
  final VoidCallback onRetry;
  final String language;

  const GadeskAccountPanel({
    super.key,
    required this.loading,
    required this.errorMessage,
    required this.providerButton,
    required this.onRetry,
    this.language = 'en',
  });

  @override
  Widget build(BuildContext context) {
    String text(String value) => gadeskText(language, value);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xff62d1d1).withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 36, color: Color(0xff008f95)),
          ),
        ),
        const SizedBox(height: 20),
        Text(text('Your first Google sign-in creates your GADESK account.'),
            textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (providerButton != null)
          Center(child: providerButton!),
        if (!loading && (errorMessage != null || providerButton == null)) ...[
          Text(
            errorMessage ??
                text(
                    'Google sign-in is not available yet. You can connect using a remote ID and password.'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(text('Retry')),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          text(
              'Your address book is personal. Remote access still requires permission from the other device.'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
