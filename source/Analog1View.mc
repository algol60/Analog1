import Toybox.Application;
import Toybox.Graphics;
import Toybox.Time.Gregorian;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class Analog1View extends WatchUi.WatchFace {

    private var isSleeping = false as Boolean;
    private var _partialUpdatesAllowed as Boolean;
    private const FRAC = Math.PI / 30.0;
    private var previousDrawnMinute as Number = -1;
    private var screenShape as Number;
    private var screenCenter as Array<Number>;
    private var clockRadius as Number;
    private var offscreenBuffer as BufferedBitmap;

    public function initialize() {
        WatchFace.initialize();
        _partialUpdatesAllowed = (WatchUi.WatchFace has :onPartialUpdate);

        var deviceSettings = System.getDeviceSettings();
        screenShape = deviceSettings.screenShape;
        var width = deviceSettings.screenWidth;
        var height = deviceSettings.screenHeight;
        screenCenter = [width/2, height/2] as Array<Number>;

        // Allow for non-circular/square faces.
        //
        clockRadius = screenCenter[0] <screenCenter[1] ? screenCenter[0] : screenCenter[1];

        var options = {:width=>width, :height=>height};
        offscreenBuffer = new Graphics.BufferedBitmap(options);
    }

    private function drawMarks0(dc as Dc) as Void { //}, sec) {
        var w = dc.getWidth()/2;
        var h = dc.getHeight()/2;
        var color = Graphics.COLOR_WHITE;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i=0; i<30; i++) {
            var angle = FRAC*(60-i);
            var sin = Math.sin(angle);
            var cos = Math.cos(angle);
            if (i%5==0) {
                // if (i>sec) {
                //     dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
                // }
                dc.setPenWidth(5);
                var p0 = sin*(w-10);
                var p1 = cos*(h-10);
                dc.drawLine(w-p0, h-p1, w-sin*w, h-cos*h);
                dc.drawLine(w+p0, h+p1, w+sin*w, h+cos*h);
                // if (i>sec) {
                //     dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                // }
            } else {
                dc.setPenWidth(1);
                var p0 = sin*(w-8);
                var p1 = cos*(h-8);
                dc.drawLine(w-p0, h-p1, w-sin*w, h-cos*h);
                dc.drawLine(w+p0, h+p1, w+sin*w, h+cos*h);
            }

            // if (i==sec) {
            //     color = Graphics.COLOR_DK_BLUE;
            //     dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            // }
        }
    }

    // // Draw the marks around the edge of the screen.
    // //
    // private function drawMarks(dc as Dc, sec) {
    //     var w = dc.getWidth()/2;
    //     var h = dc.getHeight()/2;
    //     // var frac = Math.PI / 30.0;
    //     var color = Graphics.COLOR_WHITE;
    //     dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    //     for (var i=0; i<60; i++) {
    //         var angle = FRAC*(60-i);
    //         var sin = Math.sin(angle);
    //         var cos = Math.cos(angle);
    //         if (i%5==0) {
    //             if (i>sec) {
    //                 dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
    //             }
    //             dc.setPenWidth(5);
    //             dc.drawLine(w-sin*(w-10), h-cos*(h-10), w-sin*w, h-cos*h);
    //             if (i>sec) {
    //                 dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    //             }
    //         } else {
    //             dc.setPenWidth(1);
    //             dc.drawLine(w-sin*(w-8), h-cos*(h-8), w-sin*w, h-cos*h);
    //         }

    //         if (i==sec) {
    //             color = Graphics.COLOR_DK_BLUE;
    //             dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    //         }
    //     }
    // }

    private function drawBattery(dc as Dc, angleopp) as Void {
        var WIDTH = 32;
        var HEIGHT = 16;
        var w = dc.getWidth()/2;
        var h = dc.getHeight()/2;

        var battery = System.getSystemStats().battery;
        var color;
        if (battery>=20) {
            color = Graphics.COLOR_GREEN;
        } else if (battery>=10) {
            color = Graphics.COLOR_YELLOW;
        } else {
            color = Graphics.COLOR_RED;
        }

        // var angleopp = FRAC*selectQuadrantAngle(hour, minute);
        var sin = Math.sin(FRAC*angleopp);
        var cos = Math.cos(FRAC*angleopp);
        var x = w+sin*(w*0.5) - WIDTH/2;
        var y = h-cos*(h*0.5);

        // Draw the outline of the battery.
        //
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x, y-HEIGHT/2, WIDTH, HEIGHT);
        dc.drawLine(x+WIDTH+1, y-HEIGHT/2+4, x+WIDTH+1, y-HEIGHT/2+HEIGHT-4);

        // Draw the battery bar.
        //
        dc.setColor(color, color);
        dc.fillRectangle(x+1, y-HEIGHT/2+2, (WIDTH-4)*battery/100.0, (HEIGHT-4));
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        // Assuming onShow() is triggered after any settings change, force the watch face
        // to be re-drawn in the next call to onUpdate(). This is to immediately react to
        // changes of the watch settings or a possible change of the DND setting.
        //
        previousDrawnMinute = -1;
    }

    // private function display(dc as Dc) as Void {
    //     dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
    // 	dc.clear();

    //     // Get the current time and format it correctly
    //     var timeFormat = "$1$:$2$:$3$";
    //     var clockTime = System.getClockTime();

    //     var hours = clockTime.hour;
    //     if (!System.getDeviceSettings().is24Hour) {
    //         if (hours > 12) {
    //             hours = hours - 12;
    //         }
    //     } else {
    //         if (Application.Properties.getValue("UseMilitaryFormat")) {
    //             timeFormat = "$1$$2$$3$";
    //             hours = hours.format("%02d");
    //         }
    //     }
    //     var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d"), clockTime.sec.format("%02d")]);
    //     // System.println(Lang.format("time $1$", [timeString]));

    //     // Update the view
    //     var view = View.findDrawableById("TimeLabel") as Text;
    //     view.setColor(Application.Properties.getValue("ForegroundColor") as Number);
    //     view.setText(timeString);
    // }

    // Select a quadrant that doesn't have hands in it.
    //
    private function selectQuadrantAngle(hour, minute, avoid) as Integer {
        var angle;
        if ((hour<2 or hour>4) and (minute<10 or minute>20) and avoid!=15) {
            angle = 15;
        } else if ((1<hour and hour<11) and (5<minute and minute<55) and avoid!=0) {
            angle = 0;
        } else if ((hour<5 or hour>7) and (minute<25 or minute>35) and avoid!=30) {
            angle = 30;
        } else {
            angle = 45;
        }
        System.println(Lang.format("$1$ $2$ $3$ $4$", [hour, minute, angle, avoid]));

        return angle;
    }

    private function drawHands(dc as Dc, clockTime, quadrant) {
        var w = dc.getWidth()/2;
        var h = dc.getHeight()/2;
        var hour = clockTime.hour;
        var minute = clockTime.min;
        if (hour>12) {
            hour = hour - 12;
        }
        hour = hour + minute/5.0/12.0;

        // var hh = 60.0-hour*5;
        var angleh = FRAC*(60.0-hour*5);
        var sin = Math.sin(angleh);
        var cos = Math.cos(angleh);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(12);
        dc.drawLine(w, h, w-sin*(w*0.5), h-cos*(h*0.5));

        // var mm = 60.0-minute;
        var anglem = FRAC*(60.0-minute);
        sin = Math.sin(anglem);
        cos = Math.cos(anglem);
        dc.setPenWidth(8);
        dc.drawLine(w, h, w-sin*(w-20), h-cos*(h-20));

        // var angles = FRAC*(60.0-clockTime.sec);
        // sin = Math.sin(angles);
        // cos = Math.cos(angles);
        // dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        // var p0 = sin*(w-6);
        // var p1 = cos*(h-6);
        // dc.fillCircle(w-p0, h-p1, 6);

        // var text = "plugh\nxyzzy";
        // var xy = dc.getTextDimensions(text, Graphics.FONT_XTINY);
        // var angleopp = ((angleh+anglem)/2.0) - 30.0*FRAC;
        // var angleopp = anglem - angleh;
        // if (angleopp>FRAC*180.0) {
        //     angleopp = angleopp - FRAC*360;
        // }
        // if(angleopp<-FRAC*180.0) {
        //     angleopp = angleopp + FRAC*360;
        // }
        // var quadrant = selectQuadrantAngle(hour, minute, -1);
        var angleopp = FRAC*quadrant;
        sin = Math.sin(angleopp);
        cos = Math.cos(angleopp);
        // dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        // dc.drawCircle(w+sin*(w*0.5), h-cos*(h*0.5), w/4.0);
        // dc.drawText(w+sin*(w*0.5), h-cos*(h*0.5)-xy[1]/2.0, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);

        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$\n$2$ $3$", [info.day_of_week, info.month, info.day]);
        var xy = dc.getTextDimensions(dateStr, Graphics.FONT_XTINY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w+sin*(w*0.5), h-cos*(h*0.5)-xy[1]/2.0, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        dc.clearClip();

        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var minute = clockTime.min;
        var second = clockTime.sec;
        if (hour>12) {
            hour = hour - 12;
        }
        hour = hour + minute/5.0/12.0;

        if (previousDrawnMinute!=minute) {
            previousDrawnMinute = minute;

            var bufDc = offscreenBuffer.getDc();
            bufDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            bufDc.clear();

            drawMarks0(bufDc);
            var quadrant = selectQuadrantAngle(hour, minute, -1);
            drawHands(bufDc, clockTime, quadrant);
            var q = selectQuadrantAngle(hour, minute, quadrant);
            drawBattery(bufDc, q);
        }

        dc.drawBitmap(0, 0, offscreenBuffer);

        // // var w = dc.getWidth()/2;
        // // var h = dc.getHeight()/2;

        // // var td = dc.getTextDimensions(timeString, Graphics.FONT_LARGE);
        // // dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        // // dc.drawText(w, h-td[1]/2, Graphics.FONT_LARGE, timeString, Graphics.TEXT_JUSTIFY_CENTER);

        // // var name = "Jason B";
        // // // var td2 = dc.getTextDimensions(name, Graphics.FONT_LARGE);
        // // dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        // // dc.drawText(w, h+td[1], Graphics.FONT_LARGE, name, Graphics.TEXT_JUSTIFY_CENTER);

        // // drawMarks0(dc, -1);//clockTime.sec);

        // dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        // dc.clear();

        // // // System.println("partial");
        // // // display(dc);
        // // // Call the parent onUpdate function to redraw the layout
        // // // View.onUpdate(dc);
        // // var clockTime = System.getClockTime();
        // drawMarks0(dc);

        // // var hour = clockTime.hour;
        // // var minute = clockTime.min;
        // // if (hour>12) {
        // //     hour = hour - 12;
        // // }
        // // hour = hour + minute/5.0/12.0;

        // var quadrant = selectQuadrantAngle(hour, minute, -1);
        // drawHands(dc, clockTime, quadrant);
        // var q = selectQuadrantAngle(hour, minute, quadrant);
        // drawBattery(dc, q);

        if(_partialUpdatesAllowed) {
            System.println("partial on");
            if (!isSleeping) {
                // onPartialUpdate(dc);
            }
        } else {
            // display(dc);
            // Call the parent onUpdate function to redraw the layout
            // View.onUpdate(dc);
            // System.println("partial off");
            // drawMarks0(dc, -1);//clockTime.sec);
        }
    }

    public function onPartialUpdate(dc as Dc) as Void {
        // Fill the entire background with Black.
        // dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        // dc.fillRectangle(0, 0, dc.getWidth(), dc.getHeight());
        // dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_BLACK);
        // dc.clear();

        // System.println("partial");
        // display(dc);
        // Call the parent onUpdate function to redraw the layout
        // View.onUpdate(dc);

        dc.drawBitmap(0, 0, offscreenBuffer);

        var clockTime = System.getClockTime();
        var second = clockTime.sec;
        System.println(format("second $1$", [second]));
        // drawMarks0(dc, clockTime.sec);

        // var hour = clockTime.hour;
        // var minute = clockTime.min;
        // if (hour>12) {
        //     hour = hour - 12;
        // }
        // hour = hour + minute/5.0/12.0;

        // var quadrant = selectQuadrantAngle(hour, minute, -1);
        // drawHands(dc, clockTime, quadrant);
        // var q = selectQuadrantAngle(hour, minute, quadrant);
        // drawBattery(dc, q);

        var w = dc.getWidth()/2;
        var h = dc.getHeight()/2;

        var arcStart = second + 15;
        if (arcStart>60) {
            arcStart -= 60;
        }
        arcStart = 30 - arcStart;
        dc.setPenWidth(12);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        // dc.drawArc(w, h, 100, Graphics.ARC_COUNTER_CLOCKWISE, 90, 135);
        // dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_YELLOW);
        dc.drawArc(w, h, w-7, Graphics.ARC_CLOCKWISE, arcStart*6+3, arcStart*6-3);

        // // var clockTime = System.getClockTime();
        // var angles = FRAC*(60.0-clockTime.sec);
        // var sin = Math.sin(angles);
        // var cos = Math.cos(angles);
        // dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        // var p0 = sin*(w-12);
        // var p1 = cos*(h-12);
        // // dc.setClip(w-p0-6, h-p1-6, 12, 12);
        // dc.fillCircle(w-p0, h-p1, 2);
        // // dc.fillRectangle(w-p0-6, h-p1-6, 12, 12);
        // // dc.drawPoint(w-p0, h-p1);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() as Void {
        isSleeping = false;

        // Force the watchface to be re-drawn.
        //
        previousDrawnMinute = -1;

        System.println("sleep exit");
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        isSleeping = true;

        // Force the watchface to be re-drawn.
        //
        previousDrawnMinute = -1;

        System.println("sleep enter");
    }
}

class Analog1Delegate extends WatchUi.WatchFaceDelegate {
    // private var _view as Analog1View;

    //! Constructor
    //! @param view The analog view
    public function initialize(view as Analog1View) {
        WatchFaceDelegate.initialize();
        // _view = view;
    }

    //! The onPowerBudgetExceeded callback is called by the system if the
    //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
    //! the system will stop invoking onPartialUpdate each second, so we notify the
    //! view here to let the rendering methods know they should not be rendering a
    //! second hand.
    //! @param powerInfo Information about the power budget
    public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
        System.println("Average execution time: " + powerInfo.executionTimeAverage);
        System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
        // _view.turnPartialUpdatesOff();
    }
}