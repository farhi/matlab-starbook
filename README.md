# matlab-starbook
Control a Vixen SX mount StarBook from Matlab

![Image of StarBook](https://github.com/farhi/matlab-starbook/blob/master/%40starbook/doc/Starbook.jpg)

Purpose
-------

STARBOOK: this is a Matlab class to control the Vixen StarBook for telescope mounts.

- Controllers: StarBook, StarBook S and StarBook Ten are supported
- Mounts: SX, SX2, SXD2, SXP, SXW, SXD and AXD mounts.
   
This way you can fully control, and plan the sky observations from your sofa, while it's freezing outside.

Usage
-----

The StarBook IP should be read accessing the 'About STAR BOOK' item, e.g. displayed in the menu at start-up or accessed with the 'MENU' key. 

Then use e.g.:

```matlab
>> addpath('/path/to/matlab-starbook')
>> sb = starbook('169.254.1.1');
```

to establish the connection. Use 'sim' as IP to connect to a simulated StarBook. A view of the Starbook screen appears.

The buttons are active in a similar way to the physical ones. The mouse wheel allows to zoom in/out, and the display is regularly updated (5 sec).
You can access more actions from the top menu.

![Screen of StarBook](https://github.com/farhi/matlab-starbook/blob/master/%40starbook/doc/screen_valid.png)

You may close this view, and re-open it anytime, without affecting the StarBook itself. If the StarBook image can not be retrieved (e.g with a StarBook S and StarBook Ten), a static image is used, and buttons are active as RA+/RA-/DEC+/DEC- (arrows on the right) and ZOOM+/ZOOM- (up/down arrows on the left).

**Preliminary alignment of the Mount**

The mount should have been aligned and configured (date, location, weighting) before.

For the polar alignment, use Stellarium to visually check the location of the polar star wrt the North pole. Suppose in the view you see the polar star at 10 o'clock. Then turn the graticule so that the space for the polar star is at the opposite location as that of Stellarium (the polar scopes invert images). This would then be the 4 o'clock location for our example. Finally adjust the knobs to place the polar star at its theoretical location.

For the alignment, it is recommended to use at least 4 stars, possibly up to 9. Choose a few stars or planets (4-9) on the same side on the meridian (e.g. east or west), preferably not at the zenith. Send the scope there and center the image for each.

Progamming the StarBook
-----------------------

You may as well control the StarBook programmatically, using the methods below with the 'sb' object. To close the StarBook image in this case you may use:

```matlab
>> sb=starbook;
>> close(sb)
>> image(sb)  % re-open it
```

You may directly point to a named object or coordinates with:

```matlab
>> sb=starbook;
>> sb.goto('M 51');
>> sb.goto('13h29m52.30s','+47d11m40.0s');
>> sb.goto('jupiter');
```

Valid names include usual names (such as Betelgeuse, Rigel, Capella, Orion nebula, ...), as well as the major Catalogs such as:

- Proper Name
- StarID
- HD (Henry Draper)
- HR (Harvard Revised)
- Gliese (Gliese Catalog of Nearby Stars)
- BayerFlamsteed denomination (Fifth Edition of the Yale Bright Star Catalog)
- M (Messier)
- NGC (New General Catalog)
- IC (Index Catalog)
- CGCG (Zwicky's Catalogue of Galaxies and of Clusters of Galaxies)
- ESO (ESO/Uppsala Survey of the ESO(B)-Atlas)
- IRAS (IRAS catalogue of infrared sources)
- MCG (Morphological Catalogue of Galaxies)
- PGC (Catalog of Principal Galaxies and LEDA)
- UGC (Uppsala General Catalogue of Galaxies)
- planet names

The named objects have the syntax 'Catalog ID', where the space in between is mandatory. So, use 'M 51', not 'M51'. The available catalogs are those given with SkyChart (https://github.com/farhi/matlab-skychart), but SkyChart is not required as the Catalogs are now included in StarBook.

To check if the mount has reached its position, use:

```matlab
>> sb=starbook;
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

**Programm for a night**

A typical programming for a night could be, after the mount alignment:
```matlab
addpath('/path/to/matlab-starbook')
sb=starbook('192.168.1.19');
for target={'M 51','M 81','M 101'}
  sb.goto(target{1});
  waitfor(sb);
  imwrite(sb.getscreen, [ 'starbook_' datestr(now, 30) '.png' ])
  pause(1800)
end
home(sb); % back to safe position, to avoid dew on the mirror
```
Then simply record images regularly with your CCD/camera. Some will be blurred when the mount moves, but this is a rather fast operation, so only few images are sacrificed. We recommend you to plan your observations using Stellarium (http://stellarium.org/) and http://sky-map.org

**Building a grid (panorama/stitching)**

You may prepare a grid around a target in view to assemble larger panorama view.

The **grid** method returns a list of positions, which you can send the mount to, for instance:

```matlab
for target=sb.grid('M 51'); 
  sb.goto(target); 
  waitfor(sb); % wait for position
  pause(1800); % wait for acquisition (DSLR)
end
```

**WARNING** if the mount has to reverse, you may loose the computer remote control, and would then need to select physically the Yes/No buttons on the StarBook. The mount status will then be USER, and the StarBook screen shows a **'Telescope will now reverse'** message. To avoid that, check **Auto Mount Reversal** menu item in the View menu. Before launching an automatic sequence, make sure the scope can not collide with anything around (mount, pillar, cable...). 

Methods
-------

- **starbook(ip)**:   connect to a StarBook controller
- **goto(sb, ra, dec)**: send StarBook to RA/DEC (given in HH:MM and Deg:MM). When the RA/DEC are not given, a dialogue is shown. You can also enter a named object.
- **goto(sb, 'M 51')**: send StarBook to a named object.
- **move(sb, n,s,e,w)**: move the SB in given direction. Use stop to abort.
- **align(sb)**:      align current coordinates to RA/DEC target
- **stop(sb)**:       stop the mount (e.g. during move/goto)
- **setspeed(sb)**:   set the current zoom/mount speed 0:stop - 8:fast
- **image(sb)**:      display the StarBook image (only for 320*240 screen)
- **home(sb)**:       send the SB to its HOME position
- **help(sb)**:       open the Help page
- **grid**:           build a grid around target
- **waitfor(sb)**:    wait for the mount to stop moving
- **get_ra(sb)**:     return the current RA coordinate
- **get_dec(sb)**:    return the current DEC coordinate
- **get_state(sb)**:  return the current mount state (GOTO/MOVING, SCOPE/IDLE)

Other minor commands

- **start(sb)**:      set/reset the StarBook in SCOPE mode
- **getspeed(sb)**:   return the current zoom/mount speed 
- **getstatus(sb)**:  read the StarBook state
- **getxy(sb)**:      read motor coders
- **getscreen(sb)**:  get the StarBook image as an RGB matrix
- **update(sb)**:     update status and image (when figure is visible)
- **plot(sb)**:       same as image(sb), display screen and interface
- **close(sb)**:      close the screen view
- **web(sb)**:        show the current target on sky-map.org
- **zoom(sb,{z})**:   get/set the zoom level. z can be 'in','out' or in 0-8
- **date(sb)**:       get the starbook date/time
- **chart(sb)**:      open skychart (when available)
- **findobj(sb,obj)**: search for an object name in star/DSO catalogs
- **revert(sb)**:     attempt a mount reversal. Must be close within 5 min.

Requirements/Installation
-------------------------
Matlab, no external toolbox. A Vixen StarBook controller for SX-type mounts.

Just copy the files and go into the src directory. Then type commands above.
Limitations: The StarBook S and StarBook Ten may be partly supported (the screen image is not handled).

We recommend to install as well:

- Stellarium, for a nice looking view of the sky.

Credits
-------

**urldownload : version 1.0 (9.81 KB) by Jaroslaw Tuszynski, 23 Feb 2016**

- https://fr.mathworks.com/matlabcentral/fileexchange/55614-urldownload

**rubytelescopeserver: Rob Burrowes 2013**

- https://github.com/rbur004/rubytelescopeserver*
