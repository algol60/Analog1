import Toybox.Application;
import Toybox.Graphics;
import Toybox.Time.Gregorian;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class Analog1View extends WatchUi.WatchFace {

    // Pretend there are 60 degrees in a circle.
    //
    private const FRAC = Math.PI / 30.0;

    private var isSleeping = false as Boolean;
    private var canPartialUpdate as Boolean;
    private var previousDrawnMinute as Number = -1;
    // private var screenShape as Number;
    private var screenCenter as Array<Number>;
    private var radius as Number;
    private var offscreenBuffer as BufferedBitmap;

    public function initialize() {
        WatchFace.initialize();
        canPartialUpdate = (WatchUi.WatchFace has :onPartialUpdate);

        var deviceSettings = System.getDeviceSettings();
        // screenShape = deviceSettings.screenShape;
        var width = deviceSettings.screenWidth;
        var height = deviceSettings.screenHeight;
        screenCenter = [width/2, height/2] as Array<Number>;

        // Allow for non-circular/square faces.
        //
        radius = screenCenter[0] <screenCenter[1] ? screenCenter[0] : screenCenter[1];

        var options = {:width=>width, :height=>height};
        offscreenBuffer = new Graphics.BufferedBitmap(options);
    }

    // Draw the marks around the edge.
    // We only need to count through the first quadrant;
    // the marks in the other quadrants are reflections.
    // This saves us from doing more trigonometry.
    //
    private function drawMarks(dc as Dc) as Void {
        var w = screenCenter[0];
        var h = screenCenter[1];
        var color = Graphics.COLOR_WHITE;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i=0; i<16; i++) {
            var angle = FRAC*(60-i);
            var sin = Math.sin(angle);
            var cos = Math.cos(angle);
            if (i%5==0) {
                dc.setPenWidth(i==0 ? 12 : 6);
                var p0 = sin*(radius-10);
                var p1 = cos*(radius-10);
                dc.drawLine(w-p0, h-p1, w-sin*w, h-cos*h);
                dc.setPenWidth(6);
                dc.drawLine(w+p0, h+p1, w+sin*w, h+cos*h);
                dc.drawLine(w-p0, h+p1, w-sin*w, h+cos*h);
                dc.drawLine(w+p0, h-p1, w+sin*w, h-cos*h);
            } else {
                dc.setPenWidth(1);
                var p0 = sin*(radius-8);
                var p1 = cos*(radius-8);
                dc.drawLine(w-p0, h-p1, w-sin*w, h-cos*h);
                dc.drawLine(w+p0, h+p1, w+sin*w, h+cos*h);
                dc.drawLine(w-p0, h+p1, w-sin*w, h+cos*h);
                dc.drawLine(w+p0, h-p1, w+sin*w, h-cos*h);
            }
        }
    }

    // // Draw marks around the edge of the screen using two colors
    // // to show the seconds. Takes longer, so uses more power.
    // //
    // private function drawColorMarks(dc as Dc, sec) {
    //     var w = screenCenter[0];
    //     var h = screenCenter[1];
    //     var color = Graphics.COLOR_WHITE;
    //     dc.setColor(color, color);
    //     for (var i=0; i<60; i++) {
    //         var angle = FRAC*(60-i);
    //         var sin = Math.sin(angle);
    //         var cos = Math.cos(angle);
    //         if (i%5==0) {
    //             // if (i>sec) {
    //             //     dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_TRANSPARENT);
    //             // }
    //             dc.setPenWidth(5);
    //             dc.drawLine(w-sin*(w-10), h-cos*(h-10), w-sin*w, h-cos*h);
    //             // if (i>sec) {
    //             //     dc.setColor(color, Graphics.COLOR_TRANSPARENT);
    //             // }
    //         } else {
    //             dc.setPenWidth(1);
    //             dc.drawLine(w-sin*(w-8), h-cos*(h-8), w-sin*w, h-cos*h);
    //         }

    //         if (i==sec) {
    //             color = Graphics.COLOR_BLUE;
    //             dc.setColor(color, color);
    //         }
    //     }
    // }

    private function drawBattery(dc as Dc, angleopp) as Void {
        var WIDTH = 32;
        var HEIGHT = 16;
        var w = screenCenter[0];
        var h = screenCenter[1];

        var battery = System.getSystemStats().battery;
        var color;
        if (battery>=20) {
            color = Graphics.COLOR_GREEN;
        } else if (battery>=10) {
            color = Graphics.COLOR_YELLOW;
        } else {
            color = Graphics.COLOR_RED;
        }

        var sin = Math.sin(FRAC*angleopp);
        var cos = Math.cos(FRAC*angleopp);
        var x = w+sin*(radius*0.5) - WIDTH/2;
        var y = h-cos*(radius*0.5);

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

    // // Load your resources here
    // function onLayout(dc as Dc) as Void {
    //     setLayout(Rez.Layouts.WatchFace(dc));
    // }

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

    // Select a quadrant that doesn't have hands in it.
    // Avoid an existing quadrant.
    //
    // TODO Find the free quadrants in one go and return an array,
    // so the comparisons don't have to be dome twice.
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

        return angle;
    }

    private function drawHands(dc as Dc, clockTime) {
        var w = screenCenter[0];
        var h = screenCenter[1];
        var hour = clockTime.hour;
        var minute = clockTime.min;
        if (hour>12) {
            hour = hour - 12;
        }
        hour = hour + minute/5.0/12.0;

        var angleh = FRAC*hour*5;
        var sin = Math.sin(angleh);
        var cos = Math.cos(angleh);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(12);
        dc.drawLine(w, h, w+sin*(radius*0.5), h-cos*(radius*0.5));

        var anglem = FRAC*minute;
        sin = Math.sin(anglem);
        cos = Math.cos(anglem);
        dc.setPenWidth(8);
        dc.drawLine(w, h, w+sin*(radius-20), h-cos*(radius-20));
    }

    private function drawDate(dc as Dc, quadrant) as Void {
        var angleopp = FRAC*quadrant;
        var sin = Math.sin(angleopp);
        var cos = Math.cos(angleopp);

        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$\n$2$ $3$", [info.day_of_week, info.month, info.day]);
        var xy = dc.getTextDimensions(dateStr, Graphics.FONT_XTINY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var w = screenCenter[0];
        var h = screenCenter[1];
        dc.drawText(w+sin*(radius*0.5), h-cos*(radius*0.5)-xy[1]/2.0, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // private function drawSeconds(dc as Dc, second as Integer) as Void {
    //     var arcStart = second + 15;
    //     if (arcStart>60) {
    //         arcStart -= 60;
    //     }
    //     arcStart = 30 - arcStart;
    //     dc.setPenWidth(12);
    //     dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
    //     var w = screenCenter[0];
    //     var h = screenCenter[1];
    //     dc.drawArc(w, h, radius-7, Graphics.ARC_CLOCKWISE, arcStart*6+3, arcStart*6-3);
    // }

    private function drawSecondsLine(dc as Dc, second as Integer) as Void {
        var w = screenCenter[0];
        var h = screenCenter[1];
        var angle = FRAC*second;
        var sin = Math.sin(angle);
        var cos = Math.cos(angle);

        dc.setPenWidth(3);
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLUE);
        dc.drawLine(w+sin*(radius-20), h-cos*(radius-20), w+sin*radius, h-cos*radius);
    }

    // Update the view.
    //
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

            // Draw the stuff that doesn't change within a minute into a buffer.
            // Then the partial update can just blit it onto the display,
            // then draw on top of it.
            //

            var bufDc = offscreenBuffer.getDc();
            bufDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            bufDc.clear();

            drawMarks(bufDc);
            drawHands(bufDc, clockTime);
            var quadrant = selectQuadrantAngle(hour, minute, -1);
            drawDate(bufDc, quadrant);
            var q = selectQuadrantAngle(hour, minute, quadrant);
            drawBattery(bufDc, q);
        }

        dc.drawBitmap(0, 0, offscreenBuffer);
        if (canPartialUpdate or !isSleeping) {
            drawSecondsLine(dc, second);
        }
    }

    public function onPartialUpdate(dc as Dc) as Void {
        dc.drawBitmap(0, 0, offscreenBuffer);

        var clockTime = System.getClockTime();
        var second = clockTime.sec;
        drawSecondsLine(dc, second);
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

        WatchUi.requestUpdate();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() as Void {
        isSleeping = true;

        // Force the watchface to be re-drawn.
        //
        previousDrawnMinute = -1;

        WatchUi.requestUpdate();
    }
}

// class Analog1Delegate extends WatchUi.WatchFaceDelegate {
//     // private var _view as Analog1View;

//     //! Constructor
//     //! @param view The analog view
//     public function initialize(view as Analog1View) {
//         WatchFaceDelegate.initialize();
//         // _view = view;
//     }

//     //! The onPowerBudgetExceeded callback is called by the system if the
//     //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
//     //! the system will stop invoking onPartialUpdate each second, so we notify the
//     //! view here to let the rendering methods know they should not be rendering a
//     //! second hand.
//     //! @param powerInfo Information about the power budget
//     public function onPowerBudgetExceeded(powerInfo as WatchFacePowerInfo) as Void {
//         System.println("Average execution time: " + powerInfo.executionTimeAverage);
//         System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
//         // _view.turnPartialUpdatesOff();
//     }
// }
