import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/crime_incident.dart';
import '../theme/app_theme.dart';

/// Shared list tile card for incident summaries.
class IncidentCard extends StatelessWidget {
  const IncidentCard({
    super.key,
    required this.incident,
    required this.onTap,
    this.showChevron = true,
  });

  final CrimeIncident incident;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('d MMM, h:mm a');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: incident.type.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shield_moon_outlined,
                  color: incident.type.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      incident.type.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: incident.type.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      incident.locationLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (incident.isAggregate && incident.offenceCount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${incident.offenceCount} offences · '
                          '${incident.reportingPeriodLabel ?? incident.reportingPeriod ?? 'aggregate'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.slate.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(incident.occurredAt.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SeverityBadge(
                    severity: incident.severityRank,
                    color: incident.type.color,
                  ),
                  if (showChevron) ...[
                    const SizedBox(height: 8),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity, required this.color});

  final int severity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = switch (severity) {
      >= 4 => 'Critical',
      3 => 'High',
      2 => 'Medium',
      _ => 'Low',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
