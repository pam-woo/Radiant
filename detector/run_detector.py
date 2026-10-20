"""Run the trained detector on a video and write one percept per second.

    python run_detector.py --video junction.mp4 --weights best.pt \
        --lanes lanes.json --out detections.jsonl --preview preview.mp4

The output is read by the simulator:

    dart run bin/run.dart --replay detections.jsonl --replay-intersection 1
"""
import argparse
import json

import cv2
import numpy as np
from ultralytics import YOLO

from percepts import LANES, Detection, PerceptBuilder, load_lanes

LANE_COLORS = {
    "north": (255, 160, 0),
    "south": (0, 200, 255),
    "east": (0, 220, 0),
    "west": (200, 0, 200),
}


def draw_preview(frame, lanes, boxes):
    height, width = frame.shape[:2]
    for lane in LANES:
        points = [(int(x * width), int(y * height)) for x, y in lanes[lane]]
        cv2.polylines(frame, [np.array(points)], True, LANE_COLORS[lane], 2)
        cv2.putText(frame, lane, points[0], cv2.FONT_HERSHEY_SIMPLEX, 0.7, LANE_COLORS[lane], 2)
    for (x1, y1, x2, y2, label, conf) in boxes:
        cv2.rectangle(frame, (x1, y1), (x2, y2), (255, 255, 255), 2)
        cv2.putText(frame, f"{label} {conf:.2f}", (x1, max(14, y1 - 6)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", required=True)
    parser.add_argument("--weights", required=True)
    parser.add_argument("--lanes", default="lanes.example.json")
    parser.add_argument("--out", default="detections.jsonl")
    parser.add_argument("--conf", type=float, default=0.35)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--samples-per-second", type=int, default=3,
                        help="how many frames to analyse each second")
    parser.add_argument("--preview", help="optional output video with lanes and boxes drawn")
    args = parser.parse_args()

    lanes = load_lanes(args.lanes)
    model = YOLO(args.weights)
    builder = PerceptBuilder(lanes)

    capture = cv2.VideoCapture(args.video)
    if not capture.isOpened():
        raise SystemExit(f"Could not open video: {args.video}")
    fps = capture.get(cv2.CAP_PROP_FPS) or 30.0
    frames_per_second = max(1, int(round(fps)))
    sample_every = max(1, int(round(fps / args.samples_per_second)))

    writer = None
    if args.preview:
        width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
        writer = cv2.VideoWriter(
            args.preview, cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height)
        )

    second = 0
    frame_index = 0
    boxes_for_preview = []

    with open(args.out, "w", encoding="utf-8") as out:
        while True:
            ok, frame = capture.read()
            if not ok:
                break

            if frame_index % sample_every == 0:
                result = model.predict(frame, conf=args.conf, imgsz=args.imgsz, verbose=False)[0]
                height, width = frame.shape[:2]
                detections = []
                boxes_for_preview = []
                for box in result.boxes:
                    label = result.names[int(box.cls[0])]
                    confidence = float(box.conf[0])
                    x1, y1, x2, y2 = (float(v) for v in box.xyxy[0].tolist())
                    detections.append(
                        Detection(label, confidence, ((x1 + x2) / 2) / width, y2 / height)
                    )
                    boxes_for_preview.append(
                        (int(x1), int(y1), int(x2), int(y2), label, confidence)
                    )
                builder.add_frame(detections)

            if writer is not None:
                draw_preview(frame, lanes, boxes_for_preview)
                writer.write(frame)

            frame_index += 1
            if frame_index % frames_per_second == 0:
                out.write(json.dumps(builder.finish_second(second)) + "\n")
                second += 1

        if frame_index % frames_per_second != 0:
            out.write(json.dumps(builder.finish_second(second)) + "\n")
            second += 1

    capture.release()
    if writer is not None:
        writer.release()
    print(f"Wrote {second} seconds of detections to {args.out}")


if __name__ == "__main__":
    main()
