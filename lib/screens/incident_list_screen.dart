import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/crime_incident.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_bar.dart';
import '../widgets/incident_card.dart';

/// Scrollable list of incidents for the current map viewport.
class IncidentListScreen extends ConsumerWidget {
  const IncidentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby incidents'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: const FilterBar(compact: true),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: incidents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load incidents',
                actionLabel: 'Retry',
                onAction: () {
                  final bounds = ref.read(viewportProvider);
                  if (bounds != null) {
                    ref.read(crimeQueryCacheProvider).invalidateViewport(
                          bounds: bounds,
                          state: ref.read(filtersProvider).state,
                          area: ref.read(activeAreaProvider),
                        );
                  }
                  ref.invalidate(incidentsProvider);
                },
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.search_off_outlined,
                    title: 'No incidents here',
                    subtitle: 'Pan the map or adjust filters to see more.',
                  );
                }

                final sorted = List<CrimeIncident>.from(items)
                  ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

                return RefreshIndicator(
                  color: AppTheme.amber,
                  onRefresh: () async {
                    final bounds = ref.read(viewportProvider);
                    if (bounds != null) {
                      ref.read(crimeQueryCacheProvider).invalidateViewport(
                            bounds: bounds,
                            state: ref.read(filtersProvider).state,
                            area: ref.read(activeAreaProvider),
                          );
                    }
                    ref.invalidate(incidentsProvider);
                    await ref.read(incidentsProvider.future);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final incident = sorted[index];
                      return IncidentCard(
                        incident: incident,
                        onTap: () => Navigator.of(context).pop(incident),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
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
