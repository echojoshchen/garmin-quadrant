import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

(:typecheck(false))
class QuadrantApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new QuadrantView()];
    }

    // Called when the top-right field is changed in Garmin Connect (store installs only)
    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
