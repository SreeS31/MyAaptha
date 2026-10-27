import 'package:flutter/material.dart';

class TreeScreen extends StatelessWidget {
  final String circleId;

  const TreeScreen({super.key, required this.circleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tree View')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_tree, size: 80, color: Color(0xFF7C3AED)),
            const SizedBox(height: 16),
            Text('Circle: $circleId', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Interactive tree visualization\n(offline sync ready)'),
          ],
        ),
      ),
    );
  }
}
