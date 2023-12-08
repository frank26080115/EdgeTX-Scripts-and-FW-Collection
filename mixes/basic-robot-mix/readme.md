This is a basic mix setup for a robot being controlled by a EdgeTX RC radio transmitter. It implements a translation between "arcade style" controls to "tank style" drivetrains. It also repurposes the trim adjustments to implement speed limits and rate limits (as opposed to calibrating servos for airplane control surfaces).

The `*.yml` files I have uploaded can be placed on the microSD card under the `MODELS` directory, rename them to simply `model00.yml`.

There are a few logical switches being used by this mix:

 * L61 is used to map either the throttle stick or the elevator stick to the speed control
 * L62 is used to map either the rudder stick or the aileron stick to the steering control
 * L58 is the robot-invert switch, for driving upside-down
 * L59 is used to reverse the direction of the right drive motor, use this to compensate for incorrect wiring
 * L60 is used to reverse the direction of the left drive motor, use this to compensate for incorrect wiring

The logical switches should be mapped to either phyiscal switches, or be set to a position, using the logical switch panel. (this will make the `*.etx` file more compatible with more radios)

The trim switches are used for real-time adjustments:

 * TrmT/Trm4, throttle trim: speed scaling for throttle control input
 * TrmE/Trm3, elevator trim: speed limit for motors, used to scale motor speed up or down after all other calculations
 * TrmR/Trm1, rudder trim: scaling for steering input, makes the robot turn quicker or slower
 * TrmA/Trm2, aileron trim: makes one side's motor faster or slower than the opposite side's motor, used to compensate for damaged or binding motor/wheel. If the robot is not driving straight, use this to adjust.

There are a few curves used:

 * CDZ: control dead-zone, implements a dead-zone for the joysticks, adjust to fit your needs
 * ADZ: anti-dead-zone, used to avoid any dead-zones implemented on the robot's ESCs, adjust to fit your needs
 * P01: positive 0 to 100, a simple line from (-100, 0) to (100, 100), do not adjust
 * P10: positive 100 to 0, a simple line from (-100, 100) to (100, 0), do not adjust

This mix also includes a control channel for a basic combat robot weapon. Channel 3 is the output for the weapon. Channel 20 is the input for the weapon, using L57 as the switch and potentiometer S1 as the speed control. Channel 3 is set to slowly ramp up the weapon speed, but also brake immedately if the weapon needs to be turned off.
