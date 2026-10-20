"""Writes a SYNTHETIC replay file so the replay mode can be tried without a
video or a trained model.

The numbers are invented, not model output. Never present this file as
detector results in the paper; use run_detector.py output for that.

    python make_sample.py ../simulator/replay/sample_detections.jsonl
"""
import json
import math
import sys

from percepts import Detection, PerceptBuilder, load_lanes

# One representative spot per lane in the example lane layout.
SPOTS = {
    "north": (0.5, 0.2),
    "south": (0.5, 0.8),
    "west": (0.2, 0.5),
    "east": (0.8, 0.5),
}


def main(path: str) -> None:
    lanes = load_lanes("lanes.example.json")
    builder = PerceptBuilder(lanes)
    with open(path, "w", encoding="utf-8") as out:
        for t in range(180):
            counts = {
                "north": 3 + round(2 * math.sin(t / 14)),
                "south": 2 + round(2 * math.sin(t / 11 + 1)),
                "east": 4 + round(3 * math.sin(t / 17 + 2)),
                "west": 3 + round(2 * math.sin(t / 13 + 3)),
            }
            ambulance_in_west = 70 <= t < 90
            for _ in range(3):  # three analysed frames per second
                detections = []
                for lane, (x, y) in SPOTS.items():
                    for _ in range(counts[lane]):
                        detections.append(Detection("car", 0.9, x, y))
                if ambulance_in_west:
                    detections.append(Detection("ambulance", 0.94, 0.2, 0.5))
                builder.add_frame(detections)
            out.write(json.dumps(builder.finish_second(t)) + "\n")
    print(f"Wrote {path}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "sample_detections.jsonl")
