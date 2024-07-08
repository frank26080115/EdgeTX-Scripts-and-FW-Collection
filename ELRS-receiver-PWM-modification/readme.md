Welcome to the age of ExpressLRS! There are some incredibly small ExpressLRS radio receivers available on the market, but they are designed to communicate with a drone's flight-controller so they only have two data pins, one TX and one RX. This makes it difficult to be used with devices that use PWM signalling, such as servos and ESCs.

There is a way to convert these tiny receivers to having three PWM outputs! This is great if you are building a robot or car or a V-tail. Here's how to do it:

I do recommend this particular receiver for combat robotics, the BetaFPV ELRS Lite, with the flat antenna.

![](imgs/elrsrxprep_start.jpg)

The flat antenna seems like a safer option than the cubic ceramic antenna in an impact situation. The other reason is that the "boot" pad on it is rather large, so it is easier to solder. If the receiver has no "boot" pad, then you cannot add the 3rd channel to it.

![](imgs/elrsrxprep_bootpad.jpg)

The first step is to get a piece of male header pins, 5 pins, 0.1" standard spacing. Trim four out of the five pins so that it can be soldered to the receiver as close as possible. The 5th pin should still stick out, which will make it easier for you to connect with the boot pad.

![](imgs/elrsrxprep_cutheaders.jpg)

Solder one of the pins to the receiver. Make sure all of the pins are aligned. (if they are not aligned, then melt the solder and adjust the alignment)

![](imgs/elrsrxprep_solderfirstpad.jpg)

Solder all four pins, make sure that each joint is strong (also solder the back side). Tin the boot pad and the 5th pin in preperation for the wire.

![](imgs/elrsrxprep_4pinssoldered.jpg)

Solder a thin wire from the boot pad to the 5th pin. (I used 30 AWG wire)

![](imgs/elrsrxprep_solderboot.jpg)

![](imgs/elrsrxprep_finishedsolderingcloseup.jpg)

Trim off the excess wire and you are done soldering! Clean the flux off if required. Apply the heat-shrink.

![](imgs/elrsrxprep_heatshrink.jpg)

![](imgs/elrsrxprep_alldone.jpg)

Now to configure the ELRS receiver to output PWM signals. Follow this diagram, power up the receiver by connecting the V+ and GND pins to a BEC (or any 5V power supply).

![](imgs/elrsrxprep_pinout.jpg)

Once the receiver is powered ON, wait for 60 seconds until the Wi-Fi interface starts. Connect to the access point named `ExpressLRS RX`, with the password `expresslrs`. There will be no internet available through this access point and your smartphone or computer will need to be told to not disconnect from it.

![](imgs/elrsrxprep_connectwifi.jpg)

# Pin Config Method 1 (hardware config JSON)

Once connected to the Wi-Fi access point, open up a browser and use it to navigate to `http://10.0.0.1/hardware.html`. From there, upload this custom JSON file I [provided for you here](pwm3.json).

![](imgs/elrsrxprep_hwfileupload.jpg)

# Pin Config Method 2 (firmware install)

Once connected to the Wi-Fi access point, open up a browser and use it to navigate to `http://10.0.0.1/`. From there, use the firmware update tab to upload this custom firmware file I [provided for you here](elrs-betafpv-lite-fw3.3.1-pwm-wifi.bin).

![](imgs/elrsrxprep_fwupdate.png)

# Verify Pin Config

Use the `MODEL` tab of the configuration page to ensure that the PWM pins are correctly configured:

![](imgs/elrsrxprep_pwmconfig.png)

The key items to check: 50 Hz mode for all channels, the input channels are in the correct order, invert is off, 750 us mode is off, and the failsafe is set to either 0 (for no-pulse mode) or your desired setting.

If you are not using my custom firmware, then no-pulse mode is not available, and you should set your own proper failsafe pulse values.

After that, configure the receiver however you like, such as setting the binding phrase.

# You are Finished!

Here it is compared against other small receivers:

![](imgs/elrsrxprep_sizecompare.jpg)

If you need some super short connectors to connect to this super small receiver, [please consider this technique for making small connectors](../Make-Short-Dupont-Plug-Connectors/readme.md).

![](../Make-Short-Dupont-Plug-Connectors/shortplug_final.jpg)

And I have written a [short guide (click here)](use-with-combat-robots.md) catering to beginner combat robot hobbyists about how to connect to this receiver.

# Custom Firmware Notes

The custom firmware I have provided is a special build.

 * all pins are configured for PWM output
 * failsafe can be configured for no-pulse mode
   * set the failsafe value to 0 for no-pulse
 * base version is 3.3.1
   * if you are using a future transmitter firmware that is not compatible, then use the JSON file method

If you are not using my custom firmware, then no-pulse mode is not available, and you should set your own proper failsafe pulse values.

If you want a copy of the firmware that can be loaded by UART, [use this file](elrs-betafpv-lite-fw3.3.1-pwm-wifi.bin)
