This is firmware for multi-protocol modules that can "stretch" the PWM signal that a FlySky FS2A receiver outputs. It is meant to make servos swing in a wider arc than usual.

No need to purchase any additional electronics, this is simply a firmware change that can be done as long as you have a USB cable.

The basic principle is that the transmitter is sending FS2A raw 12 bit numbers to represent the PWM pulse widths in microsecond units. Any number between 0 and 4095 can be sent, and the FS2A does not validate the number before sending the pulses. A normal PWM signal pulse width is usually between 988 microseconds and 2012 microseconds (think of it as 1500 as the center and a range of +/- 512). But since we can send arbitary numbers, we can make the transmitter firmware send numbers lower than 988 and higher than 2012.

The way the firmware works is that, when used normally, nothing is actually different. But if you configure the EdgeTX model configuration to use "extended limits", and then you actually start sending a pulse below 988 us or above 2012 us on a channel, then that particular channel has the "stretch" activated, and will remap the values to a range 500 us to 2500 us.

This means you need to wiggle your sticks to the limits at least once before stretching is activated, **every time you power on your radio**

This firmware only applies to multi-protocol modules. Not a FS-i6 or FS-i6X.

There are 4 files provided. Most likely you want to use the one marked as "64kb". The "stretch" file has a output pulse width range between 500 and 2500 microseconds. The "stretchmore" file has a output pulse width range between 250 and 2750 microseconds.

You will need to read these links to understand how to perform the firmware update:

 * https://www.multi-module.org/using-the-module/firmware-updates/update-methods
 * https://www.multi-module.org/advanced-topics/bootloader

I want to make it clear: this is NOT EdgeTX firmware, this is not FS2A firmware. This is Multi-Protocol Module firmware.

Also, importantly, there's a warning from the above tutorials:

> OpenTX and EdgeTX radios with small LCD screens (e.g. Taranis Q X7, RadioMaster TX12) will not display files with names longer than 32 characters when browsing the SD card from the radio menu. You may need to rename the downloaded file before you can access it on your radio.

Please listen to the above warning!

Also note that these firmware files do not include many of the protocols that are typically included in the "multi-protocol" firmware. It is focused on the FlySky AFHDS2A protocol and meant for people using the FS2A receiver.
