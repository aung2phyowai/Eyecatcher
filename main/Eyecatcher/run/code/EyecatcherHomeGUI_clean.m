function varargout = EyecatcherHomeGUI(varargin)
% EyecatcherHomeGUI MATLAB code for EyecatcherHomeGUI.fig
%      EyecatcherHomeGUI, by itself, creates a new EyecatcherHomeGUI or raises the existing
%      singleton*.
%
%      H = EyecatcherHomeGUI returns the handle to a new EyecatcherHomeGUI or the handle to
%      the existing singleton*.
%
%      EyecatcherHomeGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in EyecatcherHomeGUI.M with the given input arguments.
%
%      EyecatcherHomeGUI('Property','Value',...) creates a new EyecatcherHomeGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before EyecatcherHomeGUI_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to EyecatcherHomeGUI_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help EyecatcherHomeGUI

% Last Modified by GUIDE v2.5 06-Apr-2017 09:41:11

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @EyecatcherHomeGUI_OpeningFcn, ...
                       'gui_OutputFcn',  @EyecatcherHomeGUI_OutputFcn, ...
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
end

% --- Executes just before EyecatcherHomeGUI is made visible.
function EyecatcherHomeGUI_OpeningFcn(hObject, eventdata, handles, varargin) %#ok<*INUSL>
    % This function has no output args, see OutputFcn.
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)
    % varargin   command line arguments to EyecatcherHomeGUI (see VARARGIN)

    % Choose default command line output for EyecatcherHomeGUI
    handles.output = hObject;

    % Update handles structure
    guidata(hObject, handles);

    % UIWAIT makes EyecatcherHomeGUI wait for user response (see UIRESUME)
    % uiwait(handles.figure1);

    % check participant data can be found (defensive, will also check when
    % press enter)
    mpath = strrep(which(mfilename()),[mfilename() '.m'],'');
    partinfo_fn = fullfile(mpath, '../../data/__PARTINFO/partinfo.csv');
    if ~exist(partinfo_fn, 'file')
        close(gcf);
        error('Internal error -- cannot find partinfo at following location: %s', partinfo_fn);
    end
    
    % determine which participant we are dealing with
    pid = importdata('participant_id.txt');
    
    % load data for all participants
    mpath = strrep(which(mfilename()),[mfilename() '.m'],'');
    datadir = fullfile(mpath, '../../data');
    partinfo_fn = fullfile(mpath, '../../data/__PARTINFO/partinfo.csv');
    if ~exist(datadir, 'dir')
        error('Internal error -- cannot find data directory at expected location: %s', datadir);
    end
    if ~exist(datadir, 'file')
        error('Internal error -- cannot find partinfo file at expected location: %s', partinfo_fn);
    end
    dat = csv2struct(partinfo_fn);
    
    % validate that this participant is listed
    if ~ismember(pid, dat.id)
        error('Specified participant (%i) not found in partinfo.csv');
    end
    
    % make GUI fill most of screen
    set( findall( gcf, '-property', 'Units' ), 'Units', 'Normalized' ); % scale internal elements
    set(gcf, 'units','normalized','outerposition',[0 0 .95 .95]);
    set(gcf,'menubar','none');
    
    % set on top
    set(gcf,'visible','on');
    WinOnTop(gcf);
    
    % hide bar at top (to prevent minimization or close)
%     set(gcf,'visible','on');
%     drawnow();
	set(gcf, 'Units', 'Pixels')
%     guipos = get(gcf,'Position') 
%     WindowAPI(gcf,'Position',guipos); 
	% WindowAPI(gcf,'Maximize')
    WindowAPI(gcf, 'Clip', true)
    
    % Create a new pure-Java undecorated JFrame to serve as a background/splash
    % screen
    import javax.swing.*;
    jFrame = JFrame( 'EyecatcherHomeSplash' );
    jFrame.setUndecorated(true);
    % Move the JFrame's on-screen location just on top of the original
    jFrame.setLocation(0, 0);
    % Set the JFrame's size to screen size
    screensize = get( 0, 'Screensize' );
    jFrame.setSize(screensize(3)*2, screensize(4)*2);
    % Make the new JFrame visible
    jFrame.setVisible(true);
    % Save handle to jFrame to gui data structure
    handles.jFrame = jFrame; 
    guidata(hObject, handles);

    % display data for this participant
    idx = pid == dat.id;
    set(handles.hID, 'String', dat.patientcode(idx));
    set(handles.hDOB, 'String', dat.dob(idx));
    
    % #################################
    % open touchscreen keyboard, /b to stop it from blocking matlab
    % system('start /b %windir%\system32\osk.exe');
    % #################################
    
    % create custom close function
    set(gcf,'CloseRequestFcn',@EyecatcherHomeGUI_CloseRequestFcn);
end

% --- Outputs from this function are returned to the command line.
function varargout = EyecatcherHomeGUI_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% Get default command line output from handles structure
    varargout{1} = handles.output;
end


function [] = EyecatcherHomeGUI_CloseRequestFcn(hObject, eventdata, handles)

    % #################################
    % close touchscreen keyboard
%     system('tskill osk');
    % #################################
    
% do nothing    
%     % close background splashscreen
%     myhandles = guidata(gcbo);
%     myhandles.jFrame.dispose()
%     
%     % destruct
% 	delete(hObject);
end

% --- Executes on button press in pbStart.
function pbStart_Callback(hObject, eventdata, handles)
% hObject    handle to pbStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    % RUN! [button mode]
    try
        % from quickstart_bothEyes.m
        clearAbsAll();
        clc;
        cfg = 'ecl_v0_0_13';
        doPlot = false;
        pid = importdata('participant_id.txt');

        % 1: Right Eye
        sid = 1;
        eye = 1; % 0==left, 1==right
        manuallySuppressEyetrackerCalib = false;
        runTimeParams = struct('eye',eye, 'manuallySuppressEyetrackerCalib',manuallySuppressEyetrackerCalib, 'doPlot',doPlot);
        ptr('-run','EyecatcherHome', '-from',cfg, '-pid',pid, '-sid',sid, '-autoStart',true, '-skipLoginChecks',true, 'skipWriteCheck',true, 'runTimeParams',runTimeParams)
        % ptr('-run','EyecatcherHome', '-from',cfg, 'skipWriteCheck',true, 'runTimeParams',runTimeParams

        % 2: Left Eye
        sid = 2;
        eye = 0; % 0==left, 1==right
        runTimeParams = struct('eye',eye, 'manuallySuppressEyetrackerCalib',manuallySuppressEyetrackerCalib, 'doPlot',doPlot);
        ptr('-run','EyecatcherHome', '-from',cfg, '-pid',pid, '-sid',sid, '-autoStart',true, '-skipLoginChecks',true, 'skipWriteCheck',true, 'runTimeParams',runTimeParams)

    catch ME % if user pressed escape during experiment, suppress error and return to menu
        if isempty(regexp(ME.message, 'Aborted by user', 'match', 'once'))
            rethrow(ME)
        else
            warning('Aborted by user');
        end
    end

    % #################################

    % clear memory and relaunch GUI
    clearJavaMem();
    EyecatcherHomeGUI();
end


% --- Executes on button press in pbShutDown.
function pbShutDown_Callback(hObject, eventdata, handles)
% hObject    handle to pbShutDown (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
    disp('Shutting down..')
    system('shutdown /s /t 0'); % shut down immediately
end