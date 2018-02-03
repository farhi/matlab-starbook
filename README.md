# matlab-starbook
Control a Vixen SX mount StarBook from Matlab

<p align="center">

                          <br>
                          E. Farhi [farhi@ill.fr]
                          <br>
                          Version 18.02.03

<br>
<img src="https://github.com/farhi/matlab-starbook/blob/master/src/Starbook.jpg" style="width: 50%; height: 50%">
</p>

Purpose
-------

STARBOOK: this is a Matlab class to control the Vixen StarBook for telescope mounts.
   StarBook, StarBook S and StarBook Ten are supported, to control 
   SX, SX2, SXD2, SXP, SXW, SXD and AXD mounts.
   
This way you can fully control, and plan the sky observations from your sofa, while it's freezing outside.

Usage
-----

The mount should have been aligned and configured (date, location,
equilibration) before, and the StarBook IP should be read accessing the
'About STAR BOOK' menu item.
Then use e.g.:

```matlab
>> sb = starbook('169.254.1.1');
```

to establish the connection.
The easiest is to display the starbook screen image with

```matlab
>> sb.image
```

The buttons are active in a similar way to the physical ones. The mouse
wheel allows to zoom in/out, and the display is regularly updated (5 sec).
You can access more actions from the top menu.

Methods
-------

- **starbook(ip)**:   connect to a StarBook controller
- **gotoradec(sb, ra, dec)**: send StarBook to RA/DEC  
- **move(sb, n,s,e,w)**: move the SB in given direction. Use stop to abort.   
- **align(sb)**:      align current coordinates to RA/DEC target     
- **stop(sb)**:       stop the mount (e.g. during move/gotoradec)
- **setspeed(sb)**:   set the current zoom/mount speed 0:stop - 8:fast
- **image(sb)**:      display the StarBook image (only for 320*240 screen)
- **home(sb)**:       send the SB to its HOME position

Other minor commands

- **start(sb)**:      set/reset the StarBook in SCOPE mode
- **getspeed(sb)**:   return the current zoom/mount speed 
- **getstatus(sb)**:  update the StarBook state
- **getxy(sb)**:      update motor coders     
- **getscreen(sb)**:  get the StarBook image as an RGB matrix

Requirements/Installation
-------------------------
Matlab, no external toolbox. A Vixen StarBook controller for SX-type mounts.

Just copy the files and go into the src directory. Then type commands aboce.

Credits
-------

**urldownload : version 1.0 (9.81 KB) by Jaroslaw Tuszynski, 23 Feb 2016**

- https://fr.mathworks.com/matlabcentral/fileexchange/55614-urldownload

**rubytelescopeserver: Rob Burrowes 2013**

- https://github.com/rbur004/rubytelescopeserver
