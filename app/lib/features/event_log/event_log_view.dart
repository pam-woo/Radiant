import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/radiant_repository.dart';
import '../../theme.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/status_chip.dart';

/// Event Log body shared by the admin and driver apps: filter chips,
/// intersection summary cards and the event list.
class EventLogView extends StatefulWidget {
  const EventLogView({
    super.key,
    required this.repo,
    this.showMonitorLink = false,
    this.onViewMonitor,
    this.banner,
  });

  final RadiantRepository repo;

  /// Admin only: show "View live monitor >" on each summary card.
  final bool showMonitorLink;
  final ValueChanged<int>? onViewMonitor;

  /// Optional banner above the filters (the driver emergency banner).
  final Widget? banner;

  @override
  State<EventLogView> createState() => _EventLogViewState();
}

class _EventLogViewState extends State<EventLogView> {
  int? _filter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repo,
      builder: (context, _) {
        final summaries = widget.repo.summaries;
        final ids = summaries.isEmpty
            ? [1, 2, 3, 4, 5]
            : [for (final s in summaries) s.id];
        final events = widget.repo.eventsFor(_filter);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (widget.repo.offline) ...[
              const OfflineBanner(),
              const SizedBox(height: 12),
            ],
            if (widget.banner != null) widget.banner!,
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All intersections',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final id in ids)
                    _FilterChip(
                      label: intersectionName(id),
                      selected: _filter == id,
                      onTap: () => setState(() => _filter = id),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SummaryGrid(
              ids: ids,
              repo: widget.repo,
              showMonitorLink: widget.showMonitorLink,
              onViewMonitor: widget.onViewMonitor,
            ),
            const SizedBox(height: 12),
            if (events.isEmpty)
              const _EmptyEvents()
            else
              for (final e in events)
                MergeSemantics(child: _EventTile(event: e)),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? RadiantColors.maroon : RadiantColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? RadiantColors.maroonBright
                : RadiantColors.surfaceBorder,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.ids,
    required this.repo,
    required this.showMonitorLink,
    required this.onViewMonitor,
  });

  final List<int> ids;
  final RadiantRepository repo;
  final bool showMonitorLink;
  final ValueChanged<int>? onViewMonitor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 10.0;
        final half = (constraints.maxWidth - spacing) / 2;
        final oddLast = ids.length.isOdd;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < ids.length; i++)
              SizedBox(
                width: (oddLast && i == ids.length - 1)
                    ? constraints.maxWidth
                    : half,
                child: _SummaryCard(
                  id: ids[i],
                  summary: repo.summaryFor(ids[i]),
                  showMonitorLink: showMonitorLink,
                  onViewMonitor: onViewMonitor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.id,
    required this.summary,
    required this.showMonitorLink,
    required this.onViewMonitor,
  });

  final int id;
  final IntersectionSummary? summary;
  final bool showMonitorLink;
  final ValueChanged<int>? onViewMonitor;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 11, color: RadiantColors.textMuted);
    final s = summary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RadiantColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RadiantColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s?.name ?? intersectionName(id),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          StatusChip(modeChip(s?.mode ?? 'normal'), compact: true),
          const SizedBox(height: 8),
          Text('Vehicles today  ${thousands(s?.vehiclesToday ?? 0)}',
              style: muted),
          const SizedBox(height: 2),
          Text('Emergency alerts  ${s?.emergencyAlertsToday ?? 0}',
              style: muted),
          if (showMonitorLink) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => onViewMonitor?.call(id),
              child: const Text(
                'View live monitor >',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: RadiantColors.yellow,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RadiantColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RadiantColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  clockLabel(event.occurredAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: RadiantColors.textMuted,
                  ),
                ),
              ),
              StatusChip(eventChip(event.type), compact: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${intersectionName(event.intersectionId)} | ${event.lane}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            event.description,
            style: const TextStyle(fontSize: 12, color: RadiantColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyEvents extends StatelessWidget {
  const _EmptyEvents();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: RadiantColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RadiantColors.surfaceBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.list, color: RadiantColors.textMuted),
          SizedBox(height: 8),
          Text(
            'No events yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Events appear here when the system adjusts signals or detects '
            'an emergency vehicle.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: RadiantColors.textMuted),
          ),
        ],
      ),
    );
  }
}
