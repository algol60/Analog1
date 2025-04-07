import Toybox.Activity;
import Toybox.ActivityMonitor;
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
    private const LONG_MARK_LEN = 10;
    private const SHORT_MARK_LEN = 8;
    private const HDELTA = 1.5;
    private const MDELTA = 8;

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
        for (var i=0; i<15; i++) {
            var angle = FRAC*(60-i);
            var sin = Math.sin(angle);
            var cos = Math.cos(angle);
            if (i%5==0) {
                dc.setPenWidth(i==0 ? 15 : 7);
                var p0 = sin*(radius-LONG_MARK_LEN);
                var p1 = cos*(radius-LONG_MARK_LEN);
                dc.drawLine(w-p0, h-p1, w-sin*w, h-cos*h);
                dc.setPenWidth(7);
                dc.drawLine(w+p0, h+p1, w+sin*w, h+cos*h);

                dc.drawLine(w-p1, h+p0, w-cos*w, h+sin*h);
                dc.drawLine(w+p1, h-p0, w+cos*w, h-sin*h);
            } else {
                dc.setPenWidth(1);
                var p0 = sin*(radius-SHORT_MARK_LEN);
                var p1 = cos*(radius-SHORT_MARK_LEN);
                dc.drawLine(w-p0, h-p1, w-sin*w, h-cos*h);
                dc.drawLine(w+p0, h+p1, w+sin*w, h+cos*h);
                dc.drawLine(w-p1, h+p0, w-cos*w, h+sin*h);
                dc.drawLine(w+p1, h-p0, w+cos*w, h-sin*h);
            }
        }
    }

    private function drawBattery(dc as Dc, angleopp) as Void {
        var WIDTH = 32;
        var HEIGHT = 16;
        var w = screenCenter[0];
        var h = screenCenter[1];

        // Get the "steps" string.
        // (Not enough room to also include stepGoal.)
        //
        var steps = ActivityMonitor.getInfo().steps;
        if (steps==null) {
            steps = "-";
        }
        var ss = Lang.format("$1$", [steps]);
        var textDims = dc.getTextDimensions(ss, Graphics.FONT_XTINY);

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
        var y = h-cos*(radius*0.5) - textDims[1]/2;

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

        // Draw the steps.
        //
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x+WIDTH/2, y+HEIGHT, Graphics.FONT_XTINY, ss, Graphics.TEXT_JUSTIFY_CENTER);

        // Draw a steps/stepGoal bar.
        //
        var stepGoal = ActivityMonitor.getInfo().stepGoal;
        var ratio = (1.0 * steps) / stepGoal; // Multiply by 1.0 to get float divide.
        if (ratio>1.0) {
            ratio = 1.0;
        }
        dc.drawLine(x, y+HEIGHT/2+6, x+ratio*WIDTH, y+HEIGHT/2+6);
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

    // Find quadrants that don't have the hour and minute hand in them.
    // There are two hands (hour and minute), so there are always either two or three
    // free quadrants.
    // The result will be that quadrants 0 and 1 will be the first two free quadrants.
    // Quadrant 3 may or may not be valid depending on where the hands are,
    // but we don't use it anyway.
    //
    private function getFreeQuadrants(hour, minute) as Array<Integer> {
        var quadrants = new Array<Integer>[3];
        var ix = 0;
        if ((hour<=3-HDELTA or hour>=3+HDELTA) and (minute<=15-MDELTA or minute>=15+MDELTA)) {
            quadrants[ix] = 15;
            ix += 1;
        }

        if ((hour>=HDELTA and hour<=12-HDELTA) and (minute>=MDELTA and minute<=60-MDELTA)) {
            quadrants[ix] = 0;
            ix += 1;
        }

        if ((hour<=6-HDELTA or hour>=6+HDELTA) and (minute<=30-MDELTA or minute>=30+MDELTA)) {
            quadrants[ix] = 30;
            ix += 1;
        }

        if (ix<3) {
            quadrants[ix] = 45;
        }

        return quadrants;
    }

    private function minus(a, delta) {
        a -= delta;
        if (a<0) {
            a += 60;
        }
        return a;
    }

    private function plus(a, delta) {
        a += delta;
        if (a>=60) {
            a -= 60;
        }
        return a;
    }

    private function drawHands2(dc as Dc, clockTime) {
        var w = screenCenter[0];
        var h = screenCenter[1];
        var hour = clockTime.hour;
        var minute = clockTime.min;
        if (hour>12) {
            hour = hour - 12;
        }
        hour = hour + minute/5.0/12.0;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);

        // Hour hand (short, wide).
        //
        var angle0 = FRAC*hour*5.0;
        var sin0 = Math.sin(angle0);
        var cos0 = Math.cos(angle0);

        var angle1 = FRAC*minus(hour*5, 7.5);
        var sin1 = Math.sin(angle1);
        var cos1 = Math.cos(angle1);

        var angle2 = FRAC*minus(hour*5.0, 2);
        var sin2 = Math.sin(angle2);
        var cos2 = Math.cos(angle2);

        var angle3 = FRAC*plus(hour*5.0, 2);
        var sin3 = Math.sin(angle3);
        var cos3 = Math.cos(angle3);

        var angle4 = FRAC*plus(hour*5, 7.5);
        var sin4 = Math.sin(angle4);
        var cos4 = Math.cos(angle4);

        var x0 = w+sin1*(radius*0.05);
        var y0 = h-cos1*(radius*0.05);
        var x1 = w+sin2*(radius*0.4);
        var y1 = h-cos2*(radius*0.4);
        var x2 = w+sin0*(radius*0.5);
        var y2 = h-cos0*(radius*0.5);
        var x3 = w+sin3*(radius*0.4);
        var y3 = h-cos3*(radius*0.4);
        var x4 = w+sin4*(radius*0.05);
        var y4 = h-cos4*(radius*0.05);
        dc.fillPolygon([[x0, y0], [x1, y1], [x2, y2], [x3, y3], [x4, y4]]);

        // Minute hand (long, narrow, edge).
        //
        angle0 = FRAC*minute;
        sin0 = Math.sin(angle0);
        cos0 = Math.cos(angle0);

        angle1 = FRAC*minus(minute, 7.5);
        sin1 = Math.sin(angle1);
        cos1 = Math.cos(angle1);

        angle2 = FRAC*minus(minute, 1);
        sin2 = Math.sin(angle2);
        cos2 = Math.cos(angle2);

        angle3 = FRAC*plus(minute, 1);
        sin3 = Math.sin(angle3);
        cos3 = Math.cos(angle3);

        angle4 = FRAC*plus(minute, 7.5);
        sin4 = Math.sin(angle4);
        cos4 = Math.cos(angle4);

        x0 = w+sin1*(radius*0.05);
        y0 = h-cos1*(radius*0.05);
        x1 = w+sin2*(radius*0.7);
        y1 = h-cos2*(radius*0.7);
        x2 = w+sin0*(radius-LONG_MARK_LEN);
        y2 = h-cos0*(radius-LONG_MARK_LEN);
        x3 = w+sin3*(radius*0.7);
        y3 = h-cos3*(radius*0.7);
        x4 = w+sin4*(radius*0.05);
        y4 = h-cos4*(radius*0.05);
        dc.fillPolygon([[x0, y0], [x1, y1], [x2, y2], [x3, y3], [x4, y4]]);

        // Draw the outline of the minute hand to make it look like
        // it sits on top of the hour hand.
        //
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.drawLine(x0, y0, x1, y1);
        dc.drawLine(x1, y1, x2, y2);
        dc.drawLine(x2, y2, x3, y3);
        dc.drawLine(x3, y3, x4, y4);
        dc.drawLine(x4, y4, x0, y0);
    }

    // private function drawHands(dc as Dc, clockTime) {
    //     var w = screenCenter[0];
    //     var h = screenCenter[1];
    //     var hour = clockTime.hour;
    //     var minute = clockTime.min;
    //     if (hour>12) {
    //         hour = hour - 12;
    //     }
    //     hour = hour + minute/5.0/12.0;

    //     var angleh = FRAC*hour*5;
    //     var sin = Math.sin(angleh);
    //     var cos = Math.cos(angleh);
    //     dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    //     dc.setPenWidth(12);
    //     dc.drawLine(w, h, w+sin*(radius*0.5), h-cos*(radius*0.5));

    //     var anglem = FRAC*minute;
    //     sin = Math.sin(anglem);
    //     cos = Math.cos(anglem);
    //     dc.setPenWidth(8);
    //     dc.drawLine(w, h, w+sin*(radius-20), h-cos*(radius-20));
    // }

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
            drawHands2(bufDc, clockTime);
            var quadrants = getFreeQuadrants(hour, minute);
            drawDate(bufDc, quadrants[0]);
            drawBattery(bufDc, quadrants[1]);
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
