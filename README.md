# ADAPT

A Psychtoolbox-based motion direction discrimination perimetry task. ADAPT maps global motion direction discrimination performance across a grid of locations in the visual field, using gaze-contingent random-dot stimuli with EyeLink fixation enforcement. Developed by the Huxlin Lab for characterizing motion sensitivity inside, along the border of, and outside cortically-induced visual field deficits.

## Overview

Standard perimetry (e.g., Humphrey visual fields) measures luminance detection. ADAPT instead probes **global motion direction discrimination** at systematically sampled visual field locations, giving a finer-grained picture of residual visual function in and around a deficit.

On each trial the program:

1. Places a circular random-dot patch at the next location in the testing grid.
2. Presents coherently moving dots in one of four directions (up, down, left, or right) for a fixed duration.
3. Requires the participant to maintain fixation throughout, monitored in real time by an EyeLink tracker — trials with fixation breaks are aborted and repeated.
4. Collects a four-alternative forced-choice arrow-key response, gives auditory feedback, and logs accuracy, reaction time, location, motion direction, and fixation status.

Each location is tested repeatedly (10 trials per location by default), so per-location performance can be computed offline and compared against the patient's perimetric deficit map.

## Repository Structure

| File | Purpose |
|---|---|
| `ADAPT_Motion.m` | The complete experiment script: builds the testing grid, configures the display and eye tracker, generates random-dot motion stimuli, runs the trial loop, and saves results. |
| `README.md` | This file. |

### External dependencies not included in this repository

`ADAPT_Motion.m` calls three EyeLink helper functions that are **not** part of this repo and must be available on the MATLAB path:

- `setupEyelink(...)` — initializes the tracker, defines the fixation window, runs calibration
- `startStimulusEyelink(...)` — waits for stable fixation and begins recording for a trial
- `duringStimulusEyelink(...)` — checks for fixation breaks during stimulus presentation

## Requirements

- MATLAB
- [Psychtoolbox-3](http://psychtoolbox.org/) (`Screen`, `KbWait`, `KbName`, `Beeper`, `Shuffle`)
- [EyeLink Toolbox](https://www.sr-research.com/) and an SR Research EyeLink eye tracker (the code assumes eye tracking is on; it has not been tested with other trackers)
- The EyeLink helper functions listed above
- A gamma-calibrated display; the script loads a monitor calibration file to apply gamma correction

## Testing Grid

The grid is built from a handful of parameters at the top of the script rather than a fixed coordinate list:

| Parameter | Meaning | Default |
|---|---|---|
| `samplingInterval` | Spacing between test locations, in degrees | `5` |
| `testsPerLoc` | Trials run at each location | `10` |
| `testingDepth` | Number of columns sampled into the deficit | `4` |
| `testingHeight` | Number of rows sampled | `7` |
| `startingX` / `startingY` | Coordinates of the first test location, in degrees | `3` / `-15` |

An extra column is added on the intact side of the vertical meridian to give a within-subject baseline, plus a set of trials along the horizontal meridian. Locations falling outside the Humphrey visual field's tested extent are trimmed. If `Deficit_Side` is `'left'`, the x-coordinates are mirrored.

## Usage

1. Edit the patient and paradigm settings at the top of `ADAPT_Motion.m`:

   | Setting | Description |
   |---|---|
   | `Patient_ID` | Subject/session identifier; also used in the output filename |
   | `Deficit_Side` | `'left'` or `'right'` — which hemifield to test |
   | `Testing_Mode` | `'sequential'` to walk the grid in order, or `'random'` to shuffle trial order |

2. Update the apparatus settings to match your rig — `viewing_dist`, `screen_width`, `resolution`, and `frame_rate`. These drive the degrees-to-pixels conversion, so stimulus size, eccentricity, and dot speed will all be wrong if they don't match the actual setup.

3. Adjust the stimulus parameters if needed: `stimulus_duration`, `aperture_radius`, `dot_density`, `dot_size`, `dot_speed`, `dot_lifetime`, and `trial_angle_range` (the set of motion directions; defaults to the four cardinal directions, with an oblique set available in a comment).

4. Make sure Psychtoolbox, the EyeLink Toolbox, the helper functions, and the monitor calibration file are all on the path, then run:

   ```matlab
   ADAPT_Motion
   ```

5. Press `Escape` during a response window to re-enter EyeLink tracker setup (recalibration).

## Output

Results are saved to `~/Desktop/Subjects` under a filename combining `Patient_ID` and `Testing_Mode`. The `results` matrix has one row per completed trial:

| Column | Contents |
|---|---|
| 1 | Trial number |
| 2 | Stimulus x location (degrees) |
| 3 | Stimulus y location (degrees) |
| 4 | Motion direction (degrees) |
| 5 | Response accuracy (1 = correct, 0 = incorrect) |
| 6 | Fixation maintained flag |

## Notes

- Several paths are hard-coded for the lab's rig — the maintenance folder (`~/Desktop/Matlab Maintenance`), a specific gamma calibration file, and the output directory (`~/Desktop/Subjects`). These need to be changed for any other machine.
- The grid-trimming steps use hard-coded row indices tied to the default grid dimensions. Changing `testingDepth`, `testingHeight`, or `testsPerLoc` will require revisiting those index ranges so the right locations are removed.
- The script assumes eye tracking is active (`ET = 1`). Running without a tracker would need the EyeLink calls guarded or stubbed out.
- Intended for vision science research; not validated as a clinical diagnostic tool.
- This version of ADAPT is the most up to date version used by the Huxlin Lab for ongoing testing. It has undergone minor optimization tweaks from the version used in the upcoming JoV paper.
