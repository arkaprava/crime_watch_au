import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/crime_incident.dart';
import '../theme/app_theme.dart';

/// Bottom sheet showing full details for a single incident or aggregate record.
class IncidentDetailSheet extends StatelessWidget {
  const IncidentDetailSheet({super.key, required this.incident});

  final CrimeIncident incident;

  static Future<void> show(BuildContext context, CrimeIncident incident) {
    return showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => IncidentDetailSheet(incident: incident),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEE d MMM yyyy, h:mm a');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: incident.type.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    incident.isAggregate
                        ? Icons.analytics_outlined
                        : Icons.shield_moon_outlined,
                    color: incident.type.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        incident.type.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: incident.type.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        incident.locationLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _SeverityPill(
                  label: incident.severityLabel,
                  color: incident.type.color,
                ),
              ],
            ),
            if (incident.isAggregate || incident.granularityLabel != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (incident.granularityLabel != null)
                    _InfoChip(
                      icon: Icons.layers_outlined,
                      label: incident.granularityLabel!,
                    ),
                  if (incident.offenceCount != null)
                    _InfoChip(
                      icon: Icons.numbers,
                      label:
                          '${incident.offenceCount} offence${incident.offenceCount == 1 ? '' : 's'}',
                    ),
                  if (incident.reportingPeriodLabel != null)
                    _InfoChip(
                      icon: Icons.calendar_month_outlined,
                      label: incident.reportingPeriodLabel!,
                    ),
                  if (incident.geocodeStatus != null)
                    _InfoChip(
                      icon: Icons.location_searching,
                      label: incident.geocodeStatus!.label,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (incident.granularity == RecordGranularity.suburbAggregate &&
                incident.reportingPeriodLabel != null)
              _DetailRow(
                icon: Icons.date_range_outlined,
                label: 'Reporting period',
                value: incident.reportingPeriodLabel!,
              )
            else
              _DetailRow(
                icon: Icons.schedule_outlined,
                label: 'Occurred',
                value: dateFormat.format(incident.occurredAt.toLocal()),
              ),
            if (incident.showsCoordinateDetails) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.pin_drop_outlined,
                label: incident.coordinateLabel,
                value:
                    '${incident.latitude!.toStringAsFixed(4)}, ${incident.longitude!.toStringAsFixed(4)}',
              ),
            ],
            if (incident.source != null) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.source_outlined,
                label: 'Source',
                value: incident.source!,
              ),
            ],
            if (incident.description != null) ...[
              const SizedBox(height: 20),
              Text(
                incident.isAggregate ? 'Summary' : 'What happened',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.mist,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  incident.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.mist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.slate),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SeverityPill extends StatelessWidget {
  const _SeverityPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.slate.withValues(alpha: 0.8)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
