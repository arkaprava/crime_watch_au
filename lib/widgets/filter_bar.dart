import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/crime_incident.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'surface_card.dart';

/// Crime-type and date-range filters in a compact, scrollable panel.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key, this.compact = false});

  final bool compact;

  Future<void> _pickDateRange(BuildContext context, WidgetRef ref) async {
    final filters = ref.read(filtersProvider);
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now,
      initialDateRange: filters.from != null && filters.to != null
          ? DateTimeRange(start: filters.from!, end: filters.to!)
          : null,
    );
    if (range != null) {
      ref.read(filtersProvider.notifier).setDateRange(
            range.start,
            range.end
                .add(const Duration(days: 1))
                .subtract(const Duration(microseconds: 1)),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filtersProvider);
    final dateFormat = DateFormat('d MMM');
    final theme = Theme.of(context);

    final chips = <Widget>[
      _buildFilterChip(
        context: context,
        label: filters.from != null && filters.to != null
            ? '${dateFormat.format(filters.from!)} – ${dateFormat.format(filters.to!)}'
            : 'Date range',
        selected: filters.from != null,
        selectedColor: AppTheme.amber.withValues(alpha: 0.3),
        checkmarkColor: AppTheme.navy,
        avatar: Icon(
          Icons.calendar_month_outlined,
          size: 18,
          color: filters.from != null ? AppTheme.navy : AppTheme.slate,
        ),
        onSelected: (_) => _pickDateRange(context, ref),
      ),
      for (final type in CrimeType.values)
        _buildFilterChip(
          context: context,
          label: type.label,
          selected: filters.types.contains(type),
          selectedColor: type.color.withValues(alpha: 0.22),
          checkmarkColor: type.color,
          avatar: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: type.color,
              shape: BoxShape.circle,
            ),
          ),
          onSelected: (_) => ref.read(filtersProvider.notifier).toggleType(type),
        ),
      if (filters.isActive)
        ActionChip(
          avatar: Icon(Icons.filter_alt_off, size: 16, color: AppTheme.navy),
          label: Text(
            'Clear',
            style: TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppTheme.glassChipFill(theme.brightness),
          side: BorderSide(color: AppTheme.slate.withValues(alpha: 0.28)),
          onPressed: () => ref.read(filtersProvider.notifier).clear(),
        ),
    ];

    if (compact) {
      return SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) => chips[index],
          ),
        ),
      );
    }

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 18, color: AppTheme.slate.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                'Filters',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) => chips[index],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required Color selectedColor,
    required Color checkmarkColor,
    required Widget avatar,
    required ValueChanged<bool> onSelected,
  }) {
    final brightness = Theme.of(context).brightness;
    final chipFill = AppTheme.glassChipFill(brightness);

    return FilterChip(
      avatar: avatar,
      label: Text(
        label,
        style: TextStyle(
          color: selected ? AppTheme.navy : AppTheme.navy.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: chipFill,
      selectedColor: selectedColor,
      checkmarkColor: checkmarkColor,
      side: BorderSide(
        color: selected
            ? checkmarkColor.withValues(alpha: 0.55)
            : AppTheme.slate.withValues(alpha: 0.28),
        width: selected ? 1.5 : 1,
      ),
      elevation: 0,
      pressElevation: 0,
      showCheckmark: selected,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
