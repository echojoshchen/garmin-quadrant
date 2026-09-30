import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.SensorHistory;
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
    const C_TRACK = 0x1C1C1C;   // empty part of the ring
    const C_BLUE  = 0x85B7EB;   // Body Battery + Bluetooth
    const C_RED   = 0xE24B4A;   // heart + unread dot

    const GAP = 8;              // space between an icon and its number

    var _icons = {};
    var _timeFont = null;
    var _timeIsVector = false;
    var _sleeping = false;
    var _bodyBattery = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        _icons = {
            :heart     => WatchUi.loadResource(Rez.Drawables.IconHeart),
            :walk      => WatchUi.loadResource(Rez.Drawables.IconWalk),
            :flame     => WatchUi.loadResource(Rez.Drawables.IconFlame),
            :sun       => WatchUi.loadResource(Rez.Drawables.IconSun),
            :cloud     => WatchUi.loadResource(Rez.Drawables.IconCloud),
            :rain      => WatchUi.loadResource(Rez.Drawables.IconRain),
            :snow      => WatchUi.loadResource(Rez.Drawables.IconSnow),
            :storm     => WatchUi.loadResource(Rez.Drawables.IconStorm),
            :btOn      => WatchUi.loadResource(Rez.Drawables.IconBtOn),
            :btOff     => WatchUi.loadResource(Rez.Drawables.IconBtOff),
            :message   => WatchUi.loadResource(Rez.Drawables.IconMessage),
            :bolt      => WatchUi.loadResource(Rez.Drawables.IconBolt),
            :recovery  => WatchUi.loadResource(Rez.Drawables.IconRecovery),
            :stress    => WatchUi.loadResource(Rez.Drawables.IconStress),
            :intensity => WatchUi.loadResource(Rez.Drawables.IconIntensity),
            :sunrise   => WatchUi.loadResource(Rez.Drawables.IconSunrise),
            :sunset    => WatchUi.loadResource(Rez.Drawables.IconSunset),
            :floors    => WatchUi.loadResource(Rez.Drawables.IconFloors)
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

        var showBB = showBodyBattery();
        if (showBB) {
            drawRing(dc, cx, cy, w);
        }
        drawTopRow(dc, cx, (h * 0.155).toNumber(), w, ds);
        drawGrid(dc, w, h, cx);

        var info = ActivityMonitor.getInfo();
        var rowTop = (h * 0.285).toNumber();
        var rowBot = (h * 0.715).toNumber();
        var leftX  = (w * 0.46).toNumber();
        var rightX = (w * 0.54).toNumber();

        // Top-left: heart rate
        var hr = getHeartRate();
        drawLeftCell(dc, leftX, rowTop, _icons[:heart], hr == null ? "--" : hr.toString());

        // Top-right: user-selectable field
        var tr = getTopRightField(info);
        drawRightCell(dc, rightX, rowTop, tr[1], tr[0]);

        // Bottom-left: steps
        var steps = info.steps;
        drawLeftCell(dc, leftX, rowBot, _icons[:walk], steps == null ? "--" : formatThousands(steps));

        // Bottom-right: weather
        var wx = getWeather(ds);
        drawRightCell(dc, rightX, rowBot, wx[1], wx[0]);

        drawTime(dc, cx, cy, C_WHITE);
        drawBottom(dc, cx, h, showBB);
    }

    // ---------- Drawing ----------

    function drawRing(dc, cx, cy, w) {
        var pen = (w * 0.016).toNumber();
        if (pen < 4) { pen = 4; }
        var r = cx - pen / 2 - 3;

        dc.setPenWidth(pen);
        dc.setColor(C_TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);

        _bodyBattery = latestSample(:bodyBattery);
        if (_bodyBattery != null && _bodyBattery > 0) {
            dc.setColor(C_BLUE, Graphics.COLOR_TRANSPARENT);
            if (_bodyBattery >= 100) {
                dc.drawCircle(cx, cy, r);
            } else {
                // Starts at 12 o'clock and fills clockwise
                var endDeg = 90 - (_bodyBattery * 360 / 100);
                if (endDeg < 0) { endDeg += 360; }
                dc.drawArc(cx, cy, r, Graphics.ARC_CLOCKWISE, 90, endDeg);
            }
        }
        dc.setPenWidth(1);
    }

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
        dc.drawLine(cx, (h * 0.23).toNumber(), cx, y1);
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

    function drawBottom(dc, cx, h, showBB) {
        var y1 = (h * 0.81).toNumber();
        var battY = (h * 0.885).toNumber();

        // When Body Battery is turned off, the watch battery moves up into its place
        if (showBB) {
            drawBodyBatteryNumber(dc, cx, y1);
        } else {
            battY = y1;
        }

        // Watch battery, small and gray (turns red below 15%)
        var batt = System.getSystemStats().battery.toNumber();
        dc.setColor(batt < 15 ? C_RED : C_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, battY, Graphics.FONT_XTINY, batt.toString() + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Body Battery number, blue, with a bolt icon
    function drawBodyBatteryNumber(dc, cx, y1) {
        var bbTxt = _bodyBattery == null ? "--" : _bodyBattery.toString();
        var font = Graphics.FONT_TINY;
        var bolt = _icons[:bolt];
        var tw = dc.getTextWidthInPixels(bbTxt, font);
        var sx = cx - (bolt.getWidth() + 4 + tw) / 2;
        dc.drawBitmap(sx, y1 - bolt.getHeight() / 2, bolt);
        dc.setColor(C_BLUE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(sx + bolt.getWidth() + 4, y1, font, bbTxt, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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

    // Defaults to on if the setting can't be read
    function showBodyBattery() {
        try {
            var v = Application.Properties.getValue("ShowBodyBattery");
            if (v != null) { return v; }
        } catch (e) {
        }
        return true;
    }

    // Returns [text, icon] for the top-right slot based on the setting.
    // 0 Recovery, 1 Stress, 2 Intensity minutes, 3 Sunrise/sunset, 4 Floors, 5 Calories
    function getTopRightField(info) {
        var choice = 0;
        try {
            var v = Application.Properties.getValue("TopRightField");
            if (v != null) { choice = v; }
        } catch (e) {
        }

        if (choice == 1) {
            var s = latestSample(:stress);
            return [s == null ? "--" : s.toString(), _icons[:stress]];
        } else if (choice == 2) {
            var t = null;
            if ((info has :activeMinutesWeek) && info.activeMinutesWeek != null) {
                t = info.activeMinutesWeek.total;
            }
            return [t == null ? "--" : t.toString(), _icons[:intensity]];
        } else if (choice == 3) {
            return getNextSun();
        } else if (choice == 4) {
            var f = (info has :floorsClimbed) ? info.floorsClimbed : null;
            return [f == null ? "--" : f.toString(), _icons[:floors]];
        } else if (choice == 5) {
            var c = info.calories;
            return [c == null ? "--" : formatThousands(c), _icons[:flame]];
        }

        var r = (info has :timeToRecovery) ? info.timeToRecovery : null;
        return [r == null ? "--" : r.toString() + "h", _icons[:recovery]];
    }

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

    // Latest Body Battery or stress value (0-100), or null
    function latestSample(kind) {
        if (!(Toybox has :SensorHistory)) { return null; }
        var opts = { :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST };
        var it = null;
        if (kind == :bodyBattery && (SensorHistory has :getBodyBatteryHistory)) {
            it = SensorHistory.getBodyBatteryHistory(opts);
        } else if (kind == :stress && (SensorHistory has :getStressHistory)) {
            it = SensorHistory.getStressHistory(opts);
        }
        if (it == null) { return null; }
        var s = it.next();
        if (s == null || s.data == null) { return null; }
        return s.data.toNumber();
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

    // Returns [text, icon] for whichever of sunrise/sunset comes next
    function getNextSun() {
        var none = ["--", _icons[:sunrise]];
        if (!(Weather has :getSunrise)) { return none; }
        var cc = Weather.getCurrentConditions();
        if (cc == null || cc.observationLocationPosition == null) { return none; }

        var loc = cc.observationLocationPosition;
        var now = Time.now();
        var rise = Weather.getSunrise(loc, now);
        var sunset = Weather.getSunset(loc, now);

        if (rise != null && now.lessThan(rise)) {
            return [formatMoment(rise), _icons[:sunrise]];
        }
        if (sunset != null && now.lessThan(sunset)) {
            return [formatMoment(sunset), _icons[:sunset]];
        }
        var tomorrow = Weather.getSunrise(loc, now.add(new Time.Duration(86400)));
        if (tomorrow == null) { return none; }
        return [formatMoment(tomorrow), _icons[:sunrise]];
    }

    // ---------- Formatting ----------

    function formatMoment(m) {
        var i = Gregorian.info(m, Time.FORMAT_SHORT);
        return formatHourMin(i.hour, i.min);
    }

    // Respects the watch's 12/24-hour setting
    function formatHourMin(hour, min) {
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) { hour = 12; }
            return hour.format("%d") + ":" + min.format("%02d");
        }
        return hour.format("%02d") + ":" + min.format("%02d");
    }

    function formatThousands(n) {
        if (n < 1000) { return n.toString(); }
        return (n / 1000).toString() + "," + (n % 1000).format("%03d");
    }
}
