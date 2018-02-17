classdef starbook < handle
  % STARBOOK: a class to control the Vixen StarBook for telescope mounts.
  %   StarBook, StarBook S and StarBook Ten are supported, to control 
  %   SX, SX2, SXD2, SXP, SXW, SXD and AXD mounts.
  %
  % The mount should have been aligned and configured (date, location,
  % weighting)) before, and the StarBook IP should be read accessing the
  % 'About STAR BOOK' menu item.
  %
  % Then use e.g.:
  %
  %   sb = starbook('169.254.1.1');
  %
  % to establish the connection and display the StarBook screen.
  %
  % The buttons are active in a similar way to the physical ones. The mouse
  % wheel allows to zoom in/out, and the display is regularly updated (5 sec).
  % You can access more actions from the top menu, and unactivate the 
  % auto-update.
  %
  % For testing purposes, you may open a simulated StarBook with:
  %
  %   sb = starbook('simulate');
  %
  % or use 'simulate' as IP in the input dialogue.
  %
  % Methods:
  %   starbook(ip):   connect to a StarBook controller
  %   gotoradec(sb, ra, dec): send StarBook to RA/DEC  
  %   move(sb, n,s,e,w): move the SB in given direction. Use stop to abort.   
  %   align(sb):      align current coordinates to RA/DEC target     
  %   stop(sb):       stop the mount (e.g. during move/gotoradec)
  %   setspeed(sb):   set the current zoom/mount speed 0:stop - 8:fast
  %   image(sb):      display the StarBook image (only for 320*240 screen)
  %   home(sb):       send the SB to its HOME position
  %   help(sb):       open the Help page
  %
  % Other minor commands
  %   start(sb):      set/reset the StarBook in SCOPE mode
  %   getspeed(sb):   return the current zoom/mount speed 
  %   getstatus(sb):  update the StarBook state
  %   getxy(sb):      update motor coders     
  %   getscreen(sb):  get the StarBook image as an RGB matrix
  %   update(sb):     update status and image
  %   plot(sb):       same as image(sb)
  %   close(sb):      close the screen view
  %   web(sb):        show the current target on sky-map.org
  %   zoom(sb,{z}):   get/set the zoom level. z can be 'in','out' or in 0-8
  %   date(sb):       get the starbook date/time
  %   chart(sb):      open skychart (when available)
  %
  % Credits: 
  % urldownload : version 1.0 (9.81 KB) by Jaroslaw Tuszynski, 23 Feb 2016
  %   https://fr.mathworks.com/matlabcentral/fileexchange/55614-urldownload
  % 
  % rubytelescopeserver: Rob Burrowes 2013
  %   https://github.com/rbur004/rubytelescopeserver
  %
  % (c) E. Farhi, GPL2 - version 18.02.03

  properties
    ip        = '169.254.1.1';  % default IP as set in StarBook
    target_ra = struct('h',  0,'min',0);       % target RA/DEC, as struct(h/deg,min)
    target_dec= struct('deg',0,'min',0);
    ra        = struct('h',  0,'min',0);       % current RA/DEC, as struct(h/deg,min)
    dec       = struct('deg',0,'min',0);
    state     = 'INIT';
    x         = 0;        % coder values (0:round)
    y         = 0;
    round     = 8640000;  % full circle coder value
    speed     = 8;
    timer     = [];       % the current Timer object which sends a getstate regularly
    version   = '2.7 (simulate)';
    place     = { 'E' 5 2 'N' 45 2 0 };       % GPS location
    start_time= datestr(now);
    UserData  = [];
    simulate  = false;
    figure    = [];
    skychart  = [];
  end % properties
  
  methods
  
    function sb = starbook(ip)
      % sb=starbook(ip): start communication an given IP and initialize the StarBook
      if nargin
        if strncmp(ip, 'sim',3)
          sb.simulate   = true;
        else
          sb.ip         = ip;
        end
      else
        prompt = {'Enter StarBook IP (e.g. 169.254.1.1) or "simulate"'};
        name = 'StarBook: Set IP';
        options.Resize='on';
        options.WindowStyle='normal';
        options.Interpreter='tex';
        answer=inputdlg(prompt,name, 1, {sb.ip}, options);
        if isempty(answer), error([ mfilename ': initialization aborted.' ]);
        elseif strncmp(answer{1}, 'sim',3)
          sb.simulate   = true;
        else sb.ip = answer{1}; end
      end
      disp([ mfilename ': Connecting to ' sb.ip ])
      if ~sb.simulate
        try
          ret = queue(sb.ip, 'getversion', 'version=%s');
        catch ME
          disp(getReport(ME));
          disp([ mfilename ': Switching to simulate mode.' ])
          sb.simulate   = true;
          ret           = sb.version;
        end
        if ischar(ret) && ~isempty(strfind(ret, 'error'))
          error(ret);
        else
          sb.version = char(ret);
        end
      end
      
      if ~sb.simulate
        sb.place      = queue(sb.ip, 'getplace',   'longitude=%c%d+%d&latitude=%c%d+%d&timezone=%d');
      end
      sb.start_time = date(sb);
      % round: This is a full circle on the dec and ra motors in y or x coordinates.
      if ~sb.simulate
        sb.round      = queue(sb.ip, 'getround',   'ROUND=%d');
      end
      % make sure we go to SCOPE mode
      getstatus(sb);
      getxy(sb);
      start(sb);
      setspeed(sb, 6);
      % create the timer for auto update
      sb.timer  = timer('TimerFcn', @TimerCallback, ...
          'Period', 5.0, 'ExecutionMode', 'fixedDelay', 'UserData', sb, ...
          'Name', mfilename);
      % display screen
      disp([ mfilename ': [' datestr(now) '] Welcome to StarBook ' sb.version ])
      image(sb); % also start the timer
      
    end % starbook
    
    function s = getstatus(self)
      % s=getstatus(sb): update object with current status
      %    Return a string indicating status.
      
      % If the mount is executing a gotoradec. GOTO=1
      % States power on  => INIT
      %       Scope mode => SCOPE
      %       Chart mode => CHART
      %       In a menu  => USER
      if ~self.simulate
        ret = queue(self.ip, 'getstatus', ...
          'RA=%d+%f&DEC=%d+%f&GOTO=%d&STATE=%4s');
      else
        % we simulate a move from current to target RA/DEC
        dRA   =  (self.target_ra.h+self.target_ra.min/60) ...
                -(self.ra.h+self.ra.min/60);
        dDEC  =  (self.target_dec.deg+self.target_dec.min/60) ...
               - (self.dec.deg+self.dec.min/60);
        % max mve is limited
        if abs(dRA)  > 1, dRA  =   sign(dRA); end
        if abs(dDEC) > 4, dDEC = 4*sign(dDEC); end
        % compute next position
        DEC= self.dec.deg+self.dec.min/60 + dDEC;
        [RA_h, RA_min]     = getra(self.ra.h+self.ra.min/60 + dRA);
        [DEC_deg, DEC_min] = getdec(self.dec.deg+self.dec.min/60 + dDEC);
        if abs(dRA) > .01 || abs(dDEC) > .01
          goto=1;
        else goto=0; end
        ret={ RA_h, RA_min, DEC_deg, DEC_min, goto, 'SCOPE' };
      end
      [self.ra.h, self.ra.min, self.dec.deg, self.dec.min, goto] = deal(ret{1:5});
      self.ra.h    = double(self.ra.h);
      self.dec.deg = double(self.dec.deg);
      self.state   = char(ret{6});
      if goto
        self.state = 'GOTO';
      end
      getxy(self);  % update coder values
      s = sprintf('RA=%d+%f DEC=%d+%f [%s]', ...
        self.ra.h, self.ra.min, self.dec.deg, self.dec.min, self.state);
    end % getstatus

    function gotoradec(self, ra_h, ra_min, dec_deg, dec_min)
      % gotoradec(sb,ra_h, ra_min, dec_deg, dec_min): send the mount to given RA/DEC
      % gotoradec(sb, ra, dec)
      % Right Ascension can be given as:
      %   separate H, M arguments
      %   a single number
      %   a vector [H,M] or [H,M,S]
      %   a string such as HHhMMmSSs, HH:MM:SS, HHhMM, HH:MM
      % Declinaison can be given as:
      %   separate DEG, M arguments
      %   a single number
      %   a vector [DEG,M] or [DEG,M,S]
      %   a string such as DEG°MM'SS", DEG°MM'
      %
      % When RA and DEC are not given, a dialogue box is shown.
      %                
      %  Can return:
      %     ERROR:FORMAT	
      %     ERROR:ILLEGAL STATE	
      %     ERROR:BELOW HORIZON
      if nargin == 1
        prompt = {'Enter Right Ascension RA (HHhMMmSSs or HH:MM:SS or HH.hh)', ...
               'Enter Declinaison DEC (DD°MM''SS" or DD°MM or DD.dd)' };
        name = 'StarBook: Goto RA/DEC: Set TARGET';
        options.Resize='on';
        options.WindowStyle='normal';
        options.Interpreter='tex';
        answer=inputdlg(prompt,name, 1, ...
          {sprintf('%dh%fm',   self.ra.h, self.ra.min), ...
           sprintf('%ddeg%fm', self.dec.deg, self.dec.min)}, options);
        if isempty(answer), return; end
        gotoradec(self, answer{1}, answer{2});
        return
      elseif nargin == 3
        % Declinaison
        [dec_deg, dec_min] = getdec(ra_min);
        % Right Ascension
        [ra_h, ra_min]     = getra(ra_h);
      elseif nargin < 5
        disp([ mfilename ': gotoradec: wrong number of input.' ])
        return
      end
      self.target_ra.h   = ra_h;
      self.target_ra.min = ra_min;
      self.target_dec.deg= dec_deg;
      self.target_dec.min= abs(dec_min);
      
      cmd = sprintf('gotoradec?RA=%d+%f&DEC=%d+%f', ...
        self.target_ra.h,    self.target_ra.min, ...
        self.target_dec.deg, self.target_dec.min);
      disp([ mfilename ': [' datestr(now) '] ' cmd ]);
      if ~self.simulate
        queue(self.ip, cmd, 'OK');
      else
        disp([ 'SIMU: ' cmd ]);
      end
    end % gotoradec
    
    function home(self)
      % home(sb): send mount to home position
      disp([ mfilename ': [' datestr(now) '] home' ]);
      cmd = 'gohome?home=0';
      if ~self.simulate
        queue(self.ip, cmd,'OK');
      else
        disp([ 'SIMU: ' cmd ]);
        gotoradec(self, 0, 0);
      end
    end % home
    
    function move(self, north, south, east, west)
      % move(sb, north, south, east, west): move continuously the mount in given direction. 
      %   Requires STOP to stop movement.
      %
      %   north: when 1, start move in DEC+
      %   south: when 1, start move in DEC-
      %   east:  when 1, start move in RA-
      %   west:  when 1, start move in RA+
      %
      % You may as well use move(sb, 'north') or move(sb, 'ra+') or move(sb, 'up')
      % and similar stuff for other directions.
      % Can return: ERROR:FORMAT
      if nargin == 2
        d = north;
        north=0; south=0; east=0; west=0;
        switch lower(d)
        case {'north''dec+','up','n'}
          north=1;
        case {'south','dec-','down','s'}
          south=1;
        case {'ra+','east','left','e'}
          east=1;
        case {'ra-','west','right','w'}
          west=1;
        end
      elseif nargin < 5
        north=0; south=0; east=0; west=0; 
      end
      north = logical(north);
      south = logical(south);
      east  = logical(east);
      west  = logical(west);
      cmd = sprintf('move?north=%i&south=%i&east=%i&west=%i', north, south, east, west);
      if ~self.simulate
        queue(self.ip, cmd, 'OK');
      else
        disp([ 'SIMU: ' cmd ]);
        [self.target_ra.h self.target_ra.min] = getra( ...
          self.target_ra.h+self.target_ra.min/60 + east-west);
        [self.target_dec.deg self.target_dec.min] = getdec( ...
          self.target_dec.deg+self.target_dec.min/60 + north-south);
      end
    end % move
    
    function setspeed(self, speed)
      % setspeed(sb, speed): set the mount speed/zoom factor from 0(stop) - 8(fast)
      % Can return: ERROR:FORMAT
      if nargin<2, return; end
      if     speed < 0, speed = 0;
      elseif speed > 8, speed = 8; 
      end
      self.speed = round(speed);
      cmd = sprintf('setspeed?speed=%i', self.speed);
      if ~self.simulate
        queue(self.ip, cmd, 'OK');
      else
        disp([ 'SIMU: ' cmd ]);
      end
    end % setspeed
    
    function s = getspeed(self)
      % getspeed(sb): return current speed
      s = self.speed;
    end % getspeed
    
    function stop(self)
      % stop(sb): stop any movement
      %  Can return "ERROR:ILLEGAL STATE".
      if ~self.simulate
        queue(self.ip, 'stop','OK');
      else
        disp([ 'SIMU: ' 'stop' ]);
        self.target_ra = self.ra;
        self.target_dec= self.dec;
      end
      move(self, 0,0,0,0);
    end % stop
    
    function start(self)
      % start(sb): clear any error, and set the mount in move mode
      %  Can return "ERROR:ILLEGAL STATE".
      if ~self.simulate
        queue(self.ip, 'start');
      else
        disp([ 'SIMU: ' 'start' ]);
      end
    end % start
    
    function align(self)
      % align(sb): align the mount to any preset RA/DEC target
      %   One should usually issue a gotoradec, and move the mount to center
      %   the actual location of the target, then issue an align.
      disp([ mfilename ': [' datestr(now) '] align' ]);
      if ~self.simulate
        queue(self.ip, 'align','OK');
      else
        disp([ 'SIMU: ' 'align' ]);
      end
      % display target and current RA/DEC
    end % align
    
    function s=getxy(self)
      % getxy(sb): update mount motors coder values
      if ~self.simulate
        xy     = queue(self.ip, 'getxy', 'X=%d&Y=%d');
      else xy = { 0 0 }; end
      [self.x,self.y] = deal(xy{:});
      
      % returns x and y coordinates of the mount. 0,0 is the power on position
      % getround / 4 is maximum east and west (negative for east) .
      % getround / 2 is maximum south and North  (negative for south) . 
      % i.e.
      % X is the RA axis and ranges from about -2160000 (east) to 2160000 (west).
      % Y is the Dec axis ranges from from about -432000(south) to +432000(north)
      % Useful for telling if the mount should reverse
      % check if the mount is close to revert
      if abs(abs(self.x) - self.round/4) < self.round/4/10
        disp([ mfilename ': mount is close to reverse on X (east-west=RA) motor.' ])
      end
      if abs(abs(self.y) - self.round/2) < self.round/2/10
        disp([ mfilename ': mount is close to reverse on YX (north-south=DEC) motor.' ])
      end
      s = sprintf('X=%d Y=%d', self.x, self.y);
    end % getxy
    
    function W = getscreen(self)
      % im=getscreen(self): get an image of the current StarBook screen
      %   You may then plot the result with 'image(im)'
    
      % bitmap of whats on the screen. 320x240 12bit raw image file.
      % this takes about 0.5 sec
      
      % there is an issue as Matlab's urlread stops before end of message when
      % dealing with binary streams.
      % We use urldownload: 
      %   https://fr.mathworks.com/matlabcentral/fileexchange/55614-urldownload
      cmd = [ 'http://' self.ip '/getscreen.bin' ];
      if ~self.simulate
        [status,raw] = urldownload(cmd);
        W = im12toim24(raw);
      else
        disp([ 'SIMU: ' cmd ]);
        W = []; 
      end
      
    end % getscreen
    
    function h = image(self)
      % image(sb): show the StarBook screen and allow control using mouse/menu.
      
      persistent screen_static
      
      % select figure
      ud.StarBook      = self;
      ud.clicked_button='';
      tag = [ 'StarBook_' strrep(self.ip, '.', '_') ];
      h = findall(0, 'Tag', tag);
      if isempty(h)
        h = image_build(tag, self.ip, ud, self);
        if strcmp(self.timer.Running, 'off') start(self.timer); end
      else
        if numel(h) > 1, delete(h(2:end)); h=h(1); end
        set(0, 'CurrentFigure',h);
      end
      self.figure = h;
      set(h, 'HandleVisibility','on', 'NextPlot','add');
      im = '';
      
      % get the screen image
      if ~isempty(screen_static)
        % the screen can not be obtained (off-line / not StarBook 1)
        % we use a static screen
        im = screen_static;
      else
        try
          im = getscreen(self);
        end
        if isempty(im)
          im  = imread(fullfile(fileparts(which(mfilename)),'doc','screen.png'));
          screen_static = im;
        end
      end
      % display it
      if ~isempty(im)
        % get status and display
        hi = image(im);
        set(gca, 'Position', [ 0 0 1 1 ]);
        set(self.figure, 'Name', ...
          sprintf('StarBook: RA=%d+%.2f DEC=%d+%.2f [%4s]', ...
          self.ra.h, self.ra.min, self.dec.deg, self.dec.min, self.state));
        set(hi, 'UserData', ud);
        set(hi, 'ButtonDownFcn',        @ButtonDownCallback);
        
        if ~isempty(screen_static)
          % we display some text on 'blured' areas for static screen
          % [ 461 44 ] RA / DEC
          t = text(465, 70, { ...
            sprintf('%d+%.2f', self.ra.h, self.ra.min), ...
            sprintf('%d+%.2f',self.dec.deg, self.dec.min) });
          set(t,'Color', 'w', 'FontSize', 18);
          t = text(465, 200, { ...
            sprintf('%d+%.2f', self.target_ra.h, self.target_ra.min), ...
            sprintf('%d+%.2f',self.target_dec.deg, self.target_dec.min) });
          set(t,'Color', 'w', 'FontSize', 18);
        end
      end
      set(h, 'HandleVisibility','off', 'NextPlot','new');
    end % image
    
    function update(self)
      % update(sb): update the starbook status and image
      getstatus(self);
      if ishandle(self.figure)
        image(self);
      else self.figure = []; end
    end % update
    
    function d = date(self)
      % date(sb): get the starbook date/time
      if ~self.simulate
        d = queue(self.ip, 'gettime',    'time=%d+%d+%d+%d+%d+%d');
        d = datestr(double(cell2mat(d)));
      else
        d = datestr(now);
      end
      
    end
    
    function h = plot(self)
      % plot(sb): plot the starbook screen (same as image)
      h = image(self);
    end % plot
    
    function z = zoom(self, z)
      % zoom(sb): get/set zoom level
      %
      %   zoom(sb, 'in')
      %   zoom(sb, 'out')
      %   zoom(sb, 0-8)
      %   zoom(sb, 'reset')
      if nargin == 2
        if ischar(z)
          switch lower(z)
          case 'reset'
            z = 6;
          case 'in'
            z = getspeed(self)-1;
          case 'out'
            z = getspeed(self)+1;
          otherwise
            z = 6;
          end
        end 
        setspeed(self, z);
      else
        z = getspeed(self);
      end
    end % zoom
    
    function url = web(self)
      % web(sb): display the starbook RA/DEC target in a web browser (sky-map.org)
      self.getstatus;
      url = sprintf([ 'http://www.sky-map.org/?ra=%f&de=%f&zoom=%d' ...
      '&show_grid=1&show_constellation_lines=1' ...
      '&show_constellation_boundaries=1&show_const_names=0&show_galaxies=1' ], ...
      self.ra.h+self.ra.min/60.0, self.dec.deg+self.dec.min/60.0, 9-self.getspeed);
      % open in system browser
      open_system_browser(url);
    end % web
    
    function url=help(self)
      % help(sb): open the Help page
      url = fullfile('file:///',fileparts(which(mfilename)),'doc','StarBook.html');
      open_system_browser(url);
    end
    
    function chart(self)
      % chart(sb): open the skychart
      if isempty(self.skychart) && exist('skychart')
        % we search for any already opened skychart handle
        h = findall(0, 'Tag','SkyChart','Type','figure');
        if numel(h) > 1, h=h(1); end
        if ~isempty(h)
          sc = get(h, 'UserData');
        else sc = skychart;
        end
        self.skychart = sc;
        % associate the starbook to the chart (connect it)
        connect(self.skychart, self);
      end
      if ~isempty(self.skychart)
        plot(self.skychart);
      end
    end
    
    function close(self)
      % close(sb): close the starbook
      if ~isempty(self.timer) && isvalid(self.timer)
        stop(self.timer); 
      end
      if ishandle(self.figure); delete(self.figure); end
      self.figure = [];
    end
  
  end % methods
  
end % classdef

% ------------------------------------------------------------------------------
% private functions
% ------------------------------------------------------------------------------
function [val, str] = queue(ip, input, output)
  % queue: sends the input, waits for completion, get result as a cell or scalar
  if nargin < 3, output = ''; end
  val = [];
  cmd = [ 'http://' ip '/' input ];
  [str,status] = urlread(cmd);
  if ~status
    error([ mfilename ': error in communication with StarBook. Check IP.']);
  end
    
  if any(output == '%') && ~isempty(findstr(str, '<!--'))
    % expect values from a formated string with '%' format
    str_start = strfind(str, '<!--'); % extract the comment at start of answer
    str_end   = strfind(str, '-->');
    str2      = str((str_start+4):(str_end-1));
    val       = textscan(str2, output);
  elseif ~isempty(output)
    % expect a specific string as answer
    if isempty(strfind(str, output))
      disp([ mfilename ': WARNING: unexpected answer from StarBook' ])
      disp(cmd)
      disp(str);
    end
    
  end
  
  if numel(val) == 1, val=val{1}; end
end % queue



function W = im12toim24(raw)
  % im12toim24: convert the 12 bit image into a 24 bit image
  
  % check we have a 320*240 12 bits image for StarBook (first version)
  if numel(raw) ~= 115200
    W=[];
    return
  end
  
  % we get all bits 1-8 then 1-4, then 5-8 then 1-8
  % [ 1-8 1-4 ] [ 5-8 1-8 ]
  %    W0  W1      W1  W2
  % [  RG  B       R   GB ]
  
  % extend these so that they have 320*240/2 elements
  W  = uint8(raw);
  
  W0 = W(1:3:(end-2)); W0 = [ W0 zeros(1,320*240/2-numel(W0), 'uint8') ];
  W1 = W(2:3:(end-1)); W1 = [ W1 zeros(1,320*240/2-numel(W1), 'uint8') ];
  W2 = W(3:3:end);     W2 = [ W2 zeros(1,320*240/2-numel(W2), 'uint8') ];
  % we use bit masks to extract portions, and eventually shift them
  % create new uint8 image for which we shall copy consecutive bits 1:4 for each layer
  R = zeros(1,320*240,'uint8'); % 76800 uint8
  G = R;
  B = R;
  
  R(1:2:(end-1)) = bitshift(bitand(W0, bin2dec('00001111')), 4);
  G(1:2:(end-1)) = bitshift(bitand(W0, bin2dec('11110000')), 0);
  B(1:2:(end-1)) = bitshift(bitand(W1, bin2dec('00001111')), 4);
  R(2:2:end)     = bitshift(bitand(W1, bin2dec('11110000')), 0);
  G(2:2:end)     = bitshift(bitand(W2, bin2dec('00001111')), 4);
  B(2:2:end)     = bitshift(bitand(W2, bin2dec('11110000')), 0);
  
  % re-assemble this into an RGB image
  W = zeros(240,320,3,'uint8');
  W(:,:,1) = reshape(R, 320,240)';
  W(:,:,2) = reshape(G, 320,240)';
  W(:,:,3) = reshape(B, 320,240)';
  
end % im12toim24

function [ra_h, ra_min] = getra(ra)
  % getra: convert any input RA into h and min
  ra_h = []; ra_min = [];
  if ischar(ra)
    ra = repradec(ra);
  end
  if isnumeric(ra)
    if isscalar(ra)
      ra_h   = fix(ra); ra_min = abs(ra - ra_h)*60;
    elseif numel(ra) == 2
      ra_h = ra(1);     ra_min = abs(ra(2));
    elseif numel(ra) == 3
      ra_h = ra(1);     ra_min = abs(ra(2))+abs(ra(3)/60);
    end
  else
    disp([ mfilename ': invalid RA.' ])
    disp(ra)
  end
end % getra

function str = repradec(str)
  %repradec: replace string stuff and get it into num
  str = lower(str);
  for rep = {'h','m','s',':','°','deg','d','''','"'}
    str = strrep(str, rep{1}, ' ');
  end
  str = str2num(str);
end

function [dec_deg, dec_min] = getdec(dec)
  % getdec: convert any input DEC into deg and min
  if ischar(dec)
    dec = repradec(dec);
  end
  if isnumeric(dec)
    if isscalar(dec)
      dec_deg = fix(dec); dec_min = abs(dec - dec_deg)*60;
    elseif numel(dec) == 2
      dec_deg = dec(1);   dec_min = abs(dec(2));
    elseif numel(dec) == 3
      dec_deg = dec(1);   dec_min = abs(dec(2))+abs(dec(3)/60);
    end
  else
    disp([ mfilename ': invalid DEC' ])
    disp(dec)
  end
end % getdec

function ret=open_system_browser(url)
  % opens URL with system browser. Returns non zero in case of error.
  if strncmp(url, 'file://', length('file://'))
    url = url(8:end);
  end
  ret = 1;
  if ismac,      precmd = 'DYLD_LIBRARY_PATH= ;';
  elseif isunix, precmd = 'LD_LIBRARY_PATH= ; '; 
  else           precmd=''; end
  if ispc
    ret=system([ precmd 'start "' url '"']);
  elseif ismac
    ret=system([ precmd 'open "' url '"']);
  else
    [ret, message]=system([ precmd 'xdg-open "' url '"']);
  end
end % open_system_browser


function h = image_build(tag, ip, ud, self)
  h = figure('Tag',tag, 'Name', [ 'StarBook: ' ip ], ...
    'MenuBar','none', 'ToolBar','none', ...
    'WindowButtonUpFcn',    @ButtonUpCallback, ...
    'WindowScrollWheelFcn', @ScrollWheelCallback, ...
    'CloseRequestFcn',@MenuCallback, ...
    'UserData', ud);
  % add menu entries
  m = uimenu(h, 'Label', 'File');
  uimenu(m, 'Label', 'Save',        ...
    'Callback', 'filemenufcn(gcbf,''FileSave'')','Accelerator','s');
  uimenu(m, 'Label', 'Save As...',        ...
    'Callback', 'filemenufcn(gcbf,''FileSaveAs'')');
  uimenu(m, 'Label', 'Print',        ...
    'Callback', 'printdlg(gcbf)');
  uimenu(m, 'Label', 'Close',        ...
    'Callback', 'filemenufcn(gcbf,''FileClose'')', ...
    'Accelerator','w', 'Separator','on');
    
  m = uimenu(h, 'Label', 'StarBook');
  uimenu(m, 'Label', 'Goto RA/DEC...', ...
    'Callback', @MenuCallback, 'Accelerator','g');
  uimenu(m, 'Label', 'Stop',  'Callback', @MenuCallback, 'Accelerator','s');
  uimenu(m, 'Label', 'Align', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'Zoom+', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'Zoom-', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'Home position', 'Callback', @MenuCallback);
  
    
  m = uimenu(h, 'Label', 'View');
  uimenu(m, 'Label', 'Update view','Callback', @MenuCallback, ...
    'Accelerator','u');
  src=uimenu(m, 'Label', 'Auto Update View', ...
    'Callback', @MenuCallback, 'Checked','on');
  t = uimenu(m, 'Label', 'Open SkyChart', 'Callback', @MenuCallback, ...
    'Separator','on');
  if ~exist('skychart'), set(t, 'Enable','off'); end
  uimenu(m, 'Label', 'Open <Sky-Map.org>', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'Open Location (GPS) on <Google Maps>', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'Help', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'About StarBook', 'Callback', @MenuCallback, ...
    'Separator','on');
end % image_build

% ------------------------------------------------------------------------------
% Callbacks
% ------------------------------------------------------------------------------

function ButtonDownCallback(src, evnt)
  % ButtonDownCallback: callback when user clicks on the StarBook image
  
  % this Callback can be used as a menu entry
  lab = '';
  ud = get(src, 'UserData');  % get the StarBook handle
  if ~isfield(ud, 'StarBook'), return; end
  
  sb = ud.StarBook;
  
  if ischar(evnt)
    lab = evnt;
  else

    % define areas on the 320 240 screen image
    areas = { ...
    'zoom+',        [79 81    150 68]; ...
    'zoom-',        [79 36    148 27]; ...
    'align',        [143 59   212 49]; ...
    'unset',        [16 60    86 47]; ...
    'menu',         [163 18   231 6]; ...
    'dec+',         [413 83   483 68]; ...
    'dec-',         [413 39   484 25]; ...
    'ra+',          [355 61   423 47]; ...
    'ra-',          [478 59   548 46]; ...
    'chart',        [331 19   400 5]; ...
    'TARGET',       [421 291  547 274]; ...
    'lower panel',  [5 86     553 6]; ...
    'sky',          [4 399    423 91] };
    
    % where the mouse click is
    xy = get(sb.figure, 'CurrentPoint'); 
    x = xy(1,1); y = xy(1,2);
    
    % identify the area cliked upon
    for index=1:size(areas, 1)
      % test for coordinates
      z     = areas{index, 2};
      xmin  = min(z(1),z(3));
      ymin  = min(z(2),z(4));
      xmax  = max(z(1),z(3));
      ymax  = max(z(2),z(4));
      if xmin <= x && x <= xmax && ymin <= y && y <= ymax
        % found clicked area
        lab   = areas{index, 1};
        break
      end
    end
  end
  if isempty(lab), return; end
  
  ud = get(src, 'UserData');  % get the StarBook handle
  ud.clicked_button = lab;
  set(src,       'UserData', ud);
  set(sb.figure, 'UserData', ud);
  % when in GOTO state, any key -> STOP
  if strncmp(sb.state, 'GOT', 3)
    sb.stop;
    return
  end
  
  switch lower(lab)
  case 'open <sky-map.org>'
    sb.getstatus;
    web(sb);
  case 'zoom+'
    sb.zoom('in');
  case 'zoom-'
    sb.zoom('out');
  case 'align'
    sb.align;
  case {'stop','unset','lower panel'}
    sb.move(0,0,0,0);
    sb.stop;
    sb.start;
  case {'sky','menu'}
    % unused
  case {'home','home position'}
    home(sb);
  case 'dec+'
    sb.move(1,0,0,0);
  case 'dec-'
    sb.move(0,1,0,0);
  case 'ra+'
    sb.move(0,0,1,0);
  case 'ra-'
    sb.move(0,0,0,1);
  case {'chart','open skychart'}
    sb.getstatus;
    chart(sb);
  case 'update'
    sb.update;
  case {'about','about starbook'}
    try
      im = imread(fullfile(fileparts(which(mfilename)),'doc','Starbook.jpg'));
    catch
      im = '';
    end
    msg = { [ 'StarBook ' sb.version ], ...
              'A Matlab interface to control a Vixen StarBook SX mount', ...
              getstatus(sb), ...
              [ 'Motor coders XY=' num2str([sb.x sb.y]) ], ...
              [ 'http://' sb.ip ], ...
              '(c) E. Farhi GPL2 2018 <https://github.com/farhi/matlab-starbook>' };
    if ~isempty(im)
      msgbox(msg,  'About StarBook', 'custom', im);
    else
      helpdlg(msg, 'About StarBook');
    end
  case {'place','location','open location (gps) on <google maps>'}
    e = double(sb.place{2})+double(sb.place{3})/60;
    if sb.place{1} == 'W', e=-e; end
    n = double(sb.place{5})+double(sb.place{6})/60;
    if sb.place{4} == 'S', n=-n; end
    url = sprintf('https://maps.google.fr/?q=%f,%f', n, e);
    % open in system browser
    disp(url)
    open_system_browser(url);
  case {'goto','gotoradec','target','goto ra/dec...'}
    sb.gotoradec;
  case {'help'}
    sb.help;
  case 'close'
    close(sb);
  end
end % ButtonDownCallback



function ButtonUpCallback(src, evnt)
  % ButtonUpCallback: callback when user release mouse button on the StarBook image
  
  ud  = get(src, 'UserData');  % get the StarBook handle
  lab = ud.clicked_button;
  sb  = ud.StarBook;
  ud.clicked_button = '';
  set(src, 'UserData', ud);
  switch lab
  case {'dec+','dec-','ra+','ra-'}
    sb.move(0,0,0,0);
  end
end % ButtonUpCallback



function MenuCallback(src, evnt)
  % MenuCallback: execute callback from menu. Basically go to ButtonDownCallback
  %   except for the Auto update which starts/stops a timer

  try
    lab = get(src, 'Label');
  catch
    % is this a Figure ?
    lab = get(src, 'Name');
    lab = 'close';
  end
  switch lower(strtok(lab))
  case 'auto'
    % get the state
    checked = get(src, 'Checked');
    % get the timer
    t = get(src,'UserData');
    if isempty(t)
      return
    end
    if strcmp(checked,'off')
      % check and start timer
      set(src, 'Checked','on');
      if strcmp(t.Running,'off') start(t); end
    else
      set(src, 'Checked','off');
      if strcmp(t.Running,'on') stop(t); end
    end
  otherwise
    feval(@ButtonDownCallback, gcbf, lab);
  end
 
end % MenuCallback

function ScrollWheelCallback(src, evnt)
  % ScrollWheelCallback: callback to change speed/zoom with mouse wheel
  
  ud  = get(src, 'UserData');  % get the StarBook handle
  sb  = ud.StarBook;
  speed = sb.getspeed+evnt.VerticalScrollCount;
  sb.setspeed(speed);
  sb.image;
end % ScrollWheelCallback


function TimerCallback(src, evnt)
  % TimerCallback: update view from timer event
  sb = get(src, 'UserData');
  if isvalid(sb), sb.update; 
  else delete(src); end
end % TimerCallback


