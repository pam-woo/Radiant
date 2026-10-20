# Demo script (about 8 minutes)

Before you start: emulator or phone open, simulator running with
`--emergency-boost 10` for at least 2 minutes, app signed out, text size normal.

1. **The problem (1 min).** Fixed-timer signals ignore the traffic and make
   emergency vehicles wait. SmartLight reads the lanes and adapts.
2. **Welcome screen (30 s).** Two roles: authorized user and driver.
3. **Admin sign in (1 min).** Sign in. Show a wrong password error, then the
   correct one. Point out that the sign-in button stays gray until the form is valid.
4. **Monitor (2 min).** Intersection 01: the lane cards, signal countdowns, and
   the agent card. Read one PERCEIVE / DECIDE / ACT line aloud and say it is built
   from the agent's real state each second. Switch to Intersection 04 (empty
   road, flashing yellow, pedestrians cross freely) and 05 (pedestrian crossing).
5. **Emergency (1 min).** When the amber banner appears, show the lane, the
   flashing yellow warning lanes, and the new "Emergency detected" event.
6. **Event Log (30 s).** Filters, summary cards, "View live monitor".
7. **Driver (1 min).** Switch user type, Continue as driver. The red banner and
   the full-screen alert: direction, distance, mini-map, what to do. Tap Got it,
   then show the passed state.
8. **Accessibility (30 s).** Settings: high contrast, text size A+, color-blind-safe signals.
9. **Offline (30 s).** Stop the simulator (Ctrl+C). After about 12 seconds the
   "No connection" banner appears with LAST SAVED data. Restart it to recover.
10. **Detector (1 min, if done).** Show the confusion matrix and the preview video,
    then the replay on Intersection 01.

Say clearly what is simulated: traffic and the camera feed are simulated (or
replayed from detections); the agent, database, login, and app are real.
