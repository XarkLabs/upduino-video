# UPduino Video Project for SystemVerilog

## Using Makefile and Open Source Tools

This project tries to provide a reasonably simple VGA video text generation
example for the UPduino FPGA board using open source tools.

This example is MIT-0 licensed.  This means you are pretty much free to do as
you wish with it, including putting your name on it, applying a different
license, modifying it or putting it in your own project.

Supports 640x480, 848x480 (wide screen 480p) and 800x600, with an 8x8 character
set and 1x to 8x pixel repeat.  Shown below is 40x20 text (640x480 with H 2x and
V 3x).  There is an included "hex" font (showing character number in hex) and
the "retro" Ohio Scientific font with graphic characters (as shown).

![UPduino generating 640x480 8 color display](pics/upduino_video_breadboard.jpg
"Picture of VGA monitor showing character set")
<br>UPduino generating 640x480 8 color display

-Xark <https://hackaday.io/Xark>
