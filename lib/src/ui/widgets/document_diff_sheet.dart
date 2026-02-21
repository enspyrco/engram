import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pretty_diff_text/pretty_diff_text.dart';

import '../../providers/document_diff_provider.dart';

const _kAddedColor = Color.fromARGB(255, 139, 197, 139);
const _kRemovedColor = Color.fromARGB(255, 255, 129, 129);

/// Bottom sheet content that shows a visual diff between the previously
/// ingested version and the current version of a document.
class DocumentDiffSheet extends ConsumerWidget {
  const DocumentDiffSheet({super.key, this.scrollController});

  /// When used inside a [DraggableScrollableSheet], pass the sheet's
  /// scroll controller so that scrolling the diff content also controls
  /// the sheet size.
  final ScrollController? scrollController;

  /// Convenience method to fetch a diff and present it in a draggable
  /// bottom sheet.  Call from any screen to avoid duplicating the
  /// boilerplate.
  static void show(
    BuildContext context,
    WidgetRef ref, {
    required String documentId,
  }) {
    ref.read(documentDiffProvider.notifier).fetchDiff(documentId: documentId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder:
                (context, scrollController) =>
                    DocumentDiffSheet(scrollController: scrollController),
          ),
    ).whenComplete(() {
      ref.read(documentDiffProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentDiffProvider);
    final theme = Theme.of(context);

    return switch (state) {
      DocumentDiffIdle() => const SizedBox.shrink(),
      DocumentDiffLoading() => const Padding(
        padding: EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading diff...'),
          ],
        ),
      ),
      DocumentDiffError(:final message) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
      DocumentDiffLoaded(:final oldText, :final newText, :final ingestedAt) =>
        _LoadedDiff(
          oldText: oldText,
          newText: newText,
          ingestedAt: ingestedAt,
          scrollController: scrollController,
        ),
    };
  }
}

class _LoadedDiff extends StatelessWidget {
  const _LoadedDiff({
    required this.oldText,
    required this.newText,
    required this.ingestedAt,
    this.scrollController,
  });

  final String oldText;
  final String newText;
  final DateTime ingestedAt;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Document Changes', style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Since ${DateFormat.yMMMd().format(ingestedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _LegendChip(color: _kAddedColor, label: 'Added'),
              SizedBox(width: 12),
              _LegendChip(color: _kRemovedColor, label: 'Removed'),
            ],
          ),
        ),
        const Divider(height: 24),
        // Diff content
        Flexible(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PrettyDiffText(
              oldText: oldText,
              newText: newText,
              defaultTextStyle:
                  theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ) ??
                  const TextStyle(fontFamily: 'monospace'),
              addedTextStyle: const TextStyle(
                backgroundColor: _kAddedColor,
                fontFamily: 'monospace',
              ),
              deletedTextStyle: const TextStyle(
                backgroundColor: _kRemovedColor,
                decoration: TextDecoration.lineThrough,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
