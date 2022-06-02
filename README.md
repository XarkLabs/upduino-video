# UPduino Video Project for SystemVerilog

## Using Makefile and Open Source Tools

This project tries to provide a reasonably simple VGA video text generation
example for the UPduino FPGA board using open source tools.

This example is MIT-0 licensed.  This means you are pretty much free to do as
you wish with it, including putting your name on it, applying a different
license, modifying it and/or putting it in your own project.

This project supports 640x480, 848x480 (wide screen 480p) and 800x600 VGA
modes, with an 8x8 or 8x16 character set and a 1x to 8x pixel repeat.
Shown below is 40x20 text (640x480 with H 2x and V 3x repeat).  There are three
included example font files, a "hexidecimal" font (showing character number
in hex for debugging), a "retro" Ohio Scientific font with graphic characters
(as shown) and also an 8x16 font from the Atari ST.

![UPduino generating 640x480 8 color display](pics/upduino_video_breadboard.jpg
"Picture of VGA monitor showing character set")
<br>UPduino generating 640x480 8 color display

To generate the needed video frequency either UPduino OSC jumper can be shorted
with a blob of solder (for a more solid, permanent clock connection) or you can
use a wire connecting 12M pin to gpio_20 (make sure you have the real 12M pin and
not mislabelled GND, as the silkscreen is incorrect on some boards - check for
 continuity with GND).

```plain-text
            PCF   Pin#  _____  Pin#   PCF
                 /-----| USB |-----\
           <GND> |  1   \___/   48 | spi_ssn   (16)
           <VIO> |  2           47 | spi_sck   (15)
           <RST> |  3           46 | spi_mosi  (17)
          <DONE> |  4           45 | spi_miso  (14)
<RGB2>   led_red |  5           44 | gpio_20   <----+ short OSC jumper
<RGB0> led_green |  6     U     43 | gpio_10        | or use a
<RGB1>  led_blue |  7     P     42 | <GND>          | wire for
      <+5V/VUSB> |  8     d     41 | <12M>     >----+ 12 MHz clock
         <+3.3V> |  9     u     40 | gpio_12
           <GND> | 10     i     39 | gpio_21
         gpio_23 | 11     n     38 | gpio_13
         gpio_25 | 12     o     37 | gpio_19
         gpio_26 | 13           36 | gpio_18
         gpio_27 | 14     V     35 | gpio_11
         gpio_32 | 15     3     34 | gpio_9
<G0>     gpio_35 | 16     .     33 | gpio_6
         gpio_31 | 17     x     32 | gpio_44   <G6>
<G1>     gpio_37 | 18           31 | gpio_4
         gpio_34 | 19           30 | gpio_3
         gpio_43 | 20           29 | gpio_48   >----> VGA blue
         gpio_36 | 21           28 | gpio_45   >----> VGA green
         gpio_42 | 22           27 | gpio_47   >----> VGA red
         gpio_38 | 23           26 | gpio_46   >----> VGA V sync
         gpio_28 | 24           25 | gpio_2    >----> VGA H sync
                 \-----------------/
```

The breadboard pictured is using an
[inexpensive VGA breakout board from Tindie](https://www.tindie.com/products/matzelectronics/vga-adapter-for-raspberry-pi-pico-esp32-etc/)
 with 5-bit RGB (hooking up the two high bits of each color to get more
brightness).  Any breakout designed for 3.3v should be suitable (FPGA PMOD,
Parallax Propeller etc.).

You can also construct your own VGA breakout with 270 ohm resistors on the red,
green and blue pins (as shown at
[www.fpga4fun.com/PongGame.html](http://www.fpga4fun.com/PongGame.html)).

-Xark <https://hackaday.io/Xark>
