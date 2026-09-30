# Quadrant watch face (Forerunner 265 / 265S)

A four-stat grid with a thin time, a Body Battery ring around the edge, and
Bluetooth and message indicators beside the date.

## What it shows

- **Top row:** Bluetooth (blue when connected, dim when not), the date, and a
  message icon with a red dot when you have unread notifications
- **Top-left:** heart rate
- **Top-right:** your choice (see below), recovery time by default
- **Bottom-left:** steps
- **Bottom-right:** temperature, with an icon that changes with the weather
- **Ring and blue number:** Body Battery
- **Small gray number:** watch battery (turns red under 15%)

In always-on mode it shows only a dim time that shifts a few pixels each
minute, which protects the AMOLED screen and saves battery.

## Build and install

1. Install **Visual Studio Code** and the **Monkey C** extension from Garmin.
2. Install the **Connect IQ SDK Manager** (developer.garmin.com/connect-iq/sdk),
   sign in, and download the latest SDK plus the **Forerunner 265** device.
3. In VS Code, open the command palette and run
   **Monkey C: Generate a Developer Key** (one time only).
4. Open this `quadrant` folder in VS Code.
5. Optional: run **Monkey C: Run** to preview it in the simulator first.
6. Run **Monkey C: Build for Device**, choose `fr265` (or `fr265s`), and pick
   an output folder. You'll get a `.prg` file.
7. Plug the watch in with USB and copy the `.prg` into `GARMIN/APPS`.
   On a Mac you'll need an MTP app such as OpenMTP to see the watch's files.
8. Unplug, then long-press UP on the watch > Watch Face and select **Quadrant**.

## Changing the top-right field

Sideloaded watch faces don't get a settings screen in Garmin Connect, so set
the default before building. In `resources/settings/properties.xml`, change
the number in `TopRightField`:

| Value | Field |
|---|---|
| 0 | Recovery time (default) |
| 1 | Stress |
| 2 | Intensity minutes this week |
| 3 | Next sunrise or sunset |
| 4 | Floors climbed |
| 5 | Calories |

Then rebuild and copy the new `.prg` over the old one. If you publish it to
the Connect IQ Store later, this becomes a normal setting in the Connect app.

## Tweaking the look

Colors are at the top of `source/QuadrantView.mc` (`C_BLUE`, `C_RED`, etc.).
Layout positions are fractions of the screen size in `onUpdate`.
