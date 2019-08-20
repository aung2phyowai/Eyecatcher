function varargout = EyeCatcherLiteGUI(varargin)
% EyeCatcherLiteGUI MATLAB code for EyeCatcherLiteGUI.fig
%      EyeCatcherLiteGUI, by itself, creates a new EyeCatcherLiteGUI or raises the existing
%      singleton*.
%
%      H = EyeCatcherLiteGUI returns the handle to a new EyeCatcherLiteGUI or the handle to
%      the existing singleton*.
%
%      EyeCatcherLiteGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in EyeCatcherLiteGUI.M with the given input arguments.
%
%      EyeCatcherLiteGUI('Property','Value',...) creates a new EyeCatcherLiteGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before EyeCatcherLiteGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to EyeCatcherLiteGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help EyeCatcherLiteGUI

% Last Modified by GUIDE v2.5 06-Apr-2017 09:41:11

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @EyeCatcherLiteGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @EyeCatcherLiteGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before EyeCatcherLiteGUI is made visible.
function EyeCatcherLiteGUI_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<*INUSL>
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to EyeCatcherLiteGUI (see VARARGIN)

% Choose default command line output for EyeCatcherLiteGUI
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes EyeCatcherLiteGUI wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% check participant data can be found (defensive, will also check when
% press enter)
mpath = strrep(which(mfilename()),[mfilename() '.m'],'');
partinfo_fn = fullfile(mpath, '../../data/__PARTINFO/partinfo.csv');
if ~exist(partinfo_fn, 'file')
    close(gcf);
    error('Internal error -- cannot find partinfo at following location: %s', partinfo_fn);
end

% make GUI fill entire upper half of screen
set( findall( gcf, '-property', 'Units' ), 'Units', 'Normalized' ); % scale internal elements
set(gcf, 'units','normalized','outerposition',[0 .5 .95 .5]);

% Create a new pure-Java undecorated JFrame to serve as a background/splash
% screen
% import javax.swing.*;
% jFrame = JFrame( 'EyeCatcherLiteSplash' );
% jFrame.setUndecorated(true);
% % Move the JFrame's on-screen location just on top of the original
% jFrame.setLocation(0, 0);
% % Set the JFrame's size to screen size
% screensize = get( 0, 'Screensize' );
% jFrame.setSize(screensize(3)*2, screensize(4)*2);
% % Make the new JFrame visible
% jFrame.setVisible(true);
% % Save handle to jFrame to gui data structure
% handles.jFrame = jFrame; 
% guidata(hObject, handles);

% #################################
% open touchscreen keyboard, /b to stop it from blocking matlab
% system('start /b %windir%\system32\osk.exe');
% #################################

set(gcf,'CloseRequestFcn',@EyeCatcherLiteGUI_CloseRequestFcn);
  
% for debugging:
set(handles.etID,'string','Peter12345');
set(handles.etDOB,'string','27/01/1986');


% --- Outputs from this function are returned to the command line.
function varargout = EyeCatcherLiteGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Get default command line output from handles structure
varargout{1} = handles.output;

function [] = EyeCatcherLiteGUI_CloseRequestFcn(hObject, eventdata, handles)

    % #################################
    % close touchscreen keyboard, >NUL to suppress outout to console
    %system('taskkill /F /IM osk.exe >NUL');
    %system('runas /user:petejonze@gmail.com /savecred "taskkill /F /IM osk.exe >NUL"');
    %system('runas /user:Administrator /savecred "taskkill /im osk.exe">NUL');
    %system('tskill osk');
    % #################################
    
    % close background splashscreen
    %myhandles = guidata(gcbo);
    %myhandles.jFrame.dispose()
    
    % destruct
	delete(hObject);


% --- Executes on button press in pbStart.
function pbStart_Callback(hObject, eventdata, handles)
% hObject    handle to pbStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
      
    % init
	clc
    
    % init
    set(handles.stFeedback,'string',''); % blank-out feedback text

    % get user inputs
    patientcode = get(handles.etID,'string');
    dob = get(handles.etDOB,'string');
    if get(handles.rbLeft,'value')==1
        eye = 0;
    elseif get(handles.rbRight,'value')==1
        eye = 1;
    elseif get(handles.rbBoth,'value')==1
        eye = 2;
    else
        error('?????');
    end
    manuallySuppressEyetrackerCalib = get(handles.rbCalibNo,'value')==1;
    
    % validate user inputs
    if isempty(patientcode)
        set(handles.stFeedback,'string','ID cannot be blank');
        return
    elseif isempty(dob)
        set(handles.stFeedback,'string','DOB cannot be blank');
        return
    end
    % validate dob
    if isempty(regexp(dob,'^[0-3][0-9]/[0-1][0-9]/[1-2][0-9]{3}$','match','once'))
        set(handles.stFeedback,'string','Invalid DOB format. DOB must be in format dd/mm/yyyy');
        return
    end
    try % defensive:
        datenum(dob, 'dd/mm/yyyy');
    catch
        set(handles.stFeedback,'string','Invalid DOB format. DOB must be in format dd/mm/yyyy');
        return
    end
    % nb: crude: doesn't check for n days n month, leap year, etc.
    if (str2double(dob(1:2)) < 1) || (str2double(dob(1:2)) > 31)
        set(handles.stFeedback,'string', 'Invalid DOB. Day must be in the range: 1--31');
        return
    elseif (str2double(dob(4:5)) < 1) || (str2double(dob(1:2)) > 31)
        set(handles.stFeedback,'string', 'Invalid DOB. Month must be in the range: 1--12');
        return
    end
    if datenum(dob, 'dd/mm/yyyy')<datenum('01/01/1850', 'dd/mm/yyyy') || datenum(dob, 'dd/mm/yyyy')>now()
        set(handles.stFeedback,'string', sprintf('Impossible DOB. Must be in the range: 01/01/1850 -- %s', datestr(now(), 'dd/mm/yyyy')));
        return
    end

    % close GUI
    close(gcf)
    
    % ---------------------------------------------------------------------
    % launch program
    mpath = strrep(which(mfilename()),[mfilename() '.m'],'');
    datadir = fullfile(mpath, '../../data');
    partinfo_fn = fullfile(mpath, '../../data/__PARTINFO/partinfo.csv');
    if ~exist(datadir, 'dir')
        error('Internal error -- cannot find data directory at expected location: %s', datadir);
    end
    if ~exist(datadir, 'file')
        error('Internal error -- cannot find partinfo file at expected location: %s', partinfo_fn);
    end
        
    % load participants data
    dat = csv2struct(partinfo_fn);

    % if this is the first ever entry, set pid to 1
    if isempty(dat.patientcode)
        pid = 1;
        % enter details into partinfo.csv & resave (obv a crude data
        % mangement system, but sufficient for now)
        dat.id           = pid;
        dat.dob          = dob;
        dat.patientcode	= patientcode;
        struct2csv(dat, partinfo_fn, true);
%         sid = 1;
    else    
        % ensure all patient code values is a cellarray
        if ~iscell(dat.patientcode)
            dat.patientcode = num2cell(dat.id);
        end
        % ensure that all patient code entries are strings (all number entries
        % will have been automatically stored as numeric by csv2struct)
        idx = ~cellfun(@ischar, dat.patientcode); % non-strings
        if any(idx)
            dat.patientcode(idx) = any2str(dat.patientcode(idx));
        end
        
        % repeat for DOB
        if ~iscell(dat.dob)
            dat.dob = num2cell(dat.dob);
        end
        idx = ~cellfun(@ischar, dat.dob); % non-strings
        if any(idx)
            dat.dob(idx) = any2str(dat.dob(idx));
        end
        
        % check if participant can be found already in record
      	idx = ismember(dat.dob, dob) & ismember(dat.patientcode, patientcode);
        if sum(idx) > 1
            error('Internal error -- multiple matches??');
        elseif any(idx)
            % participant previously entered, get their details
            pid = dat.id(idx);
            partdatadir = fullfile(datadir, num2str(pid));
            if ~exist(partdatadir, 'dir')
                warning('Internal error -- participant registered, but no data directory found??');
%                 sid = 1;
            else
%                 files = dir(fullfile(partdatadir, '*.csv'));
%                 fnames = {files.name}';
%                 fnames([files.isdir]) = []; % remove any dirs
%                 ptn = sprintf('(?<=EyecatcherLite-%i-)[\\d]+', pid);
%                 sids = str2double(regexp(fnames, ptn, 'match','once'));
%                 if isempty(sids)
%                     sid = 1;
%                 else
%                     sid = max(sids)+1; % find highest number and increment by 1
%                 end
            end
        else % new participant, assign new pid, enter detals into partinfo.csv, and set sid to 1
            % determine pid
            pid = max(dat.id)+1; % find highest number and increment by 1
            % enter details into partinfo.csv & resave (obv a crude data
            % mangement system, but sufficient for now)
            dat.id(end+1)           = pid;
            dat.dob{end+1}          = dob;
            dat.patientcode{end+1}	= patientcode;
            struct2csv(dat, partinfo_fn, true);
            % determine sid
%             sid = 1;
        end
    end

    % #################################
    % base config filename
    cfg = 'ecl_v0_0_13';
    
    % append if using Surface Pro 3 to config filename
 	[w,~]=Screen('DisplaySize', 0);
    isSurfacePro3 = w==254;
    if isSurfacePro3
        cfg = sprintf('%s_SP3', cfg);
    end

    % RUN!       
    try
        for i = 1:length(eye)
            runTimeParams = struct('eye',eye(i), 'manuallySuppressEyetrackerCalib',manuallySuppressEyetrackerCalib);
            ptr('-run','EyecatcherHome', '-from',cfg, '-pid',pid, '-sid',i, '-autoStart',true, '-skipLoginChecks',true, 'skipWriteCheck',true, 'runTimeParams',runTimeParams); % skip write check desirable, but slow
        end
    catch ME % if user pressed escape, suppress error and return to menu
        if isempty(regexp(ME.message, 'Aborted by user', 'match', 'once'))
            rethrow(ME)
        else
            warning('Aborted by user');
        end
    end
        
    % #################################
    
    % clear memory and relaunch GUI
	clearJavaMem();
    EyeCatcherLiteGUI();
    
    
%% GUIDE JUNK -------------------------------------------------------------

function etID_Callback(hObject, eventdata, handles) %#ok<*INUSD,*DEFNU>
% hObject    handle to etID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% --- Executes during object creation, after setting all properties.
function etID_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etID (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit2_Callback(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% --- Executes during object creation, after setting all properties.
function edit2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function etDOB_Callback(hObject, eventdata, handles)
% hObject    handle to etDOB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% --- Executes during object creation, after setting all properties.
function etDOB_CreateFcn(hObject, eventdata, handles)
% hObject    handle to etDOB (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end