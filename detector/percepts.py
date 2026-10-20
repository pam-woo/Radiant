"""Turns object detections into the per-second percepts the Radiant agent reads.

Pure Python (standard library only), so it can be tested without a GPU or a
trained model. The detector scripts feed it detections; it produces one JSON
object per second:

    {"t": 12,
     "counts": {"north": 3, "south": 1, "east": 4, "west": 2},
     "emergency": {"lane": "west", "type": "ambulance", "confidence": 0.93}}

"emergency" is null when there is none.
"""
from __future__ import annotations

import json
import statistics
from dataclasses import dataclass

LANES = ("north", "south", "east", "west")

# Class names (lower case, letters and digits only) that mean "emergency
# vehicle", mapped to the type the agent understands. Police cars are
# deliberately NOT here: the proposal covers ambulances and fire trucks.
EMERGENCY_CLASSES = {
    "ambulance": "ambulance",
    "firetruck": "fire_truck",
    "fireengine": "fire_truck",
}


def normalize(label: str) -> str:
    """'Fire Truck' / 'fire_truck' / 'fire-truck' -> 'firetruck'."""
    return "".join(ch for ch in label.lower() if ch.isalnum())


def emergency_type(label: str):
    return EMERGENCY_CLASSES.get(normalize(label))


@dataclass(frozen=True)
class Detection:
    label: str
    confidence: float
    x: float  # bottom-centre of the box, 0..1 across the frame
    y: float  # bottom-centre of the box, 0..1 down the frame


def point_in_polygon(x: float, y: float, polygon) -> bool:
    """Ray casting test. polygon is a list of (x, y) points."""
    inside = False
    j = len(polygon) - 1
    for i in range(len(polygon)):
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if (yi > y) != (yj > y):
            x_cross = (xj - xi) * (y - yi) / (yj - yi) + xi
            if x < x_cross:
                inside = not inside
        j = i
    return inside


def load_lanes(path: str) -> dict:
    """Reads lane polygons: {"north": [[x, y], ...], ...} in 0..1 coordinates."""
    with open(path, encoding="utf-8") as handle:
        raw = json.load(handle)
    lanes = {lane: [tuple(p) for p in raw[lane]] for lane in LANES if lane in raw}
    missing = [lane for lane in LANES if lane not in lanes]
    if missing:
        raise ValueError(f"lanes file is missing: {', '.join(missing)}")
    return lanes


def lane_of(detection: Detection, lanes: dict):
    for lane in LANES:
        polygon = lanes.get(lane)
        if polygon and point_in_polygon(detection.x, detection.y, polygon):
            return lane
    return None


class PerceptBuilder:
    """Collects detections frame by frame and emits one percept per second.

    Counts use the median across the second's frames, which smooths out a
    missed detection. An emergency vehicle must be seen for
    `confirm_seconds` in a row before it is reported, and is held for
    `hold_seconds` after it disappears, so one wrong frame cannot trigger or
    cancel an alert.
    """

    def __init__(
        self,
        lanes: dict,
        min_confidence: float = 0.4,
        confirm_seconds: int = 2,
        hold_seconds: int = 2,
    ):
        self.lanes = lanes
        self.min_confidence = min_confidence
        self.confirm_seconds = confirm_seconds
        self.hold_seconds = hold_seconds
        self._frames: list = []
        self._streak = 0
        self._missing = 0
        self._active = False
        self._last = None

    def add_frame(self, detections) -> None:
        counts = {lane: 0 for lane in LANES}
        best = None
        for d in detections:
            if d.confidence < self.min_confidence:
                continue
            lane = lane_of(d, self.lanes)
            if lane is None:
                continue
            counts[lane] += 1  # every vehicle counts, emergency ones included
            kind = emergency_type(d.label)
            if kind and (best is None or d.confidence > best[2]):
                best = (lane, kind, d.confidence)
        self._frames.append((counts, best))

    def finish_second(self, t: int) -> dict:
        frames = self._frames or [({lane: 0 for lane in LANES}, None)]
        self._frames = []

        counts = {
            lane: int(round(statistics.median(f[0][lane] for f in frames)))
            for lane in LANES
        }

        seen = [f[1] for f in frames if f[1] is not None]
        candidate = None
        if seen and len(seen) * 2 >= len(frames):  # seen in at least half
            top = max(seen, key=lambda e: e[2])
            candidate = {
                "lane": top[0],
                "type": top[1],
                "confidence": round(top[2], 3),
            }

        emergency = None
        if candidate:
            self._streak += 1
            self._missing = 0
            self._last = candidate
            if self._active or self._streak >= self.confirm_seconds:
                self._active = True
                emergency = candidate
        else:
            self._streak = 0
            if self._active:
                self._missing += 1
                if self._missing <= self.hold_seconds:
                    emergency = self._last
                else:
                    self._active = False

        # The agent expects the emergency vehicle to be part of its lane count.
        if emergency and counts[emergency["lane"]] == 0:
            counts[emergency["lane"]] = 1

        return {"t": t, "counts": counts, "emergency": emergency}
