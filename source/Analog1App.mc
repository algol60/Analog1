import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class Analog1App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        // if (WatchUi has :WatchFaceDelegate) {
        //     var view = new Analog1View();
        //     var delegate = new Analog1Delegate(view);
        //     return [view, delegate];
        // } else {
        //     return [ new Analog1View() ];
        // }
        return [ new Analog1View() ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}

function getApp() as Analog1App {
    return Application.getApp() as Analog1App;
}