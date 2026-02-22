import 'package:flutter/material.dart';

import '../../engine/fsrs_engine.dart';

/// 4-button rating bar for FSRS-mode quiz reviews.
///
/// Uses the 4-point FSRS scale (Again / Hard / Good / Easy).
class FsrsRatingBar extends StatelessWidget {
  const FsrsRatingBar({required this.onRate, super.key});

  final ValueChanged<FsrsRating> onRate;

  static const _ratings = [
    (label: 'Again', color: Colors.red, rating: FsrsRating.again),
    (label: 'Hard', color: Colors.orange, rating: FsrsRating.hard),
    (label: 'Good', color: Colors.lightGreen, rating: FsrsRating.good),
    (label: 'Easy', color: Colors.green, rating: FsrsRating.easy),
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
          children: [
            for (var i = 0; i < _ratings.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 4 : 0),
                  child: FilledButton(
                    onPressed: () => onRate(_ratings[i].rating),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ratings[i].color,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _ratings[i].label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
