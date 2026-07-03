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
      FilterChip(
        avatar: Icon(
          Icons.calendar_month_outlined,
          size: 18,
          color: filters.from != null ? AppTheme.navy : AppTheme.slate,
        ),
        label: Text(
          filters.from != null && filters.to != null
              ? '${dateFormat.format(filters.from!)} – ${dateFormat.format(filters.to!)}'
              : 'Date range',
        ),
        selected: filters.from != null,
        onSelected: (_) => _pickDateRange(context, ref),
        selectedColor: AppTheme.amber.withValues(alpha: 0.25),
        checkmarkColor: AppTheme.navy,
      ),
      for (final type in CrimeType.values)
        FilterChip(
          avatar: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: type.color,
              shape: BoxShape.circle,
            ),
          ),
          label: Text(type.label),
          selected: filters.types.contains(type),
          onSelected: (_) => ref.read(filtersProvider.notifier).toggleType(type),
          selectedColor: type.color.withValues(alpha: 0.18),
          checkmarkColor: type.color,
        ),
      if (filters.isActive)
        ActionChip(
          avatar: const Icon(Icons.filter_alt_off, size: 16),
          label: const Text('Clear'),
          onPressed: () => ref.read(filtersProvider.notifier).clear(),
        ),
    ];

    if (compact) {
      return SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) => chips[index],
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
}
