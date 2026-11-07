# Quadrant watch face (Forerunner 265 / 265S)

A clean face with a thin time, heart rate and weather below it, and
Bluetooth and message indicators beside the date.

## What it shows

- **Top row:** Bluetooth (blue when connected, dim when not), the date, and a
  message icon with a red dot when you have unread notifications
- **Bottom-left:** heart rate
- **Bottom-right:** temperature, with an icon that changes with the weather
- **Small gray number:** watch battery (turns red under 25%)

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

## Tweaking the look

Colors are at the top of `source/QuadrantView.mc` (`C_WHITE`, `C_RED`, etc.).
Layout positions are fractions of the screen size in `onUpdate`.
