import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const publicHelpEmail = 'Help@myaaptha.com';

class SupportContactCard extends StatelessWidget {
  const SupportContactCard({super.key});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Support & privacy',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('For support or privacy enquiries, email:'),
            const SelectableText(publicHelpEmail),
            TextButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy email address'),
              onPressed: () async {
                try {
                  await Clipboard.setData(
                      const ClipboardData(text: publicHelpEmail));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email address copied.')),
                  );
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Could not copy. Select the email address to copy it.')),
                  );
                }
              },
            ),
          ]),
        ),
      );
}
