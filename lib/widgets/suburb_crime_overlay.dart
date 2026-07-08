import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/crime_incident.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/incident_timeline.dart';
import 'incident_detail_sheet.dart';
import 'incident_timeline_tile.dart';
import 'surface_card.dart';

/// Draggable bottom panel listing crimes for the selected suburb.
class SuburbCrimeOverlay extends ConsumerWidget {
  const SuburbCrimeOverlay({super.key});

  static const _minSize = 0.22;
  static const _initialSize = 0.35;
  static const _maxSize = 0.85;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(activeAreaProvider);
    if (area == null || !area.isActive) return const SizedBox.shrink();

    final incidents = ref.watch(suburbIncidentsProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: _initialSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      snapSizes: const [_minSize, _initialSize, _maxSize],
      builder: (context, scrollController) {
        return SurfaceCard(
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: [
              _Header(
                suburb: area.city!,
                state: area.state,
                incidents: incidents,
                onClose: () =>
                    ref.read(activeAreaProvider.notifier).clear(),
              ),
              const Divider(height: 1),
              Expanded(
                child: incidents.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.amber),
                  ),
                  error: (_, _) => _EmptyMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'Could not load crimes',
                    actionLabel: 'Retry',
                    onAction: () {
                      final area = ref.read(activeAreaProvider);
                      if (area != null) {
                        ref
                            .read(crimeQueryCacheProvider)
                            .invalidateSuburb(area.city!, area.state);
                      }
                      ref.invalidate(suburbIncidentsProvider);
                    },
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _EmptyMessage(
                        icon: Icons.search_off_outlined,
                        title: 'No crimes recorded for this suburb',
                        subtitle: 'Try adjusting filters or another area.',
                      );
                    }

                    final grouped = groupIncidentsByMonth(items);
                    final monthKeys = grouped.keys.toList();

                    return RefreshIndicator(
                      color: AppTheme.amber,
                      onRefresh: () async {
                        final area = ref.read(activeAreaProvider)!;
                        ref
                            .read(crimeQueryCacheProvider)
                            .invalidateSuburb(area.city!, area.state);
                        ref.invalidate(suburbIncidentsProvider);
                        await ref.read(suburbIncidentsProvider.future);
                      },
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _timelineItemCount(grouped, monthKeys),
                        itemBuilder: (context, index) {
                          final item = _resolveTimelineItem(
                            grouped,
                            monthKeys,
                            index,
                          );
                          if (item.isHeader) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 8,
                              ),
                              child: Text(
                                formatMonthHeader(item.monthKey!),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.navy,
                                ),
                              ),
                            );
                          }

                          return IncidentTimelineTile(
                            incident: item.incident!,
                            isFirst: item.isFirstInMonth,
                            isLast: item.isLastInMonth,
                            onTap: () => IncidentDetailSheet.show(
                              context,
                              item.incident!,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static int _timelineItemCount(
    Map<String, List<CrimeIncident>> grouped,
    List<String> monthKeys,
  ) {
    var count = 0;
    for (final key in monthKeys) {
      count += 1 + grouped[key]!.length;
    }
    return count;
  }

  static _TimelineItem _resolveTimelineItem(
    Map<String, List<CrimeIncident>> grouped,
    List<String> monthKeys,
    int index,
  ) {
    var cursor = 0;
    for (final monthKey in monthKeys) {
      if (cursor == index) {
        return _TimelineItem.header(monthKey);
      }
      cursor++;

      final incidents = grouped[monthKey]!;
      for (var i = 0; i < incidents.length; i++) {
        if (cursor == index) {
          return _TimelineItem.incident(
            incident: incidents[i],
            isFirstInMonth: i == 0,
            isLastInMonth: i == incidents.length - 1,
            monthKey: monthKey,
          );
        }
        cursor++;
      }
    }
    throw StateError('Invalid timeline index: $index');
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.suburb,
    required this.state,
    required this.incidents,
    required this.onClose,
  });

  final String suburb;
  final String? state;
  final AsyncValue<List<CrimeIncident>> incidents;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = incidents.value?.length;
    final subtitle = state != null ? '$suburb · $state' : suburb;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.slate.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place, color: AppTheme.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suburb,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      count != null
                          ? '$subtitle · $count record${count == 1 ? '' : 's'}'
                          : subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.slate.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem._({
    this.monthKey,
    this.incident,
    this.isFirstInMonth = false,
    this.isLastInMonth = false,
    required this.isHeader,
  });

  factory _TimelineItem.header(String monthKey) {
    return _TimelineItem._(monthKey: monthKey, isHeader: true);
  }

  factory _TimelineItem.incident({
    required CrimeIncident incident,
    required bool isFirstInMonth,
    required bool isLastInMonth,
    required String monthKey,
  }) {
    return _TimelineItem._(
      monthKey: monthKey,
      incident: incident,
      isFirstInMonth: isFirstInMonth,
      isLastInMonth: isLastInMonth,
      isHeader: false,
    );
  }

  final String? monthKey;
  final CrimeIncident? incident;
  final bool isFirstInMonth;
  final bool isLastInMonth;
  final bool isHeader;
}
