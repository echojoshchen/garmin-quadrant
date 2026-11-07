import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;
import Toybox.WatchUi;

// Quadrant watch face for the Forerunner 265 / 265S.
// Layout is expressed as fractions of the screen so it works on both sizes.
(:typecheck(false))
class QuadrantView extends WatchUi.WatchFace {

    // Palette
    const C_WHITE = 0xF2F2F2;
    const C_GRAY  = 0x8A8A8A;
    const C_DIM   = 0x5A5A5A;   // always-on time
    const C_LINE  = 0x333333;   // hairline dividers
    const C_RED   = 0xE24B4A;   // heart, unread dot, low battery

    const GAP = 8;              // space between an icon and its number

    var _icons = {};
    var _timeFont = null;
    var _timeIsVector = false;
    var _sleeping = false;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        _icons = {
            :heart     => WatchUi.loadResource(Rez.Drawables.IconHeart),
            :sun       => WatchUi.loadResource(Rez.Drawables.IconSun),
            :cloud     => WatchUi.loadResource(Rez.Drawables.IconCloud),
            :rain      => WatchUi.loadResource(Rez.Drawables.IconRain),
            :snow      => WatchUi.loadResource(Rez.Drawables.IconSnow),
            :storm     => WatchUi.loadResource(Rez.Drawables.IconStorm),
            :btOn      => WatchUi.loadResource(Rez.Drawables.IconBtOn),
            :btOff     => WatchUi.loadResource(Rez.Drawables.IconBtOff),
            :message   => WatchUi.loadResource(Rez.Drawables.IconMessage)
        };

        // A thin system vector font gives the refined look. If the watch
        // doesn't have one, fall back to the built-in number font.
        var size = (dc.getHeight() * 0.29).toNumber();
        if (Graphics has :getVectorFont) {
            _timeFont = Graphics.getVectorFont({
                :face => ["RobotoCondensedLight", "RobotoCondensedRegular", "RobotoRegular"],
                :size => size
            });
        }
        if (_timeFont != null) {
            _timeIsVector = true;
        } else {
            _timeFont = Graphics.FONT_NUMBER_MEDIUM;
            _timeIsVector = false;
        }
    }

    function onExitSleep() {
        _sleeping = false;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() {
        _sleeping = true;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        var ds = System.getDeviceSettings();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        // AMOLED always-on mode: just a dim time that drifts a few pixels
        // each minute, which keeps Garmin's burn-in protection happy.
        if (_sleeping && (ds has :requiresBurnInProtection) && ds.requiresBurnInProtection) {
            var ct = System.getClockTime();
            var dx = ((ct.min % 5) - 2) * 4;
            var dy = (((ct.min / 5) % 3) - 1) * 4;
            drawTime(dc, cx + dx, cy + dy, C_DIM);
            return;
        }

        drawTopRow(dc, cx, (h * 0.155).toNumber(), w, ds);
        drawGrid(dc, w, h, cx);

        var rowBot = (h * 0.715).toNumber();
        var leftX  = (w * 0.46).toNumber();
        var rightX = (w * 0.54).toNumber();

        // Bottom-left: heart rate
        var hr = getHeartRate();
        drawLeftCell(dc, leftX, rowBot, _icons[:heart], hr == null ? "--" : hr.toString());

        // Bottom-right: weather
        var wx = getWeather(ds);
        drawRightCell(dc, rightX, rowBot, wx[1], wx[0]);

        drawTime(dc, cx, cy, C_WHITE);
        drawBattery(dc, cx, h);
    }

    // ---------- Drawing ----------

    function drawTopRow(dc, cx, y, w, ds) {
        var d = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var txt = d.day_of_week + ", " + d.month + " " + d.day.toString();
        var font = Graphics.FONT_XTINY;

        dc.setColor(C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, font, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var half = dc.getTextWidthInPixels(txt, font) / 2;
        var gap = (w * 0.025).toNumber();

        // Bluetooth: blue when the phone is connected, dim when it isn't
        var bt = ds.phoneConnected ? _icons[:btOn] : _icons[:btOff];
        dc.drawBitmap(cx - half - gap - bt.getWidth(), y - bt.getHeight() / 2, bt);

        // Messages: only shown when there are unread notifications
        if (ds.notificationCount > 0) {
            var m = _icons[:message];
            var mx = cx + half + gap;
            var my = y - m.getHeight() / 2;
            dc.drawBitmap(mx, my, m);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx + m.getWidth() - 2, my + 3, 6);
            dc.setColor(C_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mx + m.getWidth() - 2, my + 3, 4);
        }
    }

    function drawGrid(dc, w, h, cx) {
        var x1 = (w * 0.13).toNumber();
        var x2 = (w * 0.87).toNumber();
        var y1 = (h * 0.34).toNumber();
        var y2 = (h * 0.66).toNumber();

        dc.setColor(C_LINE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(x1, y1, x2, y1);
        dc.drawLine(x1, y2, x2, y2);
        dc.drawLine(cx, y2, cx, (h * 0.77).toNumber());
        dc.setPenWidth(1);
    }

    function drawTime(dc, x, y, color) {
        var ct = System.getClockTime();
        var txt = formatHourMin(ct.hour, ct.min);
        var j = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (_timeIsVector) {
            dc.drawAngledText(x, y, _timeFont, txt, j, 0);
        } else {
            dc.drawText(x, y, _timeFont, txt, j);
        }
    }

    // Watch battery, small and gray (turns red below 25%)
    function drawBattery(dc, cx, h) {
        var batt = System.getSystemStats().battery.toNumber();
        dc.setColor(batt < 25 ? C_RED : C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.81).toNumber(), Graphics.FONT_XTINY, batt.toString() + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Number right-aligned to x, icon to its left
    function drawLeftCell(dc, x, y, icon, text) {
        var font = Graphics.FONT_SMALL;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (icon != null) {
            var tw = dc.getTextWidthInPixels(text, font);
            dc.drawBitmap(x - tw - GAP - icon.getWidth(), y - icon.getHeight() / 2, icon);
        }
    }

    // Number left-aligned to x, icon to its right
    function drawRightCell(dc, x, y, icon, text) {
        var font = Graphics.FONT_SMALL;
        dc.setColor(C_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (icon != null) {
            var tw = dc.getTextWidthInPixels(text, font);
            dc.drawBitmap(x + tw + GAP, y - icon.getHeight() / 2, icon);
        }
    }

    // ---------- Data ----------

    function getHeartRate() {
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentHeartRate != null) {
            return ai.currentHeartRate;
        }
        if (ActivityMonitor has :getHeartRateHistory) {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            var s = it.next();
            if (s != null && s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                return s.heartRate;
            }
        }
        return null;
    }

    // Returns [text, icon]
    function getWeather(ds) {
        var cc = Weather.getCurrentConditions();
        if (cc == null || cc.temperature == null) {
            return ["--", _icons[:cloud]];
        }
        var t = cc.temperature.toFloat();   // always Celsius from the API
        if (ds.temperatureUnits == System.UNIT_STATUTE) {
            t = t * 9.0 / 5.0 + 32.0;
        }
        return [t.format("%.0f") + "°", weatherIcon(cc.condition)];
    }

    function weatherIcon(c) {
        if (c == null) { return _icons[:cloud]; }
        if (c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_MOSTLY_CLEAR || c == Weather.CONDITION_FAIR) {
            return _icons[:sun];
        }
        if (c == Weather.CONDITION_THUNDERSTORMS || c == Weather.CONDITION_SCATTERED_THUNDERSTORMS) {
            return _icons[:storm];
        }
        if (c == Weather.CONDITION_SNOW || c == Weather.CONDITION_LIGHT_SNOW
            || c == Weather.CONDITION_HEAVY_SNOW || c == Weather.CONDITION_WINTRY_MIX) {
            return _icons[:snow];
        }
        if (c == Weather.CONDITION_RAIN || c == Weather.CONDITION_LIGHT_RAIN || c == Weather.CONDITION_HEAVY_RAIN
            || c == Weather.CONDITION_SCATTERED_SHOWERS || c == Weather.CONDITION_DRIZZLE) {
            return _icons[:rain];
        }
        return _icons[:cloud];
    }

    // ---------- Formatting ----------

    // Respects the watch's 12/24-hour setting
    function formatHourMin(hour, min) {
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
            return hour.format("%d") + ":" + min.format("%02d");
        }
        return hour.format("%02d") + ":" + min.format("%02d");
    }

}
