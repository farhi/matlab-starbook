# matlab-starbook
Control a Vixen SX mount StarBook from Matlab

![Image of StarBook](https://github.com/farhi/matlab-starbook/blob/master/doc/Starbook.jpg)

Purpose
-------

STARBOOK: this is a Matlab class to control the Vixen StarBook for telescope mounts.

- Controllers: StarBook, StarBook S and StarBook Ten are supported
- Mounts: SX, SX2, SXD2, SXP, SXW, SXD and AXD mounts.
   
This way you can fully control, and plan the sky observations from your sofa, while it's freezing outside.

Usage
-----

The mount should have been aligned and configured (date, location, equilibration) before, and the StarBook IP should be read accessing the 'About STAR BOOK' menu item.
Then use e.g.:

```matlab
>> sb = starbook('169.254.1.1');
```

to establish the connection. Use 'sim' as IP to connect to a simulated StarBook.
The easiest is to display the starbook screen image with

```matlab
>> sb.image
```

The buttons are active in a similar way to the physical ones. The mouse wheel allows to zoom in/out, and the display is regularly updated (5 sec).
You can access more actions from the top menu.

![Screen of StarBook](https://github.com/farhi/matlab-starbook/blob/master/doc/screen_valid.png)

You may close this view, and re-open it anytime, without affecting the StarBook itself. 
You may directly point to a named object or coordinates with:

```matlab
>> sb.gotoradec('M 51');
>> sb.gotoradec('13h29m52.30s','+47d11m40.0s');
```

To check if the mount has reached its position, use:

```matlab
>> sb.getstatus
```

returns a string with current physical coordinates, as well as the status such as:

- GOTO: indicates that the mount is moving
- SCOPE: indicates that the mount is idle
- USER: waiting for physical User input
- INIT: not ready yet
- CHART: in Chart mode

You may as well request to wait for the mount to end movement with:

```matlab
>> waitfor(sb)
```

**WARNING** if the mount has to reverse, you may loose the computer remote control, and would then need to select physically the Yes/No buttons on the StarBook. The mount status should then be USER.

Methods
-------

- **starbook(ip)**:   connect to a StarBook controller
- **gotoradec(sb, ra, dec)**: send StarBook to RA/DEC (given in HH:MM and Deg:MM). When the RA/DEC are not given, a dialogue is shown. You can also enter a named object.
- **gotoradec(sb, 'M 51')**: send StarBook to a named object.
- **move(sb, n,s,e,w)**: move the SB in given direction. Use stop to abort.
- **align(sb)**:      align current coordinates to RA/DEC target
- **stop(sb)**:       stop the mount (e.g. during move/gotoradec)
- **setspeed(sb)**:   set the current zoom/mount speed 0:stop - 8:fast
- **image(sb)**:      display the StarBook image (only for 320*240 screen)
- **home(sb)**:       send the SB to its HOME position
- **help(sb)**:       open the Help page

Other minor commands

- **start(sb)**:      set/reset the StarBook in SCOPE mode
- **getspeed(sb)**:   return the current zoom/mount speed 
- **getstatus(sb)**:  update the StarBook state
- **getxy(sb)**:      update motor coders
- **getscreen(sb)**:  get the StarBook image as an RGB matrix
- **update(sb)**:     update status and image
- **plot(sb)**:       same as image(sb)
- **close(sb)**:      close the screen view
- **web(sb)**:        show the current target on sky-map.org
- **zoom(sb,{z})**:   get/set the zoom level. z can be 'in','out' or in 0-8
- **date(sb)**:       get the starbook date/time
- **chart(sb)**:      open skychart (when available)
- **findobj(sb,obj)**: search for an object name in star/DSO catalogs
- **waitfor(sb)**:    wait for the mount to stop moving

Requirements/Installation
-------------------------
Matlab, no external toolbox. A Vixen StarBook controller for SX-type mounts.

Just copy the files and go into the src directory. Then type commands above.

Credits
-------

**urldownload : version 1.0 (9.81 KB) by Jaroslaw Tuszynski, 23 Feb 2016**

- https://fr.mathworks.com/matlabcentral/fileexchange/55614-urldownload

**rubytelescopeserver: Rob Burrowes 2013**

- https://github.com/rbur004/rubytelescopeserver*
