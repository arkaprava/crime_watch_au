import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/area_crime_stats.dart';
import '../models/crime_incident.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

/// Locally stored crime tallies for suburbs and map areas the user has viewed.
///
/// Backed by [storedAreaStatsProvider] / [CrimeLocalDatabase]. Tapping an
/// actionable row pops with the selected [AreaCrimeStats] so the map can
/// re-open it.
class SavedAreasScreen extends ConsumerWidget {
  const SavedAreasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areas = ref.watch(storedAreaStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Saved areas'),
        actions: [
          if (areas.value?.isNotEmpty ?? false)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: () => _confirmClearAll(context, ref),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: areas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load saved areas',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(storedAreaStatsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyState(
              icon: Icons.bookmarks_outlined,
              title: 'No saved areas yet',
              subtitle: 'Search a suburb or pan the map — Crime Watch keeps a '
                  'local tally for each area you view so it is here next time.',
            );
          }

          return RefreshIndicator(
            color: AppTheme.amber,
            onRefresh: () async {
              ref.invalidate(storedAreaStatsProvider);
              await ref.read(storedAreaStatsProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final area = items[index];
                return _AreaStatsCard(
                  area: area,
                  onTap: area.isActionable
                      ? () => Navigator.of(context).pop(area)
                      : null,
                  onDelete: () async {
                    await ref
                        .read(crimeLocalDatabaseProvider)
                        .deleteArea(area.areaKey);
                    ref.invalidate(storedAreaStatsProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear saved areas?'),
        content: const Text(
          'Removes the local crime tallies for every saved suburb and map '
          'area. Live data is not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(crimeLocalDatabaseProvider).clearAreas();
      ref.invalidate(storedAreaStatsProvider);
    }
  }
}

String _relativeUpdated(DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return DateFormat('d MMM yyyy').format(updatedAt);
}

class _AreaStatsCard extends StatelessWidget {
  const _AreaStatsCard({
    required this.area,
    required this.onDelete,
    this.onTap,
  });

  final AreaCrimeStats area;
  final Future<void> Function() onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topTypes = area.typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = topTypes.take(4).toList();
    final extra = topTypes.length - shown.length;

    return Dismissible(
      key: ValueKey(area.areaKey),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      area.isSuburb ? Icons.place_outlined : Icons.map_outlined,
                      size: 20,
                      color: AppTheme.slate,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        area.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${area.totalCount}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        area.totalCount == 1 ? 'record' : 'records',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _relativeUpdated(area.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.slate.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                if (shown.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in shown)
                        _TypeTally(type: entry.key, count: entry.value),
                      if (extra > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '+$extra more',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeTally extends StatelessWidget {
  const _TypeTally({required this.type, required this.count});

  final CrimeType type;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: type.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '${type.label} · $count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
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
            Icon(icon, size: 48, color: AppTheme.slate.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
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
