function [status,s] = urldownload(url,filename,varargin)
%URLDOWNLOAD writes contents of a URL as a binary file.
%   URLDOWNLOAD('URL', filename) reads the content at a URL and writes it 
%   into a binary file.
%
%   Examples:
%    url = 'https://upload.wikimedia.org/wikipedia/commons/8/84/X-ray_by_Wilhelm_R%C3%B6ntgen_of_Albert_von_K%C3%B6lliker''s_hand_-_18960123-01.jpg'
%    urldownload(url, 'xray.jpg');
%    I=imread('xray.jpg');
%    imshow(I)
%
%   From behind a firewall, use the Preferences to set your proxy server.
%
%   See also URLREAD, URLWRITE.
%
% Written by Jarek Tuszynski, Leidos, jaroslaw.w.tuszynski_at_leidos.com
% Code released under BSD License

% https://fr.mathworks.com/matlabcentral/fileexchange/55614-urldownload
%  Copyright (c) 2016, Jaroslaw Tuszynski
%  All rights reserved.

%  Redistribution and use in source and binary forms, with or without
%  modification, are permitted provided that the following conditions are
%  met:

%      * Redistributions of source code must retain the above copyright
%        notice, this list of conditions and the following disclaimer.
%      * Redistributions in binary form must reproduce the above copyright
%        notice, this list of conditions and the following disclaimer in
%        the documentation and/or other materials provided with the distribution

%  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
%  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%  POSSIBILITY OF SUCH DAMAGE.

%% create file name if missing
if nargin < 2
  filename='';
end

%% Read data from URL
catchErrors = false;
[s,status] = urlreadwrite(mfilename,catchErrors,url,varargin{:});

if ~isempty(filename)
  %% Write data into a file
  fid = fopen(filename, 'w');
  fwrite(fid, s);
  fclose(fid);
end

%% ======================================================================
% Code below is modified MATLAB's urlreadwrite function
% Find modification by searching for "Jarek Tuszynski" in the code below
%  ======================================================================
function [output,status] = urlreadwrite(fcn,catchErrors,varargin)
%URLREADWRITE A helper function for URLREAD and URLWRITE.

%   Matthew J. Simoneau, June 2005
%   Copyright 1984-2014 The MathWorks, Inc.

% This function requires Java.
error(javachk('jvm',fcn))
import com.mathworks.mlwidgets.io.InterruptibleStreamCopier;

% Be sure the proxy settings are set.
com.mathworks.mlwidgets.html.HTMLPrefs.setProxySettings

% Parse inputs.
inputs = parseInputs(fcn,varargin);
urlChar = inputs.url;

% Set default outputs.
output = '';
status = 0;

% Clean the URL for any anomolies
urlChar = cleanUrlChar(urlChar);

% GET method.  Tack param/value to end of URL.
for i = 1:2:numel(inputs.get)
    if (i == 1), separator = '?'; else separator = '&'; end
    param = char(java.net.URLEncoder.encode(inputs.get{i}));
    value = char(java.net.URLEncoder.encode(inputs.get{i+1}));
    urlChar = [urlChar separator param '=' value];
end

% Create a urlConnection.
[urlConnection,errorid] = getUrlConnection(urlChar,inputs.timeout,...
    inputs.useragent,inputs.authentication, inputs.username, inputs.password);
if isempty(urlConnection)
    if catchErrors, return
    else error(mm(fcn,errorid));
    end
end

% POST method.  Write param/values to server.
if ~isempty(inputs.post)
    try
        urlConnection.setDoOutput(true);
        urlConnection.setRequestProperty( ...
            'Content-Type','application/x-www-form-urlencoded');
        printStream = java.io.PrintStream(urlConnection.getOutputStream);
        for i=1:2:length(inputs.post)
            if (i > 1), printStream.print('&'); end
            param = char(java.net.URLEncoder.encode(inputs.post{i}));
            value = char(java.net.URLEncoder.encode(inputs.post{i+1}));
            printStream.print([param '=' value]);
        end
        printStream.close;
    catch
        if catchErrors, return
        else error(mm(fcn,'PostFailed'));
        end
    end
end

% Get the outputStream.
switch fcn
    case {'urlread', 'urldownload'} % Jarek Tuszynski modification
        outputStream = java.io.ByteArrayOutputStream;
    case 'urlwrite'
        [file,outputStream] = getFileOutputStream(inputs.filename);
end

% Read the data from the connection.
try
    inputStream = urlConnection.getInputStream;
    % This StreamCopier is unsupported and may change at any time.
    isc = InterruptibleStreamCopier.getInterruptibleStreamCopier;
    isc.copyStream(inputStream,outputStream);
    inputStream.close;
    outputStream.close;
catch e
    outputStream.close;
    if strcmp(fcn,'urlwrite')
        delete(file);
    end
    if catchErrors
        return
    elseif strfind(e.message,'java.net.SocketTimeoutException:')
        error(mm(fcn,'Timeout'));
    elseif strfind(e.message,'java.net.UnknownHostException:')
        host = regexp(e.message,'java.net.UnknownHostException: ([^\n\r]*)','tokens','once');
        error(mm(fcn,'UnknownHost',host{1}));
    elseif strfind(e.message,'java.io.FileNotFoundException:')
        error(mm(fcn,'FileNotFound'));
    elseif strfind(e.message,'java.net.Authenticator.requestPasswordAuthentication')
        error(mm(fcn,'AuthenticationFailed'));
    elseif strfind(e.message,'Server returned HTTP response code: 401 ')
        error(mm(fcn,'AuthenticationFailed'));    
    else
        error(mm(fcn,'ConnectionFailed'));
    end
end

if isempty(inputs.charset)
    contentType = char(urlConnection.getContentType);
    charsetMatch = regexp(contentType,'charset=([A-Za-z0-9\-\.:_])*','tokens','once');
    if isempty(charsetMatch)
        if strncmp(urlChar,'file:',4)
            charset = char(java.lang.System.getProperty('file.encoding'));
        else
            charset = 'UTF-8';
        end
    else
        charset = charsetMatch{1};
    end
else
    charset = inputs.charset;
end

switch fcn
    case 'urldownload' % Jarek Tuszynski addition
        output = typecast(outputStream.toByteArray','uint8');
    case 'urlread'
        output = native2unicode(typecast(outputStream.toByteArray','uint8'),charset);
    case 'urlwrite'
        output = char(file.getAbsolutePath);
end
status = 1;

function m = mm(fcn,id,varargin)
m = message(['MATLAB:' fcn ':' id],varargin{:});

function results = parseInputs(fcn,args)
p = inputParser;
p.addRequired('url',@(x)validateattributes(x,{'char'},{'nonempty'}))
if strcmp(fcn,'urlwrite')
    p.addRequired('filename',@(x)validateattributes(x,{'char'},{'nonempty'}))
end
p.addParamValue('get',{},@(x)checkpv(fcn,x))
p.addParamValue('post',{},@(x)checkpv(fcn,x))
p.addParamValue('timeout',[],@isnumeric)
p.addParamValue('useragent',[],@ischar)
p.addParamValue('charset',[],@ischar)
p.addParamValue('authentication', [], @ischar)
p.addParamValue('username', [], @ischar)
p.addParamValue('password', [], @ischar)
p.FunctionName = fcn;
p.parse(args{:})
results = p.Results;

function checkpv(fcn,params)
if mod(length(params),2) == 1
    error(mm(fcn,'InvalidInput'));
end

function [urlConnection,errorid] = getUrlConnection(urlChar,timeout,...
    userAgent,authentication,userName,password)
	
import org.apache.commons.codec.binary.Base64;	
% Default output arguments.
urlConnection = [];
errorid = '';

% Determine the protocol (before the ":").
protocol = urlChar(1:find(urlChar==':',1)-1);

% Try to use the native handler, not the ice.* classes.
switch protocol
    case 'http'
        try
            handler = sun.net.www.protocol.http.Handler;
        catch exception %#ok
            handler = [];
        end
    case 'https'
        try
            handler = sun.net.www.protocol.https.Handler;
        catch exception %#ok
            handler = [];
        end
    otherwise
        handler = [];
end

% Create the URL object.
try
    if isempty(handler)
        url = java.net.URL(urlChar);
    else
        url = java.net.URL([],urlChar,handler);
    end
catch exception %#ok
    errorid = 'InvalidUrl';
    return
end

% Get the proxy information using the MATLAB proxy API.
try
  proxy = com.mathworks.webproxy.WebproxyFactory.findProxyForURL(url);
catch
  proxy = [];
end

% Open a connection to the URL.
if isempty(proxy)
    urlConnection = url.openConnection;
else
    urlConnection = url.openConnection(proxy);
end


% Set MATLAB as the User Agent
if isempty(userAgent)
    userAgent = ['MATLAB R' version('-release') ' '  version('-description')];
end
urlConnection.setRequestProperty('User-Agent', userAgent);

% If username and password exists, perform basic authentication
if strcmpi(authentication,'Basic')
    usernamePassword = [userName ':' password];
    usernamePasswordBytes = int8(usernamePassword)';
    usernamePasswordBase64 = char(Base64.encodeBase64(usernamePasswordBytes)');
    urlConnection.setRequestProperty('Authorization', ['Basic ' usernamePasswordBase64]);
end

% Set the timeout.
if (nargin > 2 && ~isempty(timeout))
    % Handle any numeric datatype and convert.
    milliseconds = int32(double(timeout)*1000);
    % Java inteprets 0 as no timeout. This would be confusing if we rounded
    % to 0 from something else, e.g. "'timeout',.0001".
    if milliseconds == 0
        milliseconds = int32(1);
    end
    urlConnection.setConnectTimeout(milliseconds);
    urlConnection.setReadTimeout(milliseconds);
end

%set the default authenticator to null to fix g999501
java.net.Authenticator.setDefault([]);



function [file,fileOutputStream] = getFileOutputStream(location)
% Specify the full path to the file so that getAbsolutePath will work when the
% current directory is not the startup directory and urlwrite is given a
% relative path.

filename = validateFileAccess(location);
file = java.io.File(filename);
fileOutputStream = java.io.FileOutputStream(file);

function cleanUrl = cleanUrlChar(cleanUrl)
% Replace space with %20 for HTTP and HTTPS
protocol = cleanUrl(1:find(cleanUrl == ':', 1) -1);
if (strcmp(protocol, 'http') || strcmp(protocol, 'https')) && ~isempty(strfind(cleanUrl, ' '))
    warning(mm('urlread', 'ReplacingSpaces'));
    cleanUrl = regexprep(cleanUrl, ' ', '%20');
end

function filename = validateFileAccess(location)
% Ensure that the file is writeable and return full path name.

% Validate the the file can be opened. This results in a file on the disk.
fid = fopen(location,'w');
if fid == -1
    error(mm('urlwrite','InvalidOutputLocation',location))
end
fclose(fid);

% Use fopen to obtain full path to the file and to translate ~ on Unix.
fid = fopen(location);
filename = fopen(fid);
fclose(fid);

% Remove this file in case an error is issued later.
delete(location)
