import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Time.Gregorian;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// A deliberately simply analog watch face.
//
// The outstanding feature is that the day/date and battery/steps
// are never hidden by the hands.
//
class Analog1View extends WatchUi.WatchFace {

    // Pretend there are 60 degrees in a circle.
    //
    private const FRAC = Math.PI / 30.0;

    // Marker lengths (proportinal to the radius).
    //
    private const TWELVE_MARK_LEN = 0.11;
    private const LONG_MARK_LEN = 0.075;
    private const SHORT_MARK_LEN = 0.05;

    // The angles of the hour and minutes hands defining a quadrant to be avoided.
    //
    private const HDELTA = 1.5;
    private const MDELTA = 8;

    // Battery icon size.
    //
    private const BWIDTH = 32;
    private const BHEIGHT = 16;

    private var isSleeping = false as Boolean;
    private var canPartialUpdate as Boolean;
    private var previousDrawnMinute as Number = -1;
    // private var screenShape as Number;
    private var centreXY as Array<Number>;
    private var radius as Number;
    private var marksBuffer as BufferedBitmap;
    private var offscreenBuffer as BufferedBitmap;

    public function initialize() {
        WatchFace.initialize();
        canPartialUpdate = WatchUi.WatchFace has :onPartialUpdate;

        var deviceSettings = System.getDeviceSettings();
        // screenShape = deviceSettings.screenShape;
        var width = deviceSettings.screenWidth;
        var height = deviceSettings.screenHeight;
        centreXY = [width/2, height/2] as Array<Number>;

        // Allow for non-circular/square faces.
        //
        radius = centreXY[0] <centreXY[1] ? centreXY[0] : centreXY[1];

        var options = {:width=>width, :height=>height};
        marksBuffer = new Graphics.BufferedBitmap(options);
        offscreenBuffer = new Graphics.BufferedBitmap(options);

        // Only draw the marks once.
        //
        var marksDc = marksBuffer.getDc();
        marksDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        marksDc.clear();
        drawMarks(marksDc);
    }

    // Draw a single hour / minute / second mark.
    //
    private function drawMark(dc as Dc, second as Integer, dangle as Float, len as Float) as Void {
        var cx = centreXY[0];
        var cy = centreXY[1];
        var angle1 = FRAC*minusMod(second, dangle);
        var sin1 = Math.sin(angle1);
        var cos1 = Math.cos(angle1);
        var angle2 = FRAC*plusMod(second, dangle);
        var sin2 = Math.sin(angle2);
        var cos2 = Math.cos(angle2);
        var s1 = sin1*radius;
        var c1 = cos1*radius;
        var s2 = sin2*radius;
        var c2 = cos2*radius;

        // Draw a mark by drawing a polygon between two points on the radius
        // and a fraction of the distance between two points on the opposite radius.
        // This produces a rectangle instead of tapering towards the centre.
        //
        var poly = [
            [cx+s1, cy-c1],
            [cx+s2, cy-c2],
            [(1-len)*(cx+s2) + len*(cx-s1), (1-len)*(cy-c2) + len*(cy+c1)],
            [(1-len)*(cx+s1) + len*(cx-s2), (1-len)*(cy-c1) + len*(cy+c2)]
        ];
        dc.fillPolygon(poly);
    }

    // Draw the hour / minute / second marks.
    //
    private function drawMarks(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        for (var i=0; i<60; i++) {
            var dangle = i==0 ? 0.6 : i%5==0 ? 0.35 : 0.05;
            var len = i==0 ? TWELVE_MARK_LEN : i%5==0 ? LONG_MARK_LEN : SHORT_MARK_LEN;
            drawMark(dc, i, dangle, len);
        }
    }

    private function drawBattery(dc as Dc, angleopp) as Void {
        var cx = centreXY[0];
        var cy = centreXY[1];

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
        var x = cx+sin*(radius*0.5) - BWIDTH/2;
        var y = cy-cos*(radius*0.5) - textDims[1]/2;

        // Draw the outline of the battery.
        //
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x, y-BHEIGHT/2, BWIDTH, BHEIGHT);
        dc.drawLine(x+BWIDTH+1, y-BHEIGHT/2+4, x+BWIDTH+1, y-BHEIGHT/2+BHEIGHT-4);

        // Draw the battery bar.
        //
        dc.setColor(color, color);
        dc.fillRectangle(x+1, y-BHEIGHT/2+2, (BWIDTH-4)*battery/100.0, (BHEIGHT-4));

        // Draw the steps.
        //
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x+BWIDTH/2, y+BHEIGHT, Graphics.FONT_XTINY, ss, Graphics.TEXT_JUSTIFY_CENTER);

        // Draw a steps/stepGoal bar.
        //
        var stepGoal = ActivityMonitor.getInfo().stepGoal;
        var ratio = (1.0 * steps) / stepGoal; // Multiply by 1.0 to get float divide.
        if (ratio>=1.0) {
            ratio = 1.0;
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_GREEN);
        }
        dc.setPenWidth(3);
        dc.drawLine(x, y+BHEIGHT/2+6, x+ratio*BWIDTH, y+BHEIGHT/2+6);
    }

    // // Load your resources here
    // function onLayout(dc as Dc) as Void {
    //     setLayout(Rez.Layouts.WatchFace(dc));
    // }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    //
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
    //
    // The result will be that quadrants [0] and [1] will be the first two free quadrants.
    // Quadrant [3] may or may not be valid depending on where the hands are,
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

    private function minusMod(a, delta) {
        a -= delta;
        if (a<0) {
            a += 60;
        }
        return a;
    }

    private function plusMod(a, delta) {
        a += delta;
        if (a>=60) {
            a -= 60;
        }
        return a;
    }

    private function drawHands(dc as Dc, clockTime) {
        var cx = centreXY[0];
        var cy = centreXY[1];
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

        var angle1 = FRAC*minusMod(hour*5, 7.5);
        var sin1 = Math.sin(angle1);
        var cos1 = Math.cos(angle1);

        var angle2 = FRAC*minusMod(hour*5.0, 2);
        var sin2 = Math.sin(angle2);
        var cos2 = Math.cos(angle2);

        var angle3 = FRAC*plusMod(hour*5.0, 2);
        var sin3 = Math.sin(angle3);
        var cos3 = Math.cos(angle3);

        var angle4 = FRAC*plusMod(hour*5, 7.5);
        var sin4 = Math.sin(angle4);
        var cos4 = Math.cos(angle4);

        var x0 = cx+sin1*(radius*0.05);
        var y0 = cy-cos1*(radius*0.05);
        var x1 = cx+sin2*(radius*0.4);
        var y1 = cy-cos2*(radius*0.4);
        var x2 = cx+sin0*(radius*0.5);
        var y2 = cy-cos0*(radius*0.5);
        var x3 = cx+sin3*(radius*0.4);
        var y3 = cy-cos3*(radius*0.4);
        var x4 = cx+sin4*(radius*0.05);
        var y4 = cy-cos4*(radius*0.05);
        dc.fillPolygon([[x0, y0], [x1, y1], [x2, y2], [x3, y3], [x4, y4]]);

        // Minute hand (long, narrow, edge).
        //
        angle0 = FRAC*minute;
        sin0 = Math.sin(angle0);
        cos0 = Math.cos(angle0);

        angle1 = FRAC*minusMod(minute, 7.5);
        sin1 = Math.sin(angle1);
        cos1 = Math.cos(angle1);

        angle2 = FRAC*minusMod(minute, 1);
        sin2 = Math.sin(angle2);
        cos2 = Math.cos(angle2);

        angle3 = FRAC*plusMod(minute, 1);
        sin3 = Math.sin(angle3);
        cos3 = Math.cos(angle3);

        angle4 = FRAC*plusMod(minute, 7.5);
        sin4 = Math.sin(angle4);
        cos4 = Math.cos(angle4);

        x0 = cx+sin1*(radius*0.05);
        y0 = cy-cos1*(radius*0.05);
        x1 = cx+sin2*(radius*0.7);
        y1 = cy-cos2*(radius*0.7);
        x2 = cx+sin0*(radius*(1-2*LONG_MARK_LEN));
        y2 = cy-cos0*(radius*(1-2*LONG_MARK_LEN));
        x3 = cx+sin3*(radius*0.7);
        y3 = cy-cos3*(radius*0.7);
        x4 = cx+sin4*(radius*0.05);
        y4 = cy-cos4*(radius*0.05);
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

    private function drawDate(dc as Dc, quadrant) as Void {
        var angleopp = FRAC*quadrant;
        var sin = Math.sin(angleopp);
        var cos = Math.cos(angleopp);

        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$\n$2$ $3$", [info.day_of_week, info.month, info.day]);
        var xy = dc.getTextDimensions(dateStr, Graphics.FONT_XTINY);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var cx = centreXY[0];
        var cy = centreXY[1];
        dc.drawText(cx+sin*(radius*0.5), cy-cos*(radius*0.5)-xy[1]/2.0, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Draw the second hand as a red triangle pointing towards the centre.
    //
    private function drawSeconds(dc as Dc, second as Integer) as Void {
        var cx = centreXY[0];
        var cy = centreXY[1];

        var angle0 = FRAC*second;
        var sin0 = Math.sin(angle0);
        var cos0 = Math.cos(angle0);

        var angle1 = FRAC*minusMod(second, 1.0);
        var sin1 = Math.sin(angle1);
        var cos1 = Math.cos(angle1);

        var angle2 = FRAC*plusMod(second, 1.0);
        var sin2 = Math.sin(angle2);
        var cos2 = Math.cos(angle2);

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);

        // Draw the base of the triangle beyond the radius so the background marks
        // don't show. The radius also affects the pointiness of the triangle.
        //
        var r = radius*1.1;
        var tipHeight = 1-2*LONG_MARK_LEN;
        dc.fillPolygon([
            [cx+sin0*radius*tipHeight, cy-cos0*radius*tipHeight],
            [cx+sin1*r, cy-cos1*r],
            [cx+sin2*r, cy-cos2*r]
        ]);
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
            // bufDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            // bufDc.clear();
            bufDc.drawBitmap(0, 0, marksBuffer);

            drawHands(bufDc, clockTime);
            var quadrants = getFreeQuadrants(hour, minute);
            drawDate(bufDc, quadrants[0]);
            drawBattery(bufDc, quadrants[1]);
        }

        dc.drawBitmap(0, 0, offscreenBuffer);
        if (canPartialUpdate or !isSleeping) {
            drawSeconds(dc, second);
        }
    }

    public function onPartialUpdate(dc as Dc) as Void {
        dc.drawBitmap(0, 0, offscreenBuffer);

        var clockTime = System.getClockTime();
        var second = clockTime.sec;
        drawSeconds(dc, second);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    //
    function onHide() as Void {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    //
    function onExitSleep() as Void {
        isSleeping = false;

        // Force the watchface to be re-drawn.
        //
        previousDrawnMinute = -1;

        WatchUi.requestUpdate();
    }

    // Terminate any active timers and prepare for slow updates.
    //
    function onEnterSleep() as Void {
        isSleeping = true;

        // Force the watchface to be re-drawn.
        //
        previousDrawnMinute = -1;

        WatchUi.requestUpdate();
    }
}
