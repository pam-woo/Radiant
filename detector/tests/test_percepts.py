import json
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from percepts import (  # noqa: E402
    Detection,
    PerceptBuilder,
    emergency_type,
    lane_of,
    load_lanes,
    normalize,
    point_in_polygon,
)

LANES_FILE = os.path.join(os.path.dirname(__file__), "..", "lanes.example.json")


def car(x, y, conf=0.9, label="car"):
    return Detection(label, conf, x, y)


class GeometryTests(unittest.TestCase):
    def test_point_in_square(self):
        square = [(0, 0), (1, 0), (1, 1), (0, 1)]
        self.assertTrue(point_in_polygon(0.5, 0.5, square))
        self.assertFalse(point_in_polygon(1.5, 0.5, square))

    def test_example_lanes_split_the_frame(self):
        lanes = load_lanes(LANES_FILE)
        self.assertEqual(lane_of(car(0.5, 0.1), lanes), "north")
        self.assertEqual(lane_of(car(0.5, 0.9), lanes), "south")
        self.assertEqual(lane_of(car(0.1, 0.5), lanes), "west")
        self.assertEqual(lane_of(car(0.9, 0.5), lanes), "east")

    def test_lanes_file_must_define_every_lane(self, ):
        path = os.path.join(os.path.dirname(__file__), "_bad_lanes.json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({"north": [[0, 0], [1, 0], [1, 1]]}, handle)
        try:
            with self.assertRaises(ValueError):
                load_lanes(path)
        finally:
            os.remove(path)


class ClassNameTests(unittest.TestCase):
    def test_normalize(self):
        self.assertEqual(normalize("Fire Truck"), "firetruck")
        self.assertEqual(normalize("fire_truck"), "firetruck")

    def test_emergency_types(self):
        self.assertEqual(emergency_type("ambulance"), "ambulance")
        self.assertEqual(emergency_type("Fire truck"), "fire_truck")
        self.assertEqual(emergency_type("fire-engine"), "fire_truck")

    def test_police_cars_are_not_emergency(self):
        self.assertIsNone(emergency_type("police car"))
        self.assertIsNone(emergency_type("car"))


class PerceptBuilderTests(unittest.TestCase):
    def setUp(self):
        self.lanes = load_lanes(LANES_FILE)

    def second(self, builder, t, frames):
        for detections in frames:
            builder.add_frame(detections)
        return builder.finish_second(t)

    def test_counts_use_the_median_of_the_frames(self):
        builder = PerceptBuilder(self.lanes)
        two = [car(0.5, 0.1), car(0.45, 0.1)]
        three = two + [car(0.55, 0.1)]
        percept = self.second(builder, 0, [two, three, two])
        self.assertEqual(percept["counts"]["north"], 2)
        self.assertEqual(percept["counts"]["south"], 0)
        self.assertIsNone(percept["emergency"])

    def test_low_confidence_detections_are_ignored(self):
        builder = PerceptBuilder(self.lanes, min_confidence=0.5)
        percept = self.second(builder, 0, [[car(0.5, 0.1, conf=0.3)]] * 3)
        self.assertEqual(percept["counts"]["north"], 0)

    def test_emergency_needs_two_seconds_in_a_row(self):
        builder = PerceptBuilder(self.lanes, confirm_seconds=2)
        frames = [[car(0.2, 0.5, label="ambulance")]] * 3

        first = self.second(builder, 0, frames)
        self.assertIsNone(first["emergency"])

        second = self.second(builder, 1, frames)
        self.assertEqual(second["emergency"]["lane"], "west")
        self.assertEqual(second["emergency"]["type"], "ambulance")

    def test_a_single_flicker_does_not_alert(self):
        builder = PerceptBuilder(self.lanes, confirm_seconds=2)
        seen = [[car(0.2, 0.5, label="ambulance")]] * 3
        empty = [[]] * 3
        self.assertIsNone(self.second(builder, 0, seen)["emergency"])
        self.assertIsNone(self.second(builder, 1, empty)["emergency"])
        self.assertIsNone(self.second(builder, 2, seen)["emergency"])

    def test_emergency_is_held_briefly_then_cleared(self):
        builder = PerceptBuilder(self.lanes, confirm_seconds=1, hold_seconds=2)
        seen = [[car(0.2, 0.5, label="ambulance")]] * 3
        empty = [[]] * 3

        self.assertIsNotNone(self.second(builder, 0, seen)["emergency"])
        self.assertIsNotNone(self.second(builder, 1, empty)["emergency"])
        self.assertIsNotNone(self.second(builder, 2, empty)["emergency"])
        self.assertIsNone(self.second(builder, 3, empty)["emergency"])

    def test_emergency_vehicle_is_part_of_the_lane_count(self):
        builder = PerceptBuilder(self.lanes, confirm_seconds=1)
        percept = self.second(
            builder, 0, [[car(0.2, 0.5, label="ambulance")]] * 3
        )
        self.assertEqual(percept["counts"]["west"], 1)

    def test_fire_truck_is_reported(self):
        builder = PerceptBuilder(self.lanes, confirm_seconds=1)
        percept = self.second(
            builder, 0, [[car(0.5, 0.9, label="fire truck")]] * 3
        )
        self.assertEqual(percept["emergency"]["type"], "fire_truck")
        self.assertEqual(percept["emergency"]["lane"], "south")

    def test_police_car_is_counted_but_not_an_emergency(self):
        builder = PerceptBuilder(self.lanes, confirm_seconds=1)
        percept = self.second(
            builder, 0, [[car(0.9, 0.5, label="police car")]] * 3
        )
        self.assertEqual(percept["counts"]["east"], 1)
        self.assertIsNone(percept["emergency"])

    def test_output_is_valid_json_lines(self):
        builder = PerceptBuilder(self.lanes)
        percept = self.second(builder, 5, [[car(0.5, 0.1)]] * 3)
        decoded = json.loads(json.dumps(percept))
        self.assertEqual(decoded["t"], 5)
        self.assertEqual(set(decoded["counts"]), {"north", "south", "east", "west"})


if __name__ == "__main__":
    unittest.main()
