The RadioMaster MT12 surface radio originally has 5 trim switches and 4 switches.

Trim #4 is positioned right at where the user's thumb is. I think it would be nice if this trim switch can be used as a traditional momentary switch.

![](photo.jpg)

I made a modified firmware for the MT12 to turn trim #4 into **switch-E**. Please [download the file here](MT12-edgetx.2.10.0-extrathumbswitch.bin), and use the bootloader to apply the firmware.

This firmware is based on EdgeTX version 2.10.0, which is the same version that the MT12 shipped with. The code changes I made is minimal, please see the [diff file here](diff.txt).

The switch will probably not immediately show up, you need to go into `SYS`, then use the `PAGE` button to navigate to the `HARDWARE` menu, then scroll down and set `SE` to be `3POS`.

NOTE: I advise that you map this switch also to a logical switch if you need to use the EdgeTX Companion App, as the companion app is not aware of this kind of customization.

NOTE: T5 is now T4

# Other

Check out [my basic robot mix](https://github.com/frank26080115/EdgeTX-Scripts-and-FW-Collection/tree/main/mixes/basic-robot-mix) for the MT12

Check out how to [use a small ELRS receiver as a PWM receiver](https://github.com/frank26080115/EdgeTX-Scripts-and-FW-Collection/tree/main/ELRS-receiver-PWM-modification)
