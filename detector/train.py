"""Train and evaluate a YOLO vehicle detector on the Roboflow dataset.

Run on a GPU (Google Colab is fine):

    python train.py --data path/to/data.yaml --epochs 60

Results (weights, confusion matrix, curves) are saved under runs/detect/.
"""
import argparse

from ultralytics import YOLO


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data", required=True, help="data.yaml from the Roboflow export")
    parser.add_argument("--model", default="yolov8n.pt", help="starting weights")
    parser.add_argument("--epochs", type=int, default=60)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--name", default="radiant-vehicles")
    args = parser.parse_args()

    model = YOLO(args.model)
    model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        name=args.name,
    )

    # Evaluate on the validation split and print the numbers for the paper.
    metrics = model.val()
    print()
    print(f"mAP@50      : {metrics.box.map50:.3f}")
    print(f"mAP@50-95   : {metrics.box.map:.3f}")
    print(f"precision   : {metrics.box.mp:.3f}")
    print(f"recall      : {metrics.box.mr:.3f}")
    for index, name in metrics.names.items():
        if index < len(metrics.box.maps):
            print(f"  {name:<14} mAP@50-95 {metrics.box.maps[index]:.3f}")
    print("Confusion matrix and curves are in the run folder under runs/detect/.")


if __name__ == "__main__":
    main()
