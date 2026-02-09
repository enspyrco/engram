import 'package:flutter/material.dart';

class QualityRatingBar extends StatelessWidget {
  const QualityRatingBar({required this.onRate, super.key});

  final ValueChanged<int> onRate;

  static const _labels = [
    'Blackout',
    'Wrong',
    'Wrong\n(easy)',
    'Hard',
    'Hesitated',
    'Perfect',
  ];

  static const _colors = [
    Colors.red,
    Colors.red,
    Colors.orange,
    Colors.amber,
    Colors.lightGreen,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rate your recall:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(6, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                child: _RatingButton(
                  rating: i,
                  label: _labels[i],
                  color: _colors[i],
                  onTap: () => onRate(i),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final int rating;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rating',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
