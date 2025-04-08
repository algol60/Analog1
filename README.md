# A deliberately simple analog watch face

A minimal watch face that shows only what I need it to.

A feature of the watch face is that the day/date and battery/steps move around so they are never hidden by the hands.

The battery is green to 20%, then yellow to 10%, then red. Steps are shown below the battery, with a horizontal histogram the same width as the battery indicating the percent of the steps goal reached. When the bar is full it turns green.

## Implementation

All of the maths assumes that there are 60 degrees in a circle. It seemed like a good idea at the time.

Drawing the marks is expensive, so they are drawn only once, into a buffer in `initialize()`. In `onUpdate()`, a buffer is used to draw the marks bitmap, then the hour and minute hands, the day/date, and the battery/steps. Therefore, `onPartialUpdate()` only needs to draw the updated bitmap and the second hand.
