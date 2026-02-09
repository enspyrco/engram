import 'package:flutter/material.dart';

class MasteryBar extends StatelessWidget {
  const MasteryBar({
    required this.newCount,
    required this.learningCount,
    required this.masteredCount,
    super.key,
  });

  final int newCount;
  final int learningCount;
  final int masteredCount;

  int get _total => newCount + learningCount + masteredCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mastery', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                if (newCount > 0)
                  Expanded(
                    flex: newCount,
                    child: Container(
                      color: Colors.red.shade400,
                      alignment: Alignment.center,
                      child: _label('$newCount'),
                    ),
                  ),
                if (learningCount > 0)
                  Expanded(
                    flex: learningCount,
                    child: Container(
                      color: Colors.amber.shade600,
                      alignment: Alignment.center,
                      child: _label('$learningCount'),
                    ),
                  ),
                if (masteredCount > 0)
                  Expanded(
                    flex: masteredCount,
                    child: Container(
                      color: Colors.green.shade600,
                      alignment: Alignment.center,
                      child: _label('$masteredCount'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legend(Colors.red.shade400, 'New ($newCount)'),
            const SizedBox(width: 16),
            _legend(Colors.amber.shade600, 'Learning ($learningCount)'),
            const SizedBox(width: 16),
            _legend(Colors.green.shade600, 'Mastered ($masteredCount)'),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _legend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
