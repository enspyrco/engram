import 'package:flutter/material.dart';

class QuizCard extends StatelessWidget {
  const QuizCard({
    required this.question,
    this.answer,
    this.index,
    this.total,
    super.key,
  });

  final String question;
  final String? answer;
  final int? index;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index != null && total != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Question ${index! + 1} of $total',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            Text(question, style: theme.textTheme.titleLarge),
            if (answer != null) ...[
              const Divider(height: 32),
              Text(
                answer!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
