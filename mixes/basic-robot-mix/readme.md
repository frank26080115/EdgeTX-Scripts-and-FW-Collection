This is a basic mix setup for a robot being controlled by a EdgeTX RC radio transmitter. It implements a translation between "arcade style" controls to "tank style" drivetrains. It also repurposes the trim adjustments to implement speed limits and rate limits (as opposed to calibrating servos for airplane control surfaces).

The `*.yml` files (for some specific models of radios) I have uploaded can be placed on the microSD card under the `MODELS` directory, rename them to simply `model00.yml` first.

To change between using the left stick and right stick, edit the sources in the `inputs` menu.

If you've wired a drive motor backwards, edit the channel direction from the `outputs` menu, select which side and edit the `direction` setting to be `INV`.

Channel 31 and 32 has an `EXPO` curve item set, it's default to 25%. Edit these two curves to fit your needs, 0% means linear.

There are a few logical switches being used by this mix:

 * L57 is the weapon off switch (true = weapon off)
 * L58 is the robot-invert switch, for driving upside-down
 * L56 is the auto-weapon-slow toggle, use this to enable/disable this feature, or temporarily override this feature

The logical switches should be mapped to either phyiscal switches, or be set to a position, using the logical switch panel. (this will make these files more compatible with more radios)

To pick a switch position, set the logical switch to use either `a=b` (true if max) or `a<b` (false if max), with the first parameter being the switch source, and the second parameter being `MAX`. Remember to also set the pre-flight check options for the weapon switch.

There is an intentional slow-up enabled for the weapon channel 3, edit the slowness if you don't need it.

The trim switches are used for real-time adjustments:

 * TrmT, throttle trim: speed scaling for throttle control input
 * TrmE, elevator trim: speed limit for motors, used to scale motor speed up or down after all other calculations
 * TrmR, rudder trim: scaling for steering input, makes the robot turn quicker or slower
 * TrmA, aileron trim: makes one side's motor faster or slower than the opposite side's motor, used to compensate for damaged or binding motor/wheel. If the robot is not driving straight, use this to adjust.

There are a few curves used:

 * CDZ: control dead-zone, implements a dead-zone for the joysticks, can compensate for old joysticks or overly twitchy fingers
   * adjust to fit your needs
 * ADZ: anti-dead-zone, used to avoid any dead-zones implemented on the robot's ESCs, can solve problems with ESCs that appear laggy or unresponsive at low throttle
   * adjust to fit your needs, ask the ESC manufacturer if you have questions
 * P01: positive 0 to 100, a simple line from (-100, 0) to (100, 100)
   * do not adjust
 * P10: positive 100 to 0, a simple line from (-100, 100) to (100, 0)
   * do not adjust
 * WSL: weapon slow, used to automatically slow down a weapon during a steering turn
 * WEP: maps potentiometer/stick to 0 to 100 range, change the range as -100 to 100 if you need to use bi-directional weapon
 * WPS: used by the output stage to apply a offset and multiplication, do not use if the weapon is bi-directional

This mix also includes a control channel for a basic combat robot weapon. Channel 3 is the output for the weapon. Channel 20 is the input for the weapon, using L57 as the switch and potentiometer S1 as the speed control. Channel 3 is set to slowly ramp up the weapon speed, but also brake immedately if the weapon needs to be turned off.

# Notes for MT12

TrmT is T4, TrmE is T3, TrmR is T1, and TrmA is T2
