# Detector pipeline (Roboflow dataset to agent)

This folder turns a vehicle detection model into the per-second percepts the
Radiant agent reads. The agent itself is unchanged: it still receives lane
counts and an emergency detection, now from real detections instead of random
traffic.

```
Roboflow dataset --train.py--> best.pt
junction video + lanes.json --run_detector.py--> detections.jsonl
detections.jsonl --simulator --replay--> Supabase --> the app
```

Dataset: "vehicles detection" by finalproject on Roboflow Universe
(CC BY 4.0, so cite it in the paper). It has ambulance but no fire truck.

## 1. Prepare the data (Roboflow)

1. Fork the dataset into your own workspace.
2. Add labeled **fire truck** images (the proposal says the dataset is
   "supplemented with labeled images of ambulances and fire trucks"). Use
   images you are allowed to use, and aim for at least 100 fire trucks and a
   similar number of ambulances. Check the class balance first.
3. Create a version with a train / valid / test split (keep the test split
   untouched until the end), then **Download Dataset -> YOLOv8** and copy the
   download snippet. The snippet contains your API key: never commit it or paste it in chat.

## 2. Train and evaluate (Google Colab, free GPU)

```
pip install -r requirements.txt
python train.py --data <dataset folder>/data.yaml --epochs 60
```

It prints mAP@50, mAP@50-95, precision and recall (overall and per class).
The run folder under `runs/detect/` has the confusion matrix, curves and
`weights/best.pt`. These are the numbers for the paper (objective 6).

## 3. Mark the lanes

`lanes.example.json` splits the frame into four triangles meeting in the
centre, which suits a camera looking down at the middle of a junction. For
other views, edit the polygons: each point is `[x, y]` from 0 to 1 across and
down the frame. A vehicle belongs to the lane its bottom-centre falls in.

## 4. Run the detector on a video

```
python run_detector.py --video junction.mp4 --weights best.pt \
    --lanes lanes.json --out detections.jsonl --preview preview.mp4
```

`preview.mp4` shows the lanes and boxes so you can check the polygons.
Pick a short clip (one or two minutes) that you are allowed to use.

How it turns detections into percepts (`percepts.py`):

- counts are the median over each second's analysed frames
- an emergency vehicle must be seen for 2 seconds in a row to be reported
  and is held 2 seconds after it disappears, so one bad frame cannot raise or cancel an alert
- police cars are counted as vehicles but are not emergency vehicles
- the detector gives no distance, so the replay derives it (300 m, shrinking
  at 15 m/s from first sight)

## 5. Replay it through the system

Copy `detections.jsonl` into `simulator/replay/`, then:

```
cd simulator
dart run bin/run.dart --replay replay/detections.jsonl --replay-intersection 1
```

Intersection 1 now follows the video (looping when it ends); the others stay simulated.

## Try it without a model

`simulator/replay/sample_detections.jsonl` is **synthetic** (made by
`make_sample.py`), only for checking that replay works. Do not present it as detector results.

## Tests

```
python -m unittest discover -s tests
```
These need only the Python standard library.
