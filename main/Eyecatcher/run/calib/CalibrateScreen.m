 classdef (Sealed) CalibrateScreen < Singleton
    % Main class for performing screen calibration
    %   
    %	run this to generate a luminance calibration for your system
    %	(for use with EyecatcherHome)  
    %
    %       NB: It is expected that calibration will be performed using a
    %           CRS ColorCal Mk2, and validated using a manual spot
    %           photometer (e.g., Minolta LS100)
    %       NB: For CRS or EIZO additional toolboxes are required (for CRS
    %           could alternatively use the code built into PTB, but
    %           couldn't be bothered figuring out how it worked
    %       NB: EIZO code not tested, and likely requires tweaking
    %       NB: This code was modified scripts from visfieldCalib
    %
    % CalibrateScreen Methods:
    %   * runAll                        - run a demo showing all steps
    %   * CalibrateScreen               - Constructor
    %   * step1_singlePoint             - Make a full set of measurements at the centre of the screen (necessary to get a rough estimate of the background, and useful for checking bit depth)
    %   * step2_allPointsWithBackground - Make a full set of raw calibration measurements at various screen locations (with an appropriate background set to account for any potential power drain effects)
    %   * step3_fitBgrdMatrix           - Fit a matrix of values specifying an appropriate command level for every background pixel (this also demonstrates how the calibration matrix can be used in practice to determine a given target level)
    %   * step4_validateFittedCalib     - Validate the calibration by displaying the background and putting targets of arbitrary random luminance at random locations
    %
    % Example:      	CalibrateScreen.runAll()
    %
    % Requires:         PsychToolBox (PTB) v3
    %                   Some misc functions contained in ivis_util
    %                   CRS toolbox, if using CRS ColorCal
    %                   EIZO toolbox, if using EIZO photometer
    %                   interpne.m
    %
    % Matlab:           v2018 onwards
    %
    % Author(s):    	Pete R Jones <petejonze@gmail.com>
    %
    % Version History:  0.0.1	PJ  18/02/2019    Initial build.
    %                   0.1.0	PJ  27/02/2019    First complete working build (4 steps).
    %
    % Copyright 2019 : P R Jones
    % *********************************************************************
    % 

    %% ====================================================================
    %  -----PROPERTIES-----
    %$ ====================================================================
    
    properties (Constant)
        %------------- internal variables (do not change) -----------------
        PHOTOMETER_MANUAL = 0;
        PHOTOMETER_CRS_ColorCalII = 1;
        PHOTOMETER_EIZO = 2;
        PHOTOMETER_SIMULATION = 3; % for debugging only
    end
    
  	properties (GetAccess = public, SetAccess = private)
        %------------------- user specified parameters --------------------
        USE_BITSTEALING     = true;
        USE_10BIT_GRAPHICS  = false;
        PHOTOMETER_TYPE     = CalibrateScreen.PHOTOMETER_CRS_ColorCalII; % CalibrateScreen.PHOTOMETER_MANUAL;
        SCREEN_NUMBER       = 0; % 0 if no external monitor, otherwise 1 or 2
        IN_FINAL_MODE       = false; % run extra checks (can be disabled for debugging)
        % initial
        BASIC_CALIB_nLevels = 10; % 1024
        % full
        FULL_CALIB_background_cdm2 = 10;
        FULL_CALIB_nLevels = 32;
        FULL_CALIB_nObservations = 1; % 3
        FULL_CALIB_nLocations_x = 5; % 5; % 10;
        FULL_CALIB_nLocations_y = 4; % 4; % 8;
        FULL_CALIB_addExtraPoints = false;
        FULL_CALIB_stimDiameter_px = 225;
        % validation
        VALIDATION_limitToRawLocations = false; % if false, will test interpolated locations too
        VALIDATION_min_cdm2 = 10;
        VALIDATION_max_cdm2 = 100;

        %------------- internal variables (do not change) -----------------
        COMPUTER_NAME
        OUTPUT_DIR
    end
    
    properties (GetAccess = private, SetAccess = private)
        % key names
        escapeKey
        spaceKey
        % 1 or 255
        CL_max
        % CRS ColorCal variables
        colorCalIsInit = false
        myCorrectionMatrix
        colorcalPortAddress = 'COM3' % !!!
    end

    
    %% ====================================================================
    %  -----PUBLIC METHODS-----
    %$ ====================================================================
        
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = CalibrateScreen()
            % CalibrateScreen Constructor.
            %
            % @date     18/02/19
            % @author   PRJ
            %
    
            %------------------Validate user inputs------------------------
            if obj.USE_BITSTEALING && obj.USE_10BIT_GRAPHICS
                error('no need to use bit stealing if you have 10 bit graphic capabilities!');
            end
            
            %------------------Initialise internal elements----------------
            % establish output directory
            obj.OUTPUT_DIR = sprintf('calib_%s', datestr(now(),1));
            if ~isdir(obj.OUTPUT_DIR)
                fprintf('Creating output directory: =%s..\n',obj.OUTPUT_DIR);
                mkdir(obj.OUTPUT_DIR);
            end
            
            % get computer name
            [~,COMPUTER_NAME] = system('hostname');
            obj.COMPUTER_NAME = deblank(COMPUTER_NAME);
                        
            % determine max Command Level
            if obj.USE_10BIT_GRAPHICS || obj.USE_BITSTEALING
                obj.CL_max = 1;     % 32-bit mode, so values scaled from 0-1, not 0-255
            else
                obj.CL_max = 255; % won't be in 32 bit mode, so 0-255
            end

			%-------------Set windows brightness to max---------------------------
			system('powershell -inputformat none (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,100)')
        end
        
        %% == METHODS =====================================================

        %%%%%%%
        %% 1 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Preliminary calibration %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        function fullFn = step1_singlePoint(obj)
            % Perform a basic calibration at a single, central location
            %
            % We will use the results of this to check for any weird non-linearities,
            % and to set the background to our approximate desired level when
            % performing the 'proper' calibration
            %
            % This will produce 1 outputs:
            %   > A calibration (.mat) file
            %
            % @date     18/02/19
            % @author   PRJ
            %              

            % input input/output levels
            in_CL = linspace(0, obj.CL_max, obj.BASIC_CALIB_nLevels); % NB CL_max=0-1, not 0-255, as using 32 bit mode
            out_cdm2 = nan(1, obj.BASIC_CALIB_nLevels);
            
% % tmp hack            
% %             stepsize = 1/2^8
% stepsize = 1/2^10
% %             stepsize = stepsize/2;
% in_CL = 0.1:stepsize:(0.1+stepsize*20)
% out_cdm2 = nan(1, length(in_CL));
% obj.BASIC_CALIB_nLevels = length(in_CL);
                        
            %------------------Initialise photometer----------------
            if ~obj.colorCalIsInit
                switch obj.PHOTOMETER_TYPE
                    case obj.PHOTOMETER_MANUAL
                        % do nothing
                    case obj.PHOTOMETER_CRS_ColorCalII
                        obj.initPhotometer();
                    case obj.PHOTOMETER_EIZO
                        error('functionality not yet written');
                    case obj.PHOTOMETER_SIMULATION
                        % do nothing
                    otherwise
                        error('Unknown photometer type specified');
                end
                obj.colorCalIsInit = true;
            end
            
            % run
            try
                % Open PTB Window
                [winhandle,rect] = obj.openPTBWindow();
                
                % define target location
                [mx, my] = RectCenter(rect);
                x_px = mx;
                y_px = my;
                
                % get gridlines
                [w_px, h_px] = RectSize(rect);
                [hlines, vlines] = obj.makeGrid(winhandle, [1 1], y_px, x_px);
                
                % draw gridlines
                Screen('DrawLines', winhandle, hlines, 2, obj.CL_max/2);
                Screen('DrawLines', winhandle, vlines, 2, obj.CL_max/2);
                
                % highlight target location
                Screen('DrawDots', winhandle, [x_px y_px], 32, obj.CL_max);
                
                % all done with preamble
                Screen('Flip', winhandle);
                
                % -------------------------- Get values ---------------------------
                % wait for space
                fprintf('Press SPACE to continue\n');
                while 1
                    [~,keyCode] = KbWait([],2);
                    if keyCode(obj.spaceKey)
                        break;
                    elseif keyCode(obj.escapeKey)
                        error('aborted by user');
                    end
                end
                
                % HACK: ensure focus back on screen
                if obj.PHOTOMETER_TYPE == CalibrateScreen.PHOTOMETER_MANUAL
                    getRealInput('Press ENTER to start measurements', true);
                    WaitSecs(0.1);
                end
                
                % !!! Get calibration values !!!
                for i = 1:obj.BASIC_CALIB_nLevels
                    Screen('FillRect',winhandle,in_CL(i));
                    Screen('Flip',winhandle);
                    
                    % HACK: make 100% sure photometer 'buffer' is cleared
                    % (this might not be necessary -- defensive)
                    if i == 1 && obj.PHOTOMETER_TYPE==obj.PHOTOMETER_CRS_ColorCalII
                        Screen('FillRect',winhandle,in_CL(i));
                        Screen('Flip',winhandle);
                        ColorCALIIGetValues(obj.colorcalPortAddress);
                        WaitSecs(1);
                    end
                    
                    % get measurement
                    switch obj.PHOTOMETER_TYPE
                        case obj.PHOTOMETER_MANUAL
                            resp = getRealInput(sprintf('%4.2f Value? ', in_CL(i)));
                            out_cdm2(i) = resp;
                        case obj.PHOTOMETER_CRS_ColorCalII
                            try
                                myRecording = ColorCALIIGetValues(obj.colorcalPortAddress);
                            catch % if connection timed out, re-initialise and try again
                                warning('??????');
                                obj.initPhotometer();
                                myRecording = ColorCALIIGetValues(obj.colorcalPortAddress);
                            end
                            % The returned values need to be multiplied by the ColorCAL II's
                            % individual calibration matrix, as retrieved earlier. This will
                            % convert the three values into CIE XYZ.
                            transformedValues = obj.myCorrectionMatrix * myRecording';
                            
                            % Convert recorded XYZ values into CIE xyY values using PsychToolbox
                            % supplied function XYZToxyY (included at the bottom of the script).
                            CIExyY = XYZToxyY(transformedValues);
                            
                            % store measurement values
                            out_cdm2(i) = CIExyY(3);
                        case obj.PHOTOMETER_EIZO
                            error('functionality not yet written');
                        case obj.PHOTOMETER_SIMULATION
                            out_cdm2(i) = 5 + (i/obj.BASIC_CALIB_nLevels).^2.3 * 150; % a crude hypothetical screen with a gamma function of 2.3, a floor of 5 cdm2, and a max luminance of 155 cdm2
                        otherwise
                            error('Unknown photometer type specified');
                    end
                end
                
                % -------------------------- Finish Up ----------------------------
                % Restore normal gamma table and close down:
                RestoreCluts;
                ListenChar(0);
                ShowCursor();
                sca();
            catch %#ok<*CTCH>
                RestoreCluts;
                ListenChar(0);
                ShowCursor();
                sca();
                psychrethrow(psychlasterror);
            end
            
            % -------------------------- fit model to data ----------------
            % NB: should probably replace with SLM toolbox for better fits
            fitOK = false; %#ok
            try
                fittedmodel = fit(out_cdm2(:), in_CL(:), 'smoothingspline'); % 'linear');
                fitOK = true;
            catch ME
                figure()
                plot(in_CL(:), out_cdm2(:), 'o-');
                warning('fit failed')
                rethrow(ME)
            end
            
            % check
            if obj.FULL_CALIB_background_cdm2 > max(out_cdm2) || obj.FULL_CALIB_background_cdm2 < min(out_cdm2)
                save('tmp.mat');
                error('fit succeeded, but observed range of output intensities (%1.2f, %1.2f) did not include the requested background level (%1.2f)', min(out_cdm2), max(out_cdm2), obj.FULL_CALIB_background_cdm2);
            end

            % ---------------------------- plot --------------------------- 
            hFig = figure();
            hold on
            
            % plot raw
            plot(in_CL, out_cdm2, 'bo');
            
            % plot fit
            background_CL = NaN; %#ok
            if fitOK
                yFit = linspace(min(out_cdm2), max(out_cdm2), 100);
                xFit = fittedmodel(yFit);
                plot(xFit, yFit, 'r-');
                % highlight background level
                background_cdm2 = obj.FULL_CALIB_background_cdm2;
                background_CL = fittedmodel(background_cdm2);
                vline(background_CL);
                hline(background_cdm2);
            end
            
            % wait until figure closed before continuing
            fprintf('Close figure window to continue\n');
            uiwait(hFig)
            
            % ---------------------------- save --------------------------- 
            fn = sprintf('step1_crudeCentralValOnly_InputOutputFunc_v1_%s.mat', datestr(now(),30));
            fullFn = fullfile(obj.OUTPUT_DIR, fn);
            % get additional variables
            background_cdm2 = obj.FULL_CALIB_background_cdm2;
            isBitStealing = obj.USE_BITSTEALING;
            is10BitGfx = obj.USE_10BIT_GRAPHICS;
            screenNum = obj.SCREEN_NUMBER;
            computerName = obj.COMPUTER_NAME;
            % save
            save(fullFn, 'in_CL', 'out_cdm2', 'x_px', 'y_px', 'w_px', 'h_px', 'background_CL', 'background_cdm2', 'isBitStealing', 'is10BitGfx', 'screenNum', 'computerName');
            % e.g., calib = load('calib_26-Feb-2019\step1_crudeCentralValOnly_InputOutputFunc_v1_20190218T142409.mat')
            
            % step 1 complete
            fprintf('Step 1 output saved as: %s\n', fullFn);
        end
        
        %%%%%%%
        %% 2 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Full calibration %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        function fullFn = step2_allPointsWithBackground(obj, fn)
            % ------------- init Command levels --------------------------- 
            in_CL = linspace(0, obj.CL_max, obj.FULL_CALIB_nLevels);
            if obj.FULL_CALIB_addExtraPoints
                functionality_not_yet_written
%                 % add extra points in the crucial region expected to contain 10 cd/m2
%                 % (expected to be between 0.15 and 0.3)
%                 idx1 = find(in_CL<0.15,1,'last');
%                 idx2 = find(in_CL>0.3,1,'first');
%                 tmp = linspace(in_CL(idx1),in_CL(idx2),(idx2-idx1)*2+1); % double the number of points within this region
%                 in_CL = [in_CL tmp(2:end-1)];
%                 
%                 % add extra at the top, to capture the tailing off near maximum
%                 tmp = (0.99-mod(0.99,stepSize):stepSize:1);
%                 in_CL = [in_CL tmp(1:end-1)];
            end
%             in_CL = in_CL - mod(in_CL,stepSize); % round each to nearest output step
            % in_CL/stepSize % sanity check
            in_CL = unique(in_CL); % remove any duplicates (and will also sort ascending)
            obj.FULL_CALIB_nLevels = length(in_CL); % reset to accomodate extra values
            
            % plot levels we will use
            figure();
            plot(in_CL,(1:obj.FULL_CALIB_nLevels),'o');
            
            if obj.IN_FINAL_MODE
                if ~getLogicalInput(sprintf('%i levels will be tested, is this correct? (y/n) ',obj.FULL_CALIB_nLevels))
                    error('set nLevels, and/or toggle addExtraPoints');
                end
                if ~getLogicalInput('Has the screen been warmed up? (y/n) ')
                    error('warm up the screen and then try again');
                end
            end
            
            % ------------- get background level ---------------------------
            calib1 = load(fn);
            % check
            if calib1.background_cdm2 ~= obj.FULL_CALIB_background_cdm2 || ~strcmpi(obj.COMPUTER_NAME, calib1.computerName)
                error('mismatch??');
            end
            % get
            background_CL = calib1.background_CL;
            
            % ------------- input inputs/output ---------------------------
            [hlines, vlines, y_px, x_px] = obj.makeGrid(obj.SCREEN_NUMBER, [obj.FULL_CALIB_nLocations_y obj.FULL_CALIB_nLocations_x]);
            out_cdm2 = nan(obj.FULL_CALIB_nLocations_y, obj.FULL_CALIB_nLocations_x, obj.FULL_CALIB_nLevels, obj.FULL_CALIB_nObservations);
            isDone = false(obj.FULL_CALIB_nLocations_y, obj.FULL_CALIB_nLocations_x);
            
            x_px = repmat(x_px, obj.FULL_CALIB_nLocations_y, 1);
            y_px = repmat(y_px', 1, obj.FULL_CALIB_nLocations_x);
            
            %------------------Initialise photometer----------------
            if ~obj.colorCalIsInit
                switch obj.PHOTOMETER_TYPE
                    case obj.PHOTOMETER_MANUAL
                        % do nothing
                    case obj.PHOTOMETER_CRS_ColorCalII
                        obj.initPhotometer();
                    case obj.PHOTOMETER_EIZO
                        error('functionality not yet written');
                    case obj.PHOTOMETER_SIMULATION
                        % do nothing
                    otherwise
                        error('Unknown photometer type specified');
                end
                obj.colorCalIsInit = true;
            end
            
            % ------------- run ---------------------------
            try
                % Open PTB Window
                [winhandle, rect] = obj.openPTBWindow();
                [w_px,h_px] = RectSize(rect);
                
                % -------------------------- Get values ---------------------------
                tic();
                isFirstPoint = true;
                try
                    while ~all(all(isDone))
                        
                        % --------------pick a random location ------------
                        tmp = Shuffle(find(isDone==0));
                        idx = tmp(1);
                        [i,j] = ind2sub(size(x_px), idx);
                        stimRect = CenterRectOnPoint([0 0 obj.FULL_CALIB_stimDiameter_px obj.FULL_CALIB_stimDiameter_px], x_px(idx), y_px(idx));
                                                
                        % --------------wait for user to position photometer ------------
                        fprintf('Press SPACE to continue\n');
                        ready = false;
                        while ~ready
                            % check for user input
                            [isDown,~,keycode]=KbCheck;
                            if isDown
                                if keycode(obj.escapeKey)
                                    fn = sprintf('ABORTED_visfield_calib_getRawData_v2_%s.mat', datestr(now(),30));
                                    fullFn = fullfile(obj.OUTPUT_DIR, fn);
                                    save(fullFn);
                                    error('aborted by user');
                                end
                                if keycode(obj.spaceKey)
                                    ready = true;
                                    KbWait([],1); % wait for key release before continuing
                                end
                            end
                            
                            % draw background
                            Screen('FillRect', winhandle, background_CL);
                            
                            % draw stim
                            Screen('FillOval', winhandle, [1 1 1], stimRect);
                            
                            % draw gridlines for aiming
                            Screen('DrawLines', winhandle, hlines, 2, obj.CL_max/2);
                            Screen('DrawLines', winhandle, vlines, 2, obj.CL_max/2);
                            
                            % Show stimulus at next display retrace:
                            Screen('Flip', winhandle);
                        end
                        
                        % HACK: ensure focus back on screen
                        if obj.PHOTOMETER_TYPE == CalibrateScreen.PHOTOMETER_MANUAL && isFirstPoint
                            getRealInput('Press ENTER to start measurements', true);
                            WaitSecs(0.1);
                            isFirstPoint = false;
                        end
                        
                        % --------------make measurements ------------
                        for l = 1:obj.FULL_CALIB_nObservations
                            for k = 1:obj.FULL_CALIB_nLevels

                                % HACK: make 100% sure photometer 'buffer' is cleared
                                % (this might not be necessary -- defensive)
                                if i == 1 && obj.PHOTOMETER_TYPE==obj.PHOTOMETER_CRS_ColorCalII
                                    Screen('FillRect',winhandle,background_CL);
                                    Screen('Flip',winhandle);
                                    ColorCALIIGetValues(obj.colorcalPortAddress);
                                    WaitSecs(1);
                                end
                                
                                % draw stimulus
                                Screen('FillRect', winhandle, background_CL); % draw background
                                Screen('FillOval', winhandle, in_CL(k), stimRect);
                                Screen('Flip', winhandle);
                                WaitSecs(1/60 * 2);
                                
                                % get measurement
                                switch obj.PHOTOMETER_TYPE
                                    case obj.PHOTOMETER_MANUAL
                                        resp = getRealInput(sprintf('%4.2f Value? ', in_CL(i)));
                                        out_cdm2(i,j,k,l) = resp;
                                    case obj.PHOTOMETER_CRS_ColorCalII
                                        try
                                            myRecording = ColorCALIIGetValues(obj.colorcalPortAddress);
                                        catch % if connection timed out, re-initialise and try again
                                            obj.initPhotometer();
                                            myRecording = ColorCALIIGetValues(obj.colorcalPortAddress);
                                        end
                                        % The returned values need to be multiplied by the ColorCAL II's
                                        % individual calibration matrix, as retrieved earlier. This will
                                        % convert the three values into CIE XYZ.
                                        transformedValues = obj.myCorrectionMatrix * myRecording';
                                        
                                        % Convert recorded XYZ values into CIE xyY values using PsychToolbox
                                        % supplied function XYZToxyY (included at the bottom of the script).
                                        CIExyY = XYZToxyY(transformedValues);
                                        
                                        % store measurement values
                                        out_cdm2(i,j,k,l) = CIExyY(3);
                                    case obj.PHOTOMETER_EIZO
                                        error('functionality not yet written');
                                    case obj.PHOTOMETER_SIMULATION
                                        out_cdm2(i,j,k,l) = 5 + (k/obj.FULL_CALIB_nLevels).^2.3 * 150; % a crude hypothetical screen with a gamma function of 2.3, a floor of 5 cdm2, and a max luminance of 155 cdm2
                                    otherwise
                                        error('Unknown photometer type specified');
                                end
                            end
                        end % end of measurements
                        
                        % end of measurements for this location
                        isDone(idx) = true;
                        
                        % save temporary file
                        save(fullfile(obj.OUTPUT_DIR, 'calib_tmp.mat'));
                        
                        % indicate point complete
                        sound(randn(4000,1)); % auditory feedback
                    end
                    
                    % Done.
                    Screen('Preference','TextAntiAliasing', 1);
                    Screen('CloseAll'); % Close all windows and textures
                catch ME
                    timeElapsed_secs = toc(); %#ok
                    fn = sprintf('CRASHED_visfield_calib_getRawData_v3_%s.mat', datestr(now(),30));
                    fullFn = fullfile(obj.OUTPUT_DIR, fn);
                    save(fullFn)
                    rethrow(ME)
                end
                toc() % end of calibration matrix

                % -------------------------- Finish Up ----------------------------
                % Restore normal gamma table and close down:
                RestoreCluts;
                ListenChar(0);
                ShowCursor();
                sca();
            catch %#ok<*CTCH>
                RestoreCluts;
                sca();
                ListenChar(0);
                ShowCursor();
                psychrethrow(psychlasterror);
            end

            % compute further convenience params
            marginLeft_px = min(x_px(:));
            marginRight_px = max(x_px(:));
            marginBottom_px = min(y_px(:));
            marginTop_px = max(y_px(:));
            y_n = size(out_cdm2,1);
            x_n = size(out_cdm2,2);
            nLevels = size(out_cdm2,3);
            

            % ---------------------------- save --------------------------- 
            fn = sprintf('step2_fullMatrix_InputOutputFunc_v1_%s.mat', datestr(now(),30));
            fullFn = fullfile(obj.OUTPUT_DIR, fn);
            % get additional variables
            background_cdm2 = obj.FULL_CALIB_background_cdm2;
            isBitStealing = obj.USE_BITSTEALING;
            is10BitGfx = obj.USE_10BIT_GRAPHICS;
            screenNum = obj.SCREEN_NUMBER;
            computerName = obj.COMPUTER_NAME;
            % save
            save(fullFn, 'in_CL', 'out_cdm2', 'x_px', 'y_px', 'w_px', 'h_px', 'background_CL', 'background_cdm2', 'marginLeft_px', 'marginRight_px', 'marginBottom_px', 'marginTop_px', 'y_n', 'x_n', 'nLevels', 'isBitStealing', 'is10BitGfx', 'screenNum', 'computerName');
            % e.g., calib = load('calib_26-Feb-2019\step2_fullMatrix_InputOutputFunc_v1_20190218T142409.mat')
            
            % step 2 complete
            fprintf('Step 2 output saved as: %s\n', fullFn);
        end
   
        %%%%%%%
        %% 3 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Fit the data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % This will produce 2 outputs:
        %   > An MxN matrix of background values, for setting the background at
        %       some specified level: XXXXXXX
        %   > The fitted calibration input-output function for setting stimuli
        %       command levels: XXXXXXX
        function fullFn = step3_fitBgrdMatrix(obj, fnRawMeasurements, quickModeForDebugging)
            % parseInputs
            if nargin < 3 || isempty(quickModeForDebugging)
                quickModeForDebugging = false;
            end
            
            % load calib
            % fn = '..\1a. Raw measurements - ColorCalII\2. main calibration\visfield_calib_getRawData_v3_20160307T154340.mat'
            calib = load(fnRawMeasurements);
            calib.nRows = size(calib.out_cdm2, 1);
            calib.nCols = size(calib.out_cdm2, 2);
            calib.nObs = size(calib.out_cdm2, 3);
            
            % average measurements across repetitions (if any)
            obs_cdm2 = mean(calib.out_cdm2,4);

            % compute constants
            marginLeft_px = calib.x_px(1,1);
            marginRight_px = calib.x_px(1,end); % w_px-calib.x_px(1,end)
            marginTop_px = calib.y_px(1,1);
            marginBottom_px = calib.y_px(end,1); % h_px-calib.y_px(end,1)
            targAbs_cdm2 = 10; % [10 50 100];

            % init
            [w_px, h_px] = RectSize(Screen('Rect', obj.SCREEN_NUMBER));
            backgroundMatrix_CL = nan(h_px, w_px, length(targAbs_cdm2));

            % if in demo mode, just run once, and then extrapolate (for
            % debugging only!)
            if quickModeForDebugging
                h_px = 1;
                w_px = 1;
            end
            
            % interp/extrap for each pixel
            fprintf('Running\n');
            tic();
            for y_px = 1:h_px
                for x_px = 1:w_px
                    if y_px == 1 && x_px == 1000
                        fprintf('Estimated time == %1.2f hours\n', (((toc()*(h_px*w_px))/1000)/60)/60);
                    end
                    if mod((y_px-1)*h_px + x_px,40960)==0
                        fprintf('. ');
                    end
                    x_norm = (x_px - marginLeft_px) / (marginRight_px - marginLeft_px);
                    y_norm = (y_px - marginTop_px)  / (marginBottom_px - marginTop_px);
                    Xi = [repmat([(calib.nRows-1)*y_norm+1 (calib.nCols-1)*x_norm+1], calib.nObs,1), (1:calib.nObs)'];
                    valsRaw_cdm2_interpolated = interpne(obs_cdm2, Xi);
                    in = calib.in_CL'; % e.g., [0 .25 .5 .75 1]';
                    out = valsRaw_cdm2_interpolated; % e.g., [2.6 11.6 39.1 88.3 158]';
                    fittedmodel = fit(out, in, 'smoothingspline'); % 'splineinterp'  'linear'  NB: splineinterp can't handle the flatlining at upper asymptote
                    backgroundMatrix_CL(y_px,x_px,:) = fittedmodel(targAbs_cdm2); %square_luminance_norm = (fittedmodel(targ_luminance) - volts_min) / (volts_max - volts_min)
                end
            end

            % if in demo mode, just run once, and then extrapolate (for
            % debugging only!)
            if quickModeForDebugging
                [h_px, w_px] = size(backgroundMatrix_CL); % restore true values
                backgroundMatrix_CL(:,:) = backgroundMatrix_CL(1,1); % replicate same values for all pixels
            end
            
            % ---------------------------- save --------------------------- 
            fn = sprintf('step3_10cdm2_backgroundMatrix_CL_v1_%s.mat', datestr(now(),30));
            fullFn = fullfile(obj.OUTPUT_DIR, fn);
            % get additional variables
            background_cdm2 = obj.FULL_CALIB_background_cdm2;
            isBitStealing = obj.USE_BITSTEALING;
            is10BitGfx = obj.USE_10BIT_GRAPHICS;
            screenNum = obj.SCREEN_NUMBER;
            computerName = obj.COMPUTER_NAME;
            % save
            save(fullFn, 'backgroundMatrix_CL', 'background_cdm2', 'fnRawMeasurements', 'w_px', 'h_px', 'isBitStealing', 'is10BitGfx', 'screenNum', 'computerName');
            % e.g., calibBgrd = load('calib_26-Feb-2019\step3_10cdm2_backgroundMatrix_CL_v1_20190226T163100.mat')

            % step 3 complete
            fprintf('Step 3 output saved as: %s\n', fullFn);
            toc()
        end
        
        %%%%%%%
        %% 4 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Validate the fitted calibration %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Perform posthoc tests (assume using a manual spot photometer for this --
        % e.g., minolta LS100)
        function [] = step4_validateFittedCalib(obj, fnCalib, fnCalibBgrd)
            % load files
            calib = load(fnCalib);          % e.g., load('calib_26-Feb-2019\step2_fullMatrix_InputOutputFunc_v1_20190218T142409.mat')
            calibBgrd = load(fnCalibBgrd);  % e.g., load('calib_26-Feb-2019\step3_10cdm2_backgroundMatrix_CL_v1_20190226T163100.mat')

            % validate: check the two files match each other
            if calib.background_cdm2 ~= calibBgrd.background_cdm2 || calib.isBitStealing ~= calibBgrd.isBitStealing || calib.is10BitGfx ~= calibBgrd.is10BitGfx || calib.screenNum ~= calibBgrd.screenNum || ~strcmpi(calib.computerName, calibBgrd.computerName)
                error('parameter mismatch detected in two calibration files?');
            end

            % validate: check the two files match the current hardware /
            % settings
            % get computer name
            [~,detectedComputerName] = system('hostname');
            detectedComputerName = deblank(detectedComputerName);
            if ~strcmpi(calib.computerName, detectedComputerName)
                error('The computer name specified in the luminance calibration file (%s) does not match the detected name of the present system (%s). Are you sure you selected the correct calibration?', calib.computerName, detectedComputerName);
            end
            % check that backgroundMatrix matches the dimensions/resolution
            % of the specified screen
            [w_px, h_px] = RectSize(Screen('Rect', obj.SCREEN_NUMBER));
            if calibBgrd.w_px ~= w_px
                error('luminance calibration pixel width (%i) does not match that of the specified screen (%i)', calibBgrd.w_px, w_px)
            end
            if calibBgrd.h_px ~= h_px
                error('luminance calibration pixel height (%i) does not match that of the specified screen (%i)', calibBgrd.h_px, h_px)
            end
            
            % ------------- run ---------------------------
            try
                % Open PTB Window
                [winhandle, rect] = obj.openPTBWindow();
                [w_px,h_px] = RectSize(rect);
                
                % create background texture
                backTex = Screen('MakeTexture', winhandle, calibBgrd.backgroundMatrix_CL, [], [], 1); % high precision (16 bit)

                % pick an initial random location & target level on first
                % trial
                generateNewStimOnNextCycle = true;

                % --------------wait for user to position photometer ------------
                fprintf('Press SPACE to test new point (ESCAPE to quit)\n');
                while 1
                    % check for user input
                    [isDown,~,keycode]=KbCheck;
                    if isDown
                        if keycode(obj.escapeKey)
                            break;
                        end
                        if keycode(obj.spaceKey)
                            generateNewStimOnNextCycle = true;
                            KbWait([],1); % wait for key release before continuing
                        end
                    end
                    
                    % pick a random target location & level
                    if generateNewStimOnNextCycle
                        % --------------pick a random location ------------
                        if obj.VALIDATION_limitToRawLocations
                            x_px = randsample(calib.x_px(:),1);
                            y_px = randsample(calib.y_px(:),1);
                        else
                            x_px = randi([0 w_px-1], 1);
                            y_px = randi([0 h_px-1], 1);
                        end
                        stimRect = CenterRectOnPoint([0 0 obj.FULL_CALIB_stimDiameter_px obj.FULL_CALIB_stimDiameter_px], x_px, y_px);
                        targAbs_cdm2 = rand()*(obj.VALIDATION_max_cdm2-obj.VALIDATION_min_cdm2)+obj.VALIDATION_min_cdm2;
                        fprintf('Attempting to present %1.2f cdm2 at location <%i, %i>\n', targAbs_cdm2, x_px, y_px);
                        
                        % get fitted calib for target location
                        % map pixel to proportion (0 <= x <= 1) of calibrated region
                        x_norm = (x_px - calib.marginLeft_px) / (calib.marginRight_px - calib.marginLeft_px);
                        y_norm = (y_px - calib.marginTop_px)  / (calib.marginBottom_px - calib.marginTop_px);
                        % interpolate luminance calibration matrix (sampled at discrete points around the screen)
                        Xi = [repmat([(calib.y_n-1)*y_norm+1 (calib.x_n-1)*x_norm+1], calib.nLevels,1), (1:calib.nLevels)'];
                        in_CL = calib.in_CL(:);                             % e.g., [0 .25 .5 .75 1]';
                        out_cdm2 = interpne(mean(calib.out_cdm2,4), Xi);    % e.g., [2.6 11.6 39.1 88.3 158]';
                        % fit model
                        fittedmodel = fit(out_cdm2, in_CL, 'smoothingspline'); % 'splineinterp'  'linear'  NB: splineinterp can't handle the flatlining at upper asymptote
                        %fittedmodel_backwards = fit(in,out,'smoothingspline');
                        
                        % apply calibration to get requisite stimulus command level
                        stimLuminance_CL = fittedmodel(targAbs_cdm2);
                        
                        % all done with generating stim params
                        generateNewStimOnNextCycle = false;
                    end
                    
                    % draw background
                    Screen('DrawTexture', winhandle, backTex);
                    
                    % draw stim
                    Screen('FillOval', winhandle, [1 1 1]*stimLuminance_CL, stimRect);
                    
                    % Show stimulus at next display retrace:
                    Screen('Flip', winhandle);
                end
                
                % -------------------------- Finish Up ----------------------------
                % Restore normal gamma table and close down:
                RestoreCluts;
                ListenChar(0);
                ShowCursor();
                sca();
            catch %#ok<*CTCH>
                RestoreCluts;
                sca();
                ListenChar(0);
                ShowCursor();
                psychrethrow(psychlasterror);
            end
        end
       
    end
     
    %% ====================================================================
    %  -----PRIVATE METHODS-----
    %$ ====================================================================
        
    methods (Access = private)

        function [] = initPhotometer(obj)
            fprintf('Initialising photometric hardware..\n');
            switch obj.PHOTOMETER_TYPE
                case obj.PHOTOMETER_MANUAL
                    % do nothing
                case obj.PHOTOMETER_CRS_ColorCalII
                    % close any extant serial connections (defensive)
                    delete(instrfindall);
                    % start by placing one's hand over the ColorCAL II sensor to block
                    % all light (or put it face down on the table)
                    disp('Please cover the ColorCAL II so that no light can enter it, then press any key');
                    % Wait for a keypress to indicate the ColorCAL II sensor is covered.
                    pause;
                    % This is a separate function (see further below in this script) that will
                    % calibrate the ColorCAL II's zero level (i.e. the value for no light).
                    ColorCALIIZeroCalibrate(obj.colorcalPortAddress);
                    % Confirm the calibration is complete. Position the ColorCAL II to take a
                    % measurement from the screen.
                    disp('OK, you can now uncover ColorCAL II.\n');
                    % Obtains the XYZ colour correction matrix specific to the ColorCAL II
                    % being used, via the CDC port. This is a separate function (see further
                    % below in this script).
                    obj.myCorrectionMatrix = getColorCALIICorrectionMatrix(obj.colorcalPortAddress);
                case obj.PHOTOMETER_EIZO
                    % setup EIZO sensor
                    fprintf('Connecting to EIZO and calibrating (may take about 10 seconds)\n');
                    EIZOSensor('init');         % connect to EIZO monitor
                    EIZOSensor('calibrate');
                    % EIZOSensor('skipcalib')
                    EIZOSensor('raise');
                otherwise
                    error('Unknown photometer type specified');
            end
            fprintf('..done\n\n\n'); % photometer initialisation complete
        end
    
        function [winhandle, rect] = openPTBWindow(obj)
            fprintf('Initialising screen hardware..\n');
            
            % This script calls Psychtoolbox commands available only in OpenGL-based
            % versions of the Psychtoolbox. The Psychtoolbox command AssertPsychOpenGL will issue
            % an error message if someone tries to execute this script on a computer without
            % an OpenGL Psychtoolbox
            AssertOpenGL();
            
            % Disable checks
            Screen('Preference', 'SkipSyncTests', 1);
            
            % Open a double-buffered fullscreen window with a gray (intensity =
            % 0.5) background and support for 16- or 32 bpc floating point framebuffers.
            PsychImaging('PrepareConfiguration');
            
            % This will try to get 32 bpc float precision if the hardware supports
            % simultaneous use of 32 bpc float and alpha-blending. Otherwise it
            % will use a 16 bpc floating point framebuffer for drawing and
            % alpha-blending, but a 32 bpc buffer for gamma correction and final
            % display. The effective stimulus precision is reduced from 23 bits to
            % about 11 bits when a 16 bpc float buffer must be used instead of a 32
            % bpc float buffer:
            PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
            
            % Optionally use bitstealing to grab a few extra bits from the colour
            % channels if using an 8-bit system
            if obj.USE_BITSTEALING
                PsychImaging('AddTask', 'General', 'EnablePseudoGrayOutput');
            end
            
            % Enable GPU's 10 bit framebuffer under certain conditions
            % (see help for this file):
            if obj.USE_10BIT_GRAPHICS
                PsychImaging('AddTask', 'General', 'EnableNative10BitFramebuffer');
            end
            
            % Open PTB Window
            [winhandle, rect] = PsychImaging('OpenWindow', obj.SCREEN_NUMBER, 0);

            % set up keyboard
            KbName('UnifyKeyNames');
            obj.escapeKey = KbName('ESCAPE');
            obj.spaceKey = KbName('space');
            % intercept keystrokes (unless need it to manually enter
            % photometer readings)
            if obj.PHOTOMETER_TYPE ~= CalibrateScreen.PHOTOMETER_MANUAL
                ListenChar(2);
            end
            
            % try to hide mouse cursor to stop it from inadvertently
            % contaminating and luminance measures
            HideCursor();
            
            % ??
            LoadIdentityClut(winhandle);

            % screen initialisation complete
            fprintf('..done\n\n\n');
        end
        
        
        function [hlines, vlines, y_px, x_px] = makeGrid(~, winhandle, gridsize, y_px, x_px)
            % get screen size
            [w_px, h_px]=Screen('WindowSize', winhandle);
            
            % init
            n = gridsize(1);
            m = gridsize(2);
            if nargin < 4 || isempty(y_px)
                % if only specified the number of horizontal lines,
                % determine best/most-likely values
                y_px = linspace(0,h_px,n+1);
                y_px(end) = [];
                y_px = y_px + diff(y_px(1:2))/2;
            end
            if nargin < 5 || isempty(y_px)
                % if only specified the number of vertical lines,
                % determine best/most-likely values
                x_px = linspace(0,w_px,m+1);
                x_px(end) = [];
                x_px = x_px + diff(x_px(1:2))/2;
            end
            
            % check
            if length(y_px) ~= n
                error('Number of horizontal line values (%i) doesnt match number specified (%i)', length(y_px), n);
            end
            if length(x_px) ~= m
                error('Number of vertical line values (%i) doesnt match number specified (%i)', length(x_px), m);
            end

            
            % create hlines
            hlines = round(y_px);
            hlines = [hlines; hlines]; hlines = hlines(:);
            hlines = [zeros(size(hlines)) hlines]';
            hlines(1,2:2:end) = w_px;
            
            % create vlines
            vlines = round(x_px);
            vlines = [vlines; vlines]; vlines = vlines(:);
            vlines = [vlines zeros(size(vlines))]';
            vlines(2,2:2:end) = h_px;
        end
       
    end
    
    %% ====================================================================
    %  -----STATIC METHODS (public)-----
    %$ ====================================================================
    
    methods (Static, Access = public)
        
        function [] = runAll(quickDemoMode)
            %------------------Initialise workspace------------------------
            clc
            close all
%             clearJavaMem()
            if nargin < 1 || isempty(quickDemoMode)
                quickDemoMode = false;
            end
            
            %---------------------------- Setup -----------------------------
            obj = CalibrateScreen()  %#ok
            if quickDemoMode % for illustration purposes only, no real measurements made and no photometer required
                 obj.USE_BITSTEALING     = true;
                 obj.USE_10BIT_GRAPHICS  = false;
                 obj.PHOTOMETER_TYPE     = CalibrateScreen.PHOTOMETER_SIMULATION; % CalibrateScreen.PHOTOMETER_MANUAL;
                 obj.SCREEN_NUMBER       = 0;
                 obj.IN_FINAL_MODE       = false; % run extra checks (can be disabled for debugging)
                 % initial
                 obj.BASIC_CALIB_nLevels = 99;
                 % full
                 obj.FULL_CALIB_background_cdm2 = 10;
                 obj.FULL_CALIB_nLevels = 5;
                 obj.FULL_CALIB_nObservations = 1; % 3
                 obj.FULL_CALIB_nLocations_x = 3; % 10;
                 obj.FULL_CALIB_nLocations_y = 2; % 8;
                 obj.FULL_CALIB_addExtraPoints = false;
                 obj.FULL_CALIB_stimDiameter_px = 200;
                 % validation
                 obj.VALIDATION_limitToRawLocations = false; % if false, will test interpolated locations too
                 obj.VALIDATION_max_cdm2 = 100;
                 obj.VALIDATION_min_cdm2 = 10;
            end

            %---------------------------- Run -----------------------------
            fnPrelim = obj.step1_singlePoint()                              %#ok
            fnCalib = obj.step2_allPointsWithBackground(fnPrelim)           %#ok
            fnCalibBgrd = obj.step3_fitBgrdMatrix(fnCalib, quickDemoMode)	%#ok
            obj.step4_validateFittedCalib(fnCalib, fnCalibBgrd)
            clear obj;
        end
        
    end
    
  	%% ====================================================================
    %  -----SINGLETON BLURB-----
    %$ ====================================================================

    methods (Static, Access = ?Singleton)
        function obj = getSetSingleton(obj)
            persistent singleObj
            if nargin > 0, singleObj = obj; end
            obj = singleObj;
        end
    end
    methods (Static, Access = public)
        function obj = getInstance()
            obj = Singleton.getInstanceSingleton(mfilename('class'));
        end
        function [] = finishUp()
            Singleton.finishUpSingleton(mfilename('class'));
        end
    end
    
end % end of class