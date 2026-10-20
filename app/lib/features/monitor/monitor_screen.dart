import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/radiant_repository.dart';
import '../../theme.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/status_chip.dart';
import 'intersection_view.dart';

/// Admin Monitor tab: camera view, lane cards, agent reasoning, latest events.
class MonitorScreen extends StatelessWidget {
  const MonitorScreen({
    super.key,
    required this.repo,
    required this.intersectionId,
  });

  final RadiantRepository repo;
  final int intersectionId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final frame = repo.liveFor(intersectionId);
        final offline = repo.offline;
        final events = repo.eventsFor(intersectionId, limit: 3);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (offline) ...[
              const OfflineBanner(),
              const SizedBox(height: 12),
            ],
            if (frame == null)
              const _Waiting()
            else ...[
              if (frame.mode == 'emergency') ...[
                _EmergencyBanner(frame: frame),
                const SizedBox(height: 12),
              ],
              _CameraCard(frame: frame, offline: offline),
              const SizedBox(height: 12),
              _LaneGrid(frame: frame),
              const SizedBox(height: 12),
              _AgentCard(frame: frame),
              const SizedBox(height: 12),
              _LatestEvents(events: events),
            ],
          ],
        );
      },
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Waiting for live data from the simulator...',
            style: TextStyle(color: RadiantColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({required this.frame});

  final LiveFrame frame;

  @override
  Widget build(BuildContext context) {
    final lane = frame.emergencyLane;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RadiantColors.amber,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EMERGENCY VEHICLE DETECTED',
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${lane == null ? 'An approach' : '${capitalize(lane)} lane'}. '
            'Busy lanes flash yellow, drivers alerted.',
            style: const TextStyle(color: Colors.black, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RadiantColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: RadiantColors.surfaceBorder),
      ),
      child: child,
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.frame, required this.offline});

  final LiveFrame frame;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final walking = frame.crosswalks.entries.any((e) => e.value == 'walk');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CAM-${two(frame.intersectionId)} live feed',
                  style: const TextStyle(
                    fontSize: 11,
                    color: RadiantColors.textMuted,
                  ),
                ),
              ),
              StatusChip(cameraChip(frame.mode, offline: offline)),
            ],
          ),
          const SizedBox(height: 8),
          IntersectionView(frame: frame),
          if (frame.mode == 'idle') ...[
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Pedestrians cross freely',
                style: TextStyle(fontSize: 11, color: RadiantColors.textMuted),
              ),
            ),
          ] else if (walking) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final lane in const ['north', 'south', 'east', 'west'])
                  _CrosswalkChip(
                    label: capitalize(lane),
                    crossing: frame.crosswalks[lane] == 'walk',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CrosswalkChip extends StatelessWidget {
  const _CrosswalkChip({required this.label, required this.crossing});

  final String label;
  final bool crossing;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      crossing
          ? ChipStyle('$label CROSS', RadiantColors.green, Colors.black)
          : ChipStyle('$label WAIT', RadiantColors.red, Colors.white),
      compact: true,
    );
  }
}

class _LaneGrid extends StatelessWidget {
  const _LaneGrid({required this.frame});

  final LiveFrame frame;

  @override
  Widget build(BuildContext context) {
    Widget card(String lane) => Expanded(
          child: _LaneCard(name: lane, info: frame.lane(lane)),
        );

    return Column(
      children: [
        Row(children: [card('north'), const SizedBox(width: 10), card('south')]),
        const SizedBox(height: 10),
        Row(children: [card('east'), const SizedBox(width: 10), card('west')]),
      ],
    );
  }
}

class _LaneCard extends StatelessWidget {
  const _LaneCard({required this.name, required this.info});

  final String name;
  final LaneInfo? info;

  @override
  Widget build(BuildContext context) {
    final lane = info;
    final chip = lane == null
        ? const ChipStyle('--', RadiantColors.disabled, Colors.white)
        : signalChip(lane.signal, lane.secondsRemaining);
    final count = lane?.vehicleCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RadiantColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chip.background, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${name.toUpperCase()} LANE',
            style: const TextStyle(
              fontSize: 10,
              color: RadiantColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count == 1 ? '1 vehicle' : '$count vehicles',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          StatusChip(chip),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.frame});

  final LiveFrame frame;

  @override
  Widget build(BuildContext context) {
    final alerting = frame.mode == 'emergency';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Intelligent Agent',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                alerting
                    ? const ChipStyle('ALERTING', RadiantColors.amber, Colors.black)
                    : const ChipStyle('ACTIVE', RadiantColors.maroon, Colors.white),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AgentLine(
            label: 'PERCEIVE',
            color: RadiantColors.green,
            text: frame.perceive,
          ),
          _AgentLine(
            label: 'DECIDE',
            color: RadiantColors.yellow,
            text: frame.decide,
          ),
          _AgentLine(
            label: 'ACT',
            color: RadiantColors.amber,
            text: frame.act,
          ),
          const SizedBox(height: 4),
          const Wrap(
            spacing: 6,
            children: [
              StatusChip(
                ChipStyle('Min green 5 s', RadiantColors.disabled, Colors.white),
                compact: true,
              ),
              StatusChip(
                ChipStyle('Yellow 3 s', RadiantColors.yellow, Colors.black),
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentLine extends StatelessWidget {
  const _AgentLine({
    required this.label,
    required this.color,
    required this.text,
  });

  final String label;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _LatestEvents extends StatelessWidget {
  const _LatestEvents({required this.events});

  final List<EventItem> events;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest events',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text(
              'No events yet.',
              style: TextStyle(fontSize: 12, color: RadiantColors.textMuted),
            )
          else
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 68,
                      child: Text(
                        clockLabel(e.occurredAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: RadiantColors.textMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
