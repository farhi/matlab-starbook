classdef starbook < handle
  % STARBOOK a class to control the Vixen StarBook for telescope mounts.
  %   StarBook, StarBook S and StarBook Ten are supported, to control 
  %   SX, SX2, SXD2, SXP, SXW, SXD and AXD mounts.
  %
  % Initial set-up
  % ==============
  % The mount should have been aligned and configured (date, location,
  % weighting)) before, and the StarBook IP should be read accessing the
  % 'About STAR BOOK' menu item.
  %
  % Then use e.g.:
  %
  %   sb = starbook('169.254.1.1');
  %
  % to establish the connection and display the StarBook screen.
  % You may close this view without affecting the StarBook itself, and re-open it
  % anytime with:
  %
  %   sb.image; 
  %
  % The buttons are active in a similar way to the physical ones. The mouse
  % wheel allows to zoom in/out, and the display is regularly updated (5 sec).
  % You can access more actions from the top menu, and unactivate the 
  % auto-update.
  %
  % For testing purposes, you may open a simulated StarBook with:
  %
  %   sb = starbook('sim');
  %
  %  or use 'sim' as IP in the input dialogue.
  %
  % Programming the mount
  % =====================
  %  You may directly point to a named object or coordinates with:
  %
  %  >> sb.goto('M 51');
  %  >> sb.goto('13h29m52.30s','+47d11m40.0s');
  %  >> sb.goto('jupiter');
  %
  % Valid names include usual names (such as Betelgeuse, Rigel, Capella, 
  % Orion nebula, ...), as well as the major Catalogs such as:
  %
  %    - Proper Name
  %    - StarID
  %    - HD (Henry Draper)
  %    - HR (Harvard Revised)
  %    - Gliese (Gliese Catalog of Nearby Stars)
  %    - BayerFlamsteed denomination (Fifth Edition of the Yale Bright Star Catalog)
  %    - M (Messier)
  %    - NGC (New General Catalog)
  %    - IC (Index Catalog)
  %    - CGCG (Zwicky's Catalogue of Galaxies and of Clusters of Galaxies)
  %    - ESO (ESO/Uppsala Survey of the ESO(B)-Atlas)
  %    - IRAS (IRAS catalogue of infrared sources)
  %    - MCG (Morphological Catalogue of Galaxies)
  %    - PGC (Catalog of Principal Galaxies and LEDA)
  %    - UGC (Uppsala General Catalogue of Galaxies)
  %    - planet names
  %
  %  To check if the mount has reached its position, use:
  %
  %  >> sb.getstatus
  %
  %  returns a string with current physical coordinates, as well as the status such as:
  %
  %  - GOTO: indicates that the mount is moving (MOVING)
  %  - SCOPE: indicates that the mount is idle (TRACKING)
  %  - USER: waiting for physical User input
  %  - INIT: not ready yet
  %  - CHART: in Chart mode
  %
  % You may as well request for the mount to wait the current movement completion with:
  % 
  %  >> waitfor(sb)
  %
  % It is also possible to monitor when the mount has reached a new target with
  % the 'gotoReached' event:
  %   sb = starbook(''192.168.1.19')
  %   addlistener(sb, 'gotoReached', @(src,evt)disp('goto reached'))
  %
  % **WARNING**: if the mount has to reverse, you may loose the computer remote control, 
  % and would then need to select physically the Yes/No buttons on the StarBook.
  % The mount status should then be USER. To avoid that, check "Auto Mount Reversal"
  % menu item in the View menu. Before launching an automatic sequence, make sure the
  % scope can not collide with anything around (mount, pillar, cable...). 
  %
  % Main Methods
  % ============
  % - starbook(ip)   connect to a StarBook controller. Use ip='sim' for simulation.
  % - goto(sb, ra, dec) send StarBook to RA/DEC  (given in HH:MM and Deg:MM)
  % - goto(sb, 'M 51')  send to named object
  % - move(sb, n,s,e,w) move the SB in given direction. Use stop to abort.   
  % - align(sb)      align current coordinates to RA/DEC target     
  % - stop(sb)       stop the mount (e.g. during move/goto)
  % - setspeed(sb)   set the current zoom/mount speed 0:stop - 8:fast
  % - image(sb)      display the StarBook image (only for 320*240 screen)
  % - home(sb)       send the SB to its HOME position
  % - help(sb)       open the Help page
  % - grid(sb)       build a grid around the target. Goto to items with GOTO.
  % - waitfor(sb)    wait for the mount to stop moving
  % - get_ra(sb)     return the current RA coordinate
  % - get_dec(sb)    return the current DEC coordinate
  % - get_state(sb)  return the current mount state (GOTO/MOVING, SCOPE/IDLE)
  %
  % Other minor commands
  % ====================
  % - start(sb)      set/reset the StarBook in SCOPE mode
  % - getspeed(sb)   return the current zoom/mount speed 
  % - getstatus(sb)  get the StarBook state
  % - getxy(sb)      update motor coders     
  % - getscreen(sb)  get the StarBook image as an RGB matrix
  % - get_state(sb)  get the mount state.
  % - update(sb)     update status and image
  % - plot(sb)       same as image(sb)
  % - close(sb)      close the screen view
  % - web(sb)        show the current target on sky-map.org
  % - zoom(sb,{z})   get/set the zoom level. z can be 'in','out' or in 0-8
  % - date(sb)       get the starbook date/time
  % - findobj(sb,obj) search for an object name in star/DSO catalogs
  % - reset(sb)      hibernate the mount. Use start(sb) to restart.
  % - queue(sb, cmd) send a command
  % - revert(sb)     attempt a mount reversal. Must be close within 5 min.
  %
  % Credits: 
  % =======
  % urldownload: version 1.0 (9.81 KB) by Jaroslaw Tuszynski, 23 Feb 2016
  %   https://fr.mathworks.com/matlabcentral/fileexchange/55614-urldownload
  % 
  % rubytelescopeserver: Rob Burrowes 2013
  %   https://github.com/rbur004/rubytelescopeserver
  %
  % (c) E. Farhi, GPL2 - version 19.06.02

  properties
    ip        = '169.254.1.1';  % default IP as set in StarBook
    target_ra = struct('h',  0,'min',0);      % target RA, as struct(h,min)
    target_dec= struct('deg',0,'min',0);      % target DEC, as struct(deg,min)
    target_name=[];                           % target name
    ra        = struct('h',  0,'min',0);      % current RA, as struct(h,min)
    dec       = struct('deg',0,'min',0);      % current DEC, as struct(deg,min)
    status    = 'INIT';                       % mount state e.g. GOTO, SCOPE
    x         = 0;                            % coder X value (0:round)
    y         = 0;                            % coder Y value (0:round)
    round     = 8640000;                      % full circle coder value
    speed     = 6;                            % zoom level
    version   = '2.7 (simulate)';             % StarBook board version
    place     = { 'E' 5 2 'N' 45 2 0 };       % GPS location and hour shift/UTC
    UserData  = [];                           % for the User
    rate_ra   = 0;                            % RA current speed
    delta_ra  = 0;                            % RA current speed
    autoreverse=true;                         % when true check for mount reversal
    
  end % properties
  
  properties(Access=private)
    timer     = [];       % the current Timer object which sends a getstate regularly
    start_time= datestr(now);
    simulate  = false;    % when in simulation mode
    revert_flag= false;   % true during an auto reverse action
    figure    = [];       % figure where to display
    catalogs  = [];       % our object catalogs
    x_goto    = [];       % coder X value at GOTO
    y_goto    = [];       % coder Y value at GOTO
    t_goto    = [];       % coder time value at GOTO
    autoscreen= true;     % when true, update view automatically

  end % properties
  
  events
    gotoStart
    gotoReached
    moving
    idle
    updated
  end
  
  methods
  
    function sb = starbook(ip)
      % STARBOOK Start communication an given IP and initialize the StarBook.
      %   sb=STARBOOK(ip) specify an IP, e.g. 169.254.1.1 192.168.1.19 ...
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
      % check if IP address is reachable
      ip = java.net.InetAddress.getByName(char(sb.ip));
      if ~ip.isReachable(1000)
        disp([ '[' datestr(now) '] ' mfilename ': WARNING: can not connect to ' sb.ip '. Using simulate mode.' ])  
        sb.simulate=true;
      else
        disp([ '[' datestr(now) '] ' mfilename ': Connecting to ' sb.ip ])
      end
      
      if ~sb.simulate
        try
          ret = queue(sb.ip, 'getversion', 'version=%s');
        catch ME
          disp(getReport(ME));
          disp([ '[' datestr(now) '] ' mfilename ': Switching to simulate mode.' ])
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
      % load catalogs (to be able to give target as name)
      load(sb);
      
      sb.start_time = date(sb);
      % round: This is a full circle on the dec and ra motors in y or x coordinates.
      if ~sb.simulate
        sb.round      = queue(sb.ip, 'getround',   'ROUND=%d');
      end
      % make sure we go to SCOPE mode
      getstatus(sb);
      getxy(sb);
      start(sb);
      setspeed(sb, sb.speed);
      % create the timer for auto update
      sb.timer  = timer('TimerFcn', @TimerCallback, ...
          'Period', 5.0, 'ExecutionMode', 'fixedDelay', 'UserData', sb, ...
          'Name', mfilename);
      % display screen
      disp([ '[' datestr(now) '] ' mfilename ': Welcome to StarBook ' sb.version ])
      image(sb); % also start the timer
      
    end % starbook
    
    function load(self)
      % LOAD load catalogs for objects, stars
      disp([ '[' datestr(now) '] ' mfilename ': Welcome ! Loading Catalogs:' ]);
      self.catalogs = load(mfilename);
      
      % display available catalogs
      for f=fieldnames(self.catalogs)'
        name = f{1};
        if ~isempty(self.catalogs.(name))
          num  = numel(self.catalogs.(name).RA);
          if isfield(self.catalogs.(name), 'Description')
            desc = self.catalogs.(name).Description;
          else desc = ''; end
          disp([ '[' datestr(now) '] ' mfilename ': ' name ' with ' num2str(num) ' entries.' ]);
          disp([ '  ' desc ])
        end
      end
    end % load
    
    function [s, rev] = getstatus(self)
      % GETSTATUS Update object with current status.
      %    s=GETSTATUS(sb) Return a string indicating status.
      
      % If the mount is executing a GOTO. GOTO=1
      % States power on  => INIT
      %       Scope mode => SCOPE
      %       Chart mode => CHART
      %       In a menu  => USER
      
      % called in: update (TimerCallback), web, waitfor
      prev_state = self.status;
      if ~self.simulate
        try
          ret = queue(self.ip, 'getstatus', ...
            'RA=%d+%f&DEC=%d+%f&GOTO=%d&STATE=%4s');
        catch
          disp([ '[' datestr(now) '] ' mfilename ': halting monitoring. Restart it with "start" method.' ]);
          stop(self.timer)
        end
      else
        % we simulate a move from current to target RA/DEC
        dRA   =  (self.target_ra.h+self.target_ra.min/60) ...
                -(self.ra.h+self.ra.min/60);
        dDEC  =  (self.target_dec.deg+self.target_dec.min/60) ...
               - (self.dec.deg+self.dec.min/60);
        % max move is limited
        if abs(dRA)  > 1, dRA  =   sign(dRA); end
        if abs(dDEC) > 4, dDEC = 4*sign(dDEC); end
        % compute next position
        DEC= self.dec.deg+self.dec.min/60 + dDEC;
        [RA_h, RA_min]     = getra(self.ra.h+self.ra.min/60 + dRA);
        [DEC_deg, DEC_min] = getdec(self.dec.deg+sign(self.dec.deg)*self.dec.min/60 + dDEC);
        if abs(dRA) > .01 || abs(dDEC) > .01
          goto=1;
        else goto=0; end
        ret={ RA_h, RA_min, DEC_deg, DEC_min, goto, 'SCOP' };
      end
      [self.ra.h, self.ra.min, self.dec.deg, self.dec.min, goto] = deal(ret{1:5});
      self.ra.h    = double(self.ra.h);
      self.dec.deg = double(self.dec.deg);
      self.ra.min    = double(self.ra.min);
      self.dec.min = double(self.dec.min);
      self.status  = char(ret{6});
      if goto
        self.status= 'GOTO';
      end
      if strcmp(prev_state,'GOTO') && strcmp(self.status,'SCOP')
        notify(self,'gotoReached')
        notify(self,'idle');
      end
      [coders, rev] = getxy(self);  % update coder values
      s = [ char(self) ' ' coders ];
      if rev && ~self.revert_flag && self.autoreverse
        disp(s);
        revert(self);
      end
      notify(self,'updated');
    end % getstatus
    
    function s=char(self)
      % CHAR Return the mount state as a short string.
      s = sprintf('RA=%d+%f DEC=%d+%f [%s]', ...
        self.ra.h, self.ra.min, self.dec.deg, self.dec.min, self.status);
      if ~strncmp(self.target_name,'RA_',3)
        s = [ s ' ' self.target_name ];
      end
    end % char
    
    function revert(self)
    % REVERT Trigger a mount reversal (when close to meridian).
    
      % must be in SCOP (IDLE) state
      if ~strcmp(self.status, 'SCOP'), return; end
      disp([ '[' datestr(now) '] ' mfilename ': reverting mount...'])
      self.revert_flag = true;
      % reposition scope to its coordinates
      val=self.goto(self.ra, self.dec);
      if isempty(val)
        waitfor(self);
      end
      self.revert_flag = false;
    end % revert

    function val=goto(self, ra_h, ra_min, dec_deg, dec_min)
      % GOTO Send the mount to given RA/DEC coordinates.
      %   GOTO(sb, ra_h, ra_min, dec_deg, dec_min)
      %   GOTO(sb, object_name)
      %   GOTO(sb, ra_h, dec_deg)
      %
      % Right Ascension can be given as:
      %   separate H, M arguments
      %   a single number in H (=DEG/15)
      %   a vector [H,M] or [H,M,S]
      %   a string such as HHhMMmSSs, HH:MM:SS, HHhMM, HH:MM
      %   an object name (such as 'M 51' or 'jupiter')
      % Declinaison can be given as:
      %   separate DEG, M arguments
      %   a single number in DEG
      %   a vector [DEG,M] or [DEG,M,S]
      %   a string such as DEG°MM'SS", DEG°MM'
      %   not specified when giving a named object
      %
      % When RA and DEC are not given, a dialogue box is shown.
      %                
      %  Can return:
      %     ERROR:FORMAT	
      %     ERROR:ILLEGAL STATE	
      %     ERROR:BELOW HORIZON
      NL = sprintf('\n'); val='OK'; target_name = '';
      if nargin == 1
        prompt = {[ '{\bf \color{blue}Enter Right Ascension RA} ' NL ...
          '(HHhMMmSSs or HH:MM:SS or HH.hh) ' NL ...
          'or {\color{blue}name} such as {\color{red}M 51}' ], ...
               ['{\bf \color{blue}Enter Declinaison DEC} ' NL ...
               '(DD°MM''SS" or DD°MM or DD.dd ' NL ...
               'or leave {\color{red}empty} when entering name above)' ] };
        name = 'StarBook: Goto RA/DEC: Set TARGET';
        options.Resize='on';
        options.WindowStyle='normal';
        options.Interpreter='tex';
        answer=inputdlg(prompt,name, 1, ...
          {sprintf('%dh%fm',   self.ra.h, self.ra.min), ...
           sprintf('%ddeg%fm', self.dec.deg, self.dec.min)}, options);
        if isempty(answer), return; end
        if isempty(answer{2}) || isempty(strtrim(answer{2}))
          val=goto(self, answer{1});
        else
          val=goto(self, answer{1}, answer{2});
        end
        return
      elseif nargin == 2 && ischar(ra_h)
        if any(strcmp(lower(ra_h), ...
          {'jupiter','saturn','moon','mars','mercury','neptune','plutot','uranus','venus'}))
          val=self.queue([ 'goto' ra_h ]);
          return
        end
        found = findobj(self, ra_h);
        if isempty(found)
          disp([ '[' datestr(now) '] ' mfilename ': goto: can not find object ' ra_h ])
          return;
        else target_name=ra_h;
        end
        [dec_deg, dec_min] = getdec(found.DEC);
        % Right Ascension
        [ra_h, ra_min]     = getra(found.RA/15);
      elseif nargin == 2 && isstruct(ra_h)
        found = ra_h;
        [dec_deg, dec_min] = getdec(found.DEC);
        % Right Ascension
        [ra_h, ra_min]     = getra(found.RA/15);
      elseif nargin == 3
        % Declinaison
        [dec_deg, dec_min] = getdec(ra_min);
        % Right Ascension
        [ra_h, ra_min]     = getra(ra_h);
      elseif nargin < 5
        disp([ '[' datestr(now) '] ' mfilename ': goto: wrong number of input.' ])
        return
      end
      self.target_ra.h   = ra_h;
      self.target_ra.min = ra_min;
      self.target_dec.deg= dec_deg;
      self.target_dec.min= abs(dec_min);
      
      cmd = sprintf('gotoradec?RA=%d+%f&DEC=%d+%f', ...
        self.target_ra.h,    self.target_ra.min, ...
        self.target_dec.deg, self.target_dec.min);
      disp([ '[' datestr(now) '] ' mfilename ': ' cmd ]);
      if ~self.simulate
        val=queue(self.ip, cmd, 'OK');
      else
        disp([ 'SIMU: ' cmd ]);
      end
      notify(self,'gotoStart');
      notify(self,'moving');
      if isempty(target_name)
        target_name = sprintf('RA_%d_%f_DEC_%d_%f', ...
            self.target_ra.h,    self.target_ra.min, ...
            self.target_dec.deg, self.target_dec.min);
      end
      self.target_name = target_name;
      
    end % goto
    
    function val=gotoradec(self, varargin)
      % GOTORADEC Send the mount to given RA/DEC coordinates.
      %   This is equivalent to GOTO
      val=goto(self, varargin{:});
    end % goto
    
    function ra=get_ra(self, option)
      % GET_RA Return the current mount RA coordinates.
      %   ra=GET_RA(s) Returns Right Ascension as [hh mm ss] in hours.
      %
      %   ra=GET_RA(s,'deg') Returns Right Ascension as a scalar in degrees.
      %
      %   ra=GET_RA(s,'target') Returns Target Right Ascension as [hh mm ss] in hours.
      %   ra=GET_RA(s,'target deg') Returns the same in degrees.
      if nargin < 2, option = ''; end
      if strfind(option, 'target')
        ra = double([ self.target_ra.h self.target_ra.min 0 ]);
      else
        ra = double([ self.ra.h self.ra.min 0 ]);
      end
      if strfind(option, 'deg')
        ra = (ra(1)+ra(2)/60+ra(3)/3600)*15;
      end
    end
    
    function dec=get_dec(self, option)
      % GET_DEC Return the current mount RA coordinates.
      %   dec=GET_DEC(s) Returns Declinaison as [dd mm ss] in degrees.
      %
      %   dec=GET_DEC(s,'deg') Returns Declinaison as a scalar in degrees.
      %
      %   dec=GET_DEC(s,'target') Returns Target Declinaison as [dd mm ss] in degrees.
      %   dec=GET_DEC(s,'target deg') Returns the same in degrees.
      if nargin < 2, option = ''; end
      if strfind(option, 'target')
        dec = double([ self.target_dec.h self.target_dec.min 0 ]);
      else
        dec = double([ self.dec.deg self.dec.min 0 ]);
      end
      if strfind(option, 'deg')
        dec = dec(1)+dec(2)/60+dec(3)/3600;
      end
    end
    
    function st = get_state(self)
      % GET_STATE Return the mount state, e.g. MOVING, TRACKING.
      st = self.status;
    end
    
    function c = get_catalogs(self)
      % GET_CATALOGS Get the loaded catalogs
      c = self.catalogs;
    end
    
    function home(self)
      % HOME Send mount to home position.
      disp([ '[' datestr(now) '] ' mfilename ': home' ]);
      cmd = 'gohome?home=0';
      if ~self.simulate
        queue(self.ip, cmd,'OK');
      else
        disp([ 'SIMU: ' cmd ]);
        goto(self, 0, 0);
      end
    end % home
    
    function park(self, varargin)
      % PARK Send the mount to a reference PARK position (home).
      home(self);
    end % park
    
    function move(self, north, south, east, west)
      % MOVE Move continuously the mount in given direction.
      %   MOVE(sb, north, south, east, west) toggle movement along given directions
      %   Requires STOP to stop movement.
      %
      %   north: when 1, start move in DEC+
      %   south: when 1, start move in DEC-
      %   east:  when 1, start move in RA-
      %   west:  when 1, start move in RA+
      %
      % You may as well use MOVE(sb, 'north') or MOVE(sb, 'ra+') or MOVE(sb, 'up')
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
          self.target_dec.deg+sign(self.target_dec.deg)*self.target_dec.min/60 + north-south);
      end
      notify(self, 'moving');
    end % move
    
    function setspeed(self, speed)
      % SETSPEED Set the mount speed/zoom factor from 0(stop) - 8(fast).
      %   SETSPEED(sb, speed) specify speed to use. Default is 6.
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
      % GETSPEED Return current speed.
      s = self.speed;
    end % getspeed
    
    function stop(self)
      % STOP Stop any movement.
      %  Can return "ERROR:ILLEGAL STATE".
      if ~self.simulate
        queue(self.ip, 'stop','OK');
      else
        disp([ 'SIMU: ' 'stop' ]);
        self.target_ra = self.ra;
        self.target_dec= self.dec;
      end
      move(self, 0,0,0,0);
      self.revert_flag = false;
      notify(self, 'idle');
    end % stop
    
    function start(self)
      % START Clear any error, and set the mount in move mode.
      %  Can return "ERROR:ILLEGAL STATE".
      if ~self.simulate
        queue(self.ip, 'start');
      else
        disp([ 'SIMU: ' 'start' ]);
      end
      try
        start(self.timer);
      end
      self.revert_flag = false;
    end % start
    
    function reset(self)
      % RESET Reset the StarBook to its start-up screen (park) e.g. after HOME. 
      close(self);
      stop(self);
      if ~self.simulate
        disp([ '[' datestr(now) '] ' mfilename ': reset (park). Use "start" to restart.' ]);
        cmd = [ 'http://' self.ip '/reset?reset' ];
        url = java.net.URL(cmd);
        url.openConnection;
      end
    end % reset
    
    function align(self)
      % ALIGN Align the mount to any preset RA/DEC target.
      %   One should usually issue a GOTO, and move the mount to center
      %   the actual location of the target, then issue an align.
      disp([ '[' datestr(now) '] ' mfilename ': align' ]);
      if ~self.simulate
        queue(self.ip, 'align','OK');
      else
        disp([ 'SIMU: ' 'align' ]);
      end
      % display target and current RA/DEC
    end % align
    
    function sync(self)
      % SYNC Synchronise current RA/DEC with last target.
      %   SYNC(s) tells the mount that the target (current) RA/DEC corresponds 
      %   with the previously defined target (from GOTO).
      align(self);
    end % sync
    
    function h = shift(self, varargin)
      % SHIFT Move the mount by a given amount on both axes. The target is kept.
      disp([ '[' datestr(now) '] ' mfilename ': shift: Not implemented.' ])
    end
    
    function settings(self)
      % SETTINGS Display a dialogue to set board settings.
      disp([ '[' datestr(now) '] ' mfilename ': SETTINGS: Not implemented.' ])
    end % settings
    
    function [s, rev]=getxy(self)
      % GETXY Update mount motors coder values.
      %   xy = GETXY(sb) returns a string with coders
      %
      %   [xy, reverse] = GETXY(sb) also returns a 'close to reverse' flag
      
      rev = false;
      
      if ~self.simulate
        xy     = queue(self.ip, 'getxy', 'X=%d&Y=%d');
      else xy = { 0 0 }; end
      [self.x,self.y] = deal(xy{:});
      s = sprintf('X=%d Y=%d', self.x, self.y);
      
      if self.simulate, return; end
      
      % check if the mount is close to revert ----------------------------------
      
      % returns x and y coordinates of the mount. 0,0 is the power on position
      % getround / 4 is maximum east and west (negative for east) .
      % getround / 2 is maximum south and North  (negative for south) . 
      % i.e.
      % X is the RA axis and ranges from about -2160000 (east) to 2160000 (west).
      % Y is the Dec axis ranges from from about -432000(south) to +432000(north)
      % Useful for telling if the mount should reverse
      
      
      % on RA, x can reach +/- round/4 as a 1/4th round
      delta_ra = (double(self.round/4) - abs(double(self.x)))/double(self.round);
      if delta_ra*100 <= -0.2
        beep
        disp([ '[' datestr(now) '] ' mfilename ': mount is close to revert on X (east-west=RA) motor. ' ])
        disp([ '    Delta=' num2str(delta_ra*100) ' % i.e. ' ...
               num2str(abs(delta_ra)*1800) ' min after meridian.' ])
      end
      
      % on DEC, y can reach +/- round, then has to revert
      delta_dec = double(abs(abs(self.y) -  self.round))/double(self.round);
      if delta_dec < 0.10
        disp([ '[' datestr(now) '] ' mfilename ': mount is close to revert on Y (north-south=DEC) motor. Delta='...
        num2str(delta_dec*100) ' % i.e. ' num2str(delta_dec*360) ' deg' ])
      end

      % indicate reversal when too close to USER mode
      if delta_ra*100 <= -0.3 || delta_dec < 0.01 % reach bounds
           rev = true;
      end
      
      self.delta_ra = delta_ra*1800; % in minutes
      
      % estimate sideral rate on X ---------------------------------------------
      % only in SCOPE state (not GOTO)
      scop = strcmp(self.status, 'SCOP') | strcmp(self.status, 'USER');
      
      % we reset the rate calculation every 60 sec
      if ~isempty(self.t_goto)
        dt = etime(clock, self.t_goto);
      else dt = 0; end

      if scop && dt > 60
        scop = false; dt = 0;
      end
      if ~scop
        self.x_goto=[]; self.y_goto=[]; self.t_goto=[];
      else
        % store the coder values for last GOTO / Update
        if isempty(self.x_goto) self.x_goto = self.x; dt = 0; end
        if isempty(self.y_goto) self.y_goto = self.y; end
        if isempty(self.t_goto) self.t_goto = clock;  end
      end

      % we evaluate the rate when the time diff is larger than 10 s
      if ~isempty(self.t_goto) && dt > 10
        self.rate_ra = abs(double(self.x) - double(self.x_goto))/dt;
        % compute sideral rate
        self.rate_ra = self.rate_ra/(double(self.round)/3600/24);
        
        % must do a round in 24h
        % we display a message when moving slower than 1/2 the speed
        if self.rate_ra < 0.5 && strcmp(self.status, 'SCOP')
          beep
          disp([ '[' datestr(now) '] ' mfilename ': WARNING: SLOW RA move' ])
          disp([ '    rate=' num2str(self.rate_ra) ' [sideral] delta=' num2str(delta_ra*1800) ' [min wrt meridian] ' s ])
          disp('    Check cables and tube. RA (X) is stuck ?' );
          if delta_ra < 0
            % try a mount reversal
            rev = true;
          end
        end
      end
        
    end % getxy
    
    function W = getscreen(self)
      % GETSCREEN Get an RGB image of the current StarBook screen.
      %   You may then plot the result with 'image(im)'
    
      % bitmap of what's on the screen. 320x240 12bit raw image file.
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
      % IMAGE Show the StarBook screen and allow control using mouse/menu.
      
      persistent screen_static
      
      % select figure
      ud.StarBook      = self;
      ud.clicked_button='';
      tag = [ 'StarBook_' strrep(self.ip, '.', '_') ];
      h = findall(0, 'Tag', tag);
      if isempty(h)
        h = build_interface(tag, self.ip, ud, self);
        set(0, 'CurrentFigure',h);
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
        set(self.figure, 'Name', [ 'StarBook: ' char(self) ]);
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
      % UPDATE Update the starbook status and image.
      [s, rev] = getstatus(self);
      if ishandle(self.figure)
        if self.autoscreen, image(self); end
      else self.figure = []; end
    end % update
    
    function d = date(self)
      % DATE Return the Starbook date/time.
      if ~self.simulate
        d = queue(self.ip, 'gettime',    'time=%d+%d+%d+%d+%d+%d');
        d = datestr(double(cell2mat(d)));
      else
        d = datestr(now);
      end
      
    end
    
    function h = plot(self)
      % PLOT Plot the starbook screen (same as image).
      h = image(self);
    end % plot
    
    function h = scatter(self, varargin)
      % SCATTER Display RA/DEC coordinates on the SkyChart plot.
      disp([ '[' datestr(now) '] ' mfilename ': scatter: Not implemented.' ])
    end
    
    function z = zoom(self, z)
      % ZOOM Get/set zoom level.
      %   z = ZOOM(sb) get the zoom (speed) level.
      %   ZOOM(sb, 'in')
      %   ZOOM(sb, 'out')
      %   ZOOM(sb, 0-8)
      %   ZOOM(sb, 'reset') reset to default (6)
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
      % WEB Display the starbook RA/DEC target in a web browser (sky-map.org).
      self.getstatus;
      url = sprintf([ 'http://www.sky-map.org/?ra=%f&de=%f&zoom=%d' ...
      '&show_grid=1&show_constellation_lines=1' ...
      '&show_constellation_boundaries=1&show_const_names=0&show_galaxies=1' ], ...
      self.ra.h+self.ra.min/60.0, self.dec.deg+self.dec.min/60.0, 9-self.getspeed);
      % open in system browser
      open_system_browser(url);
    end % web
    
    function url=help(self)
      % HELP Open the Help page.
      url = fullfile('file:///',fileparts(which(mfilename)),'doc','StarBook.html');
      open_system_browser(url);
    end
    
    function location(sb)
      % LOCATION Show the current GPS location on a Map.
      e = double(sb.place{2})+double(sb.place{3})/60;
      if sb.place{1} == 'W', e=-e; end
      n = double(sb.place{5})+double(sb.place{6})/60;
      if sb.place{4} == 'S', n=-n; end
      url = sprintf('https://maps.google.fr/?q=%f,%f', n, e);
      % open in system browser
      open_system_browser(url);
    end % location
    
    function close(self)
      % CLOSE Close the starbook view.
      if ishandle(self.figure); delete(self.figure); end
      self.figure = [];
    end
    
    function delete(self)
      % DELETE Close connection
      stop(self);
      close(self);
    end % delete
    
    function found = findobj(self, name)
      % FINDOBJ Find a given object in catalogs.
      %   id = findobj(sc, name) search for a given object and return ID
      %   You can then send the mount there with GOTO(sc,id)
      catalogs = fieldnames(self.catalogs);
      found = [];
      
      % check first for name without separator
      if ~any(name == ' ')
        [n1,n2]  = strtok(name, '0123456789');
        found = findobj(self, [ n1 ' ' n2 ]);
        if ~isempty(found) return; end
      end
      namel= strtrim(lower(name));
      for f=catalogs(:)'
        catalog = self.catalogs.(f{1});
        if ~isfield(catalog, 'MAG'), continue; end
        NAME = lower(catalog.NAME);
        NAME = regexprep(NAME, '\s*',' ');
        % search for name
        index = find(~cellfun(@isempty, strfind(NAME, [ ';' namel ';' ])));
        if isempty(index)
        index = find(~cellfun(@isempty, strfind(NAME, [ namel ';' ])));
        end
        if isempty(index)
        index = find(~cellfun(@isempty, strfind(NAME, [ ';' namel ])));
        end
        if isempty(index)
        index = find(~cellfun(@isempty, strfind(NAME, [ namel ])));
        end
        if ~isempty(index)
          found.index   = index(1);
          found.catalog = f{1};
          found.RA      = catalog.RA(found.index);
          found.DEC     = catalog.DEC(found.index);
          found.MAG     = catalog.MAG(found.index);
          found.TYPE    = catalog.TYPE{found.index};
          found.NAME    = catalog.NAME{found.index};
          found.DIST    = catalog.DIST(found.index);
          break;
        end
      end

      if ~isempty(found)
        disp([ '[' datestr(now) '] ' mfilename ': Found object ' name ' as: ' found.NAME ])
        if found.DIST > 0
          disp(sprintf('  %s: Magnitude: %.1f ; Type: %s ; Dist: %.3g [ly]', ...
            found.catalog, found.MAG, found.TYPE, found.DIST*3.262 ));
        else
          disp(sprintf('  %s: Magnitude: %.1f ; Type: %s', ...
            found.catalog, found.MAG, found.TYPE ));
        end
      else
        disp([ mfilename ': object ' name ' was not found.' ])
      end
    end % findobj
    
    function g=grid(self, RA, DEC, n, da)
      % GRID Return a 3x3 grid around given object or RA/DEC.
      %   g = GRID(sb, RA, DEC, n, da) build a n x n grid around RA/DEC with angular step da
      %   f = GRID(sb, name,    n, da) build a n x n grid around named object
      %
      %   The grid size can be given as n = [nDEC nRA] to specify a non-square grid
      %   as well as similarly for the angular step da = [dDEC dRA]
      %
      %   The angular step should be e.g. the field of view (FOV) in order to 
      %   build a panorama / stitch view.
      %   When using a focal length F with a camera sensor size S, the FOV is:
      %     FOV = S/F*57.3 [deg], where S and F should e.g. be in [mm]
      %
      %   With a 1200 mm focal length and an APS-C sensor 23.5x15.6, the FOV is:
      %     FOV = 0.74 and 1.12 [deg]
      %   With a 400 mm focal length and similar sensor:
      %     FOV = 2.23 and 3.36 [deg]
      %     
      % To use a 3x3 grid, you may use:
      %
      %   for t=sb.grid('M 51', 3); 
      %     sb.goto(t); 
      %     waitfor(sb); pause(1800); 
      %   end
      
      if nargin < 2, RA =[]; end
      if nargin < 3, DEC=[]; end
      if nargin < 4, n  =[]; end
      if nargin < 5, da =[]; end
      
      % input as a name
      if ischar(RA) RA = findobj(self, RA); end
      
      % input as a struct (from findobj)
      if isstruct(RA) && isfield(RA, 'RA') && isfield(RA, 'DEC')
        if nargin >= 4, da=n;  n=[]; end
        if nargin >= 3, n=DEC; end
        selected = RA;
        if isempty(selected), return; end
        RA = selected.RA/15; % deg -> hours
        DEC= selected.DEC;
      end
      if ~isempty(RA) && ~isempty(DEC) && isnumeric(RA) && isnumeric(DEC)
        RA = getra(RA);
        DEC= getdec(DEC);
      else return; end
      
      if isempty(RA)
        RA = self.target_ra.h+self.target_ra.min/60;
      end
      if isempty(DEC)
        DEC= self.target_dec.deg+self.target_dec.min/60;
      end
      if isempty(n), n=3;     end
      if isempty(da) da=0.75; end
      
      g = []; % list of targets
      
      if all(isfinite(n)) && all(isfinite(da))
        if isscalar(n),  n  = [n  n]; end
        if isscalar(da), da = [da da]; end
        n = round(n);
        index=1;
        for dec = DEC+da(1)*((0:(n(1)-1))-(n(1)-1)/2)
          for ra = RA+da(2)*((0:(n(2)-1))-(n(2)-1)/2)
            found.index   = index;
            found.catalog = 'starbook';
            found.RA      = getra(ra)*15; % hours -> deg
            found.DEC     = getdec(dec);
            found.MAG     = 0;
            found.TYPE    = 'grid';
            found.NAME    = sprintf('RA=%.2f DEC=%.2f', ra, dec);
            g     = [ g found ];
            index = index+1;
          end
        end
      end
    end % grid
    
    function waitfor(self)
      % WAITFOR Wait for the mount to be idle (not moving).
      flag = true;
      while flag
        flag = strfind(self.getstatus, 'GOTO');
        pause(2)
      end
    end % waitfor
    
    function [val, str] = queue(self, input, output)
      % QUEUE Send a command and return result.
      %   [val, str] = queue(self, input, output)
      if nargin < 2, val=[]; str=[]; return; end
      if nargin < 3, output = ''; end
      [val, str] = queue(self.ip, input, output);
    end % queue
    
    function disp(self)
      % DISP display StarBook object (details)
      
      if ~isempty(inputname(1))
        iname = inputname(1);
      else
        iname = 'ans';
      end
      if isdeployed || ~usejava('jvm') || ~usejava('desktop') || nargin > 2, id=class(self);
      else id=[  '<a href="matlab:doc ' class(self) '">' class(self) '</a> ' ...
                 '(<a href="matlab:methods ' class(self) '">methods</a>,' ...
                 '<a href="matlab:image(' iname ');">plot</a>)'  ];
      end
      self.getstatus;
      fprintf(1,'%s = %s %s [%s]\n',iname, id, self.status, self.ip);
      fprintf(1,'  RA:  %d+%.2f [h:min] (%f DEG)\n', self.ra.h, self.ra.min, ...
        (self.ra.h+self.ra.min/60)*15);
      fprintf(1,'  DEC: %d+%.2f [deg:min] (%f DEG)\n', self.dec.deg, self.dec.min, ...
        (self.dec.deg+self.dec.min/60*sign(self.dec.deg)));
      fprintf(1,'  dX:  %f [min] time to meridian\n',self.delta_ra);
      if ~isempty(self.target_name)
        fprintf(1,'  Last target:  %s\n', self.target_name);
      end
    
    end % disp
    
    function display(self)
      % DISPLAY Display StarBook object (short).
      
      if ~isempty(inputname(1))
        iname = inputname(1);
      else
        iname = 'ans';
      end
      if isdeployed || ~usejava('jvm') || ~usejava('desktop') || nargin > 2, id=class(self);
      else id=[  '<a href="matlab:doc ' class(self) '">' class(self) '</a> ' ...
                 '(<a href="matlab:methods ' class(self) '">methods</a>,' ...
                 '<a href="matlab:image(' iname ');">plot</a>,' ...
                 '<a href="matlab:disp(' iname ');">more...</a>)' ];
      end
      radec = sprintf('RA=%d+%.2f DEC=%d+%.2f', ...
          self.ra.h, self.ra.min, self.dec.deg, self.dec.min);
      fprintf(1,'%s = %s %s\n',iname, id, radec);
    end % display
    
    function about(sb)
      % ABOUT Display a dialogue about the mount status and software.
      try
        im = imread(fullfile(fileparts(which(mfilename)),'doc','Starbook.jpg'));
      catch
        im = '';
      end
      msg = { [ 'StarBook ' sb.version ], ...
                'A Matlab interface to control a Vixen StarBook SX mount', ...
                getstatus(sb), ...
                [ 'Motor coders XY=' num2str([sb.x sb.y]) ], ...
                [ 'Sideral rate=   ' num2str(sb.rate_ra) ], ...
                [ 'Time wrt Meridian= ' num2str(sb.delta_ra)  ' [min]' ], ...
                [ 'http://' sb.ip ], ...
                '(c) E. Farhi GPL2 2018 <https://github.com/farhi/matlab-starbook>' };
      if ~isempty(im)
        msgbox(msg,  'About StarBook', 'custom', im);
      else
        helpdlg(msg, 'About StarBook');
      end
    end % about
    
    function id = identify(self)
      % IDENTIFY Read the mount identification string.
      id = [ 'Vixen StarBook ' self.version ' on ' self.ip ];
    end % identify
  
  end % methods
  
end % classdef

% ------------------------------------------------------------------------------
% private functions
% ------------------------------------------------------------------------------
function [val, str] = queue(ip, input, output)
  % QUEUE sends the input, waits for completion, get result as a cell or scalar
  if nargin < 3, output = ''; end
  val = [];
  cmd = [ 'http://' ip '/' input ];
  [str,status] = urlread(cmd);
  if ~status
    error([ mfilename ': [' datestr(now) ']: error in communication with StarBook. Check IP.']);
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
      disp([ '[' datestr(now) '] ' mfilename ': WARNING: unexpected answer from StarBook.' ])
      disp(cmd)
      if strfind(str, 'ILLEGAL STATE')
        str='ERROR:ILLEGAL STATE';
        val={ nan };
      end
      disp(str);
    end
    
  end
  
  if numel(val) == 1, val=val{1}; end
end % queue



function W = im12toim24(raw)
  % IM12TOIM24 convert the 12 bit image into a 24 bit image
  
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
  % GETRA convert any input RA into h and min
  ra_h = []; ra_min = [];
  if ischar(ra)
    ra = repradec(ra);
  end
  if isstruct(ra) && isfield(ra, 'RA')
    ra = ra.RA;
  elseif isstruct(ra) && isfield(ra, 'h') && isfield(ra, 'min')
    ra_h = ra.h;
    ra_min = ra.min;
    return
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
    disp([ '[' datestr(now) '] ' mfilename ': invalid RA.' ])
    disp(ra)
  end
  if nargout == 1
    ra_h = ra_h+ra_min/60;
  end
end % getra

function str = repradec(str)
  % REPRADEC replace string stuff and get it into num
  str = lower(str);
  for rep = {'h','m','s',':','°','deg','d','''','"'}
    str = strrep(str, rep{1}, ' ');
  end
  str = str2num(str);
end

function [dec_deg, dec_min] = getdec(dec)
  % GETDEC convert any input DEC into deg and min
  if ischar(dec)
    dec = repradec(dec);
  end
  if isstruct(dec) && isfield(dec, 'DEC')
    dec = dec.DEC;
  elseif isstruct(dec) && isfield(dec, 'deg') && isfield(dec, 'min')
    dec_deg = dec.deg;
    dec_min = dec.min;
    return
  end
  if isnumeric(dec)
    if isscalar(dec)
      if dec > 0, dec_deg = floor(dec); 
      else dec_deg = ceil(dec); end
      dec_min = abs(dec - dec_deg)*60;
    elseif numel(dec) == 2
      dec_deg = dec(1);   dec_min = abs(dec(2));
    elseif numel(dec) == 3
      dec_deg = dec(1);   dec_min = abs(dec(2))+abs(dec(3)/60);
    end
  else
    disp([ '[' datestr(now) '] ' mfilename ': invalid DEC' ])
    disp(dec)
  end
  if nargout == 1
    dec_deg = dec_deg + dec_min/60;
  end
end % getdec

function ret=open_system_browser(url)
  % OPEN_SYSTEM_BROWSER opens URL with system browser. Returns non zero in case of error.
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


function h = build_interface(tag, ip, ud, self)
  % build_interface build the main GUI
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
  if self.autoscreen, n='on'; else n='off'; end
  uimenu(m, 'Label', 'Auto Update View', ...
    'Callback', @MenuCallback, 'Checked',n,'UserData',self);
  if self.autoreverse, n='on'; else n='off'; end
  uimenu(m, 'Label', 'Auto Mount Reversal', ...
    'Callback', @MenuCallback, 'Checked',n,'UserData',self);
  uimenu(m, 'Label', 'Open <Sky-Map.org>', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'Open Location (GPS) on <Google Maps>', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'Help', 'Callback', @MenuCallback);
  uimenu(m, 'Label', 'About StarBook', 'Callback', @MenuCallback, ...
    'Separator','on');
end % build_interface

% ------------------------------------------------------------------------------
% Callbacks
% ------------------------------------------------------------------------------

function ButtonDownCallback(src, evnt)
  % ButtonDownCallback callback when user clicks on the StarBook image
  
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
  try
    set(sb.figure, 'UserData', ud);
  catch
    disp('Closing orphan window');
    delete(gcbf);
    return
  end
  % when in GOTO state, any key -> STOP
  if strncmp(sb.status, 'GOT', 3)
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
  case {'update','update view'}
    disp([ mfilename ': [' datestr(now) ']: ' sb.getstatus ]);
    sb.image;
  case {'about','about starbook'}
    about(sb);
  case {'place','location','open location (gps) on <google maps>'}
    location(sb);
  case {'goto','gotoradec','target','goto ra/dec...'}
    sb.goto;
  case {'help'}
    sb.help;
  case 'close'
    close(sb);
  otherwise
    disp([ '[' datestr(now) '] ' mfilename ': unknown action ' lab ]);
  end
end % ButtonDownCallback



function ButtonUpCallback(src, evnt)
  % ButtonUpCallback callback when user release mouse button on the StarBook image
  
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
  % MenuCallback execute callback from menu. Basically go to ButtonDownCallback
  %   except for the Auto update which starts/stops a timer

  try
    lab = get(src, 'Label');
  catch
    % is this a Figure ?
    lab = get(src, 'Name');
    lab = 'close';
  end
  
  switch lower(strtok(lab))
  case {'auto','mount'} % Auto Update menu item
    % get the state
    checked = get(src, 'Checked');
    % get the timer
    s = get(src,'UserData');
    if isempty(s), return; end
    
    % set new state (toggle)
    if strcmp(checked,'off'), n='on'; else n='off'; end
    if ~isempty(strfind(lower(lab), 'view'))
      s.autoscreen   = strcmp(n, 'on');
    elseif ~isempty(strfind(lower(lab), 'reverse'))
      s.autoreverse = strcmp(n, 'on');
    end
    set(src, 'Checked',n);
    if strcmp(s.timer.Running,'off') start(s.timer); end
  otherwise
    feval(@ButtonDownCallback, gcbf, lab);
  end
 
end % MenuCallback

function ScrollWheelCallback(src, evnt)
  % ScrollWheelCallback callback to change speed/zoom with mouse wheel
  
  ud  = get(src, 'UserData');  % get the StarBook handle
  sb  = ud.StarBook;
  speed = sb.getspeed+evnt.VerticalScrollCount;
  sb.setspeed(speed);
  figure(sb.figure);
  sb.image;
end % ScrollWheelCallback


function TimerCallback(src, evnt)
  % TimerCallback update status/view from timer event
  sb = get(src, 'UserData');
  if isvalid(sb), 
    try
      sb.update; % getstatus and image
    catch ME
      getReport(ME)
    end
    
  else delete(src); end
  
end % TimerCallback

