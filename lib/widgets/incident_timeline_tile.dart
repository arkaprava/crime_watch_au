import 'package:flutter/material.dart';

import '../models/crime_incident.dart';
import '../theme/app_theme.dart';
import '../utils/incident_timeline.dart';

/// A single row in the suburb crime timeline with a vertical rail.
class IncidentTimelineTile extends StatelessWidget {
  const IncidentTimelineTile({
    super.key,
    required this.incident,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final CrimeIncident incident;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  if (!isFirst)
                    Container(
                      width: 2,
                      height: 8,
                      color: AppTheme.slate.withValues(alpha: 0.2),
                    ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: incident.type.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: incident.type.color.withValues(alpha: 0.35),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 24,
                      color: AppTheme.slate.withValues(alpha: 0.2),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: incident.type.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            incident.type.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: incident.type.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _SeverityChip(severity: incident.severity),
                        if (incident.isAggregate) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.analytics_outlined,
                            size: 14,
                            color: AppTheme.slate.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      incident.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatIncidentTimelineLabel(incident),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.slate.withValues(alpha: 0.85),
                      ),
                    ),
                    if (incident.description != null &&
                        incident.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        incident.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final CrimeSeverity severity;

  @override
  Widget build(BuildContext context) {
    return Text(
      severity.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.slate.withValues(alpha: 0.8),
      ),
    );
  }
}
