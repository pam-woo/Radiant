import 'package:flutter/material.dart';

import '../../data/radiant_repository.dart';
import '../../theme.dart';
import '../../widgets/status_chip.dart';

/// Bottom sheet for choosing which intersection to monitor.
Future<int?> showIntersectionPicker(
  BuildContext context,
  RadiantRepository repo,
  int selected,
) {
  final ids = repo.summaries.isEmpty
      ? [1, 2, 3, 4, 5]
      : [for (final s in repo.summaries) s.id];

  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: RadiantColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select intersection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose which camera view to monitor.',
                style: TextStyle(fontSize: 12, color: RadiantColors.textMuted),
              ),
              const SizedBox(height: 12),
              for (final id in ids)
                _PickerRow(
                  name: repo.summaryFor(id)?.name ?? intersectionName(id),
                  chip: modeLongChip(repo.summaryFor(id)?.mode ?? 'normal'),
                  selected: id == selected,
                  onTap: () => Navigator.of(sheetContext).pop(id),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.name,
    required this.chip,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final ChipStyle chip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: RadiantColors.background,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? RadiantColors.maroonBright
                : RadiantColors.surfaceBorder,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontSize: 13)),
                ),
                StatusChip(chip),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
