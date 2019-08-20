function PsychoController = eyecatcherLite_v0_0_13(metaParams, runTimeParams, psyParams, gridParams, stimParams, lumParams, graphicParams, paradigm, eyeParams, audioParams)    
% visfield test
%
%   This program is designed to be launched via EyecatcherHomeGUI.m
%
%   EyecatcherHomeGUI is designed to be launched automatically via
%   EyecatcherHomeAutolaunch.bat (i.e., by Win+r => shell:startup => drag)
%
%
%   shell:startup
% Requires:         Toolbox: ivis v1.5
%                   Toolbox: PsychToolBox
%                   Toolbox: PsychTestRig
%
% Matlab:           v2018 onwards
%
% Example:          cfg = 'ecl_v0_0_13';
%                   i = 1
%                 	eye = 0
%                	pid = 99
%                 	manuallySuppressEyetrackerCalib = false
%                 	runTimeParams = struct('eye',eye(i), 'manuallySuppressEyetrackerCalib',manuallySuppressEyetrackerCalib);
%                	ptr('-run','EyecatcherHome', '-from',cfg, '-pid',pid, '-sid',i, '-autoStart',true, '-skipLoginChecks',true, 'skipWriteCheck',true, 'runTimeParams',runTimeParams)
%
% Author(s):    	Pete R Jones <petejonze@gmail.com>
% 
% Version History:  1.0.0	PJ  07/07/2014    Initial build.
%                   1.1.0	PJ  18/07/2014    Screen calibration, tracker calibration, myStimulus placement, myStimulus selection/adaptation. Still no support for limited-range gamma tables.
%                   1.2.0	PJ  22/07/2014    First functional (proof-of-concept) build.  Still no support for limited-range gamma tables.
%                   1.3.0	PJ  31/07/2014    Stationarity criteiron (trial onset). Heavy rewriting/streamlining.
%                   1.4.0	PJ  ??/08/2014    Pilot version 1 (worked well, but only with some people)
%                   1.5.0	PJ  30/09/2014    Tobii EyeX pilot version 1 : rough_results_average_rightEye.png
%                   1.6.0	PJ  20/10/2014    Tobii EyeX pilot version 2 : reworked grid. Attempting to refine various aspects. Cleaned up
%                   1.7.0	PJ  01/12/2014    Used for first experiment
%                   2.0.0	PJ  09/03/2015    Attempt at a rapid version, using my own eyex Matlab binding (which provides distance info), and a more intelligent prior.
%                                               - changed to Goldmann III (as per HFA) rather than IV
%                                               - changed to using ZEST algorithm (involved whole new .visfield packge)
%                   2.1.0	PJ  08/06/2015    Misc prcoedural modifications
%                   2.2.0   PJ  13/07/2015    For use with new 10-bit system
%                                               - stop background changing luminance when pseudogray disabled
%                                               - implemented new background calib
%                                               - removed redundant inputs
%                   2.3.0   PJ  15/07/2015    Miscellaneous tweeks to improve performance
%                   2.4.0   PJ  17/07/2015    Coninuted refinements
%                                               - Added eyeball (z-)distance calibration
%                                               - Changed logic so that classifier box now specified in degrees (and is sensitive to viewing distance), and dimensions changed by calling the classifier, rather than indirectly via the graphic size
%                                               - Tweaked logic for carying classifier-relaxtion with eccentricity
%                   2.4.3   PJ  21/03/2016    Correction for viewing angle
%                                             Remove bottom corners as invalid locations
%                   0.0.4   PJ  29/06/2017    "Groningen" build
%                   0.0.5   PJ  18/09/2017    "Heiko" build
%                   0.0.6   PJ  19/10/2017    Modifications based on Heiko pilots (see changes.log)
%                   0.0.7   PJ  19/10/2017    Pre-ethics
%                   0.0.8   PJ  08/02/2018    Post-ethics
%                   0.0.9   PJ  08/04/2018    Guildford piloting: tweaked the grid
%                   0.0.10  PJ  22/06/2018    Harmonized Guildford version with home version. Corrected refixation target placement. Added functionality: Allow for unplacable points to be aborted, disable distance tracking if returning implausible values
%                   0.0.11  PJ  05/07/2018    Added button (non-eyetracking) mode
%                   0.0.12  PJ  15/02/2019    For use with EyecatcherHome edition
%                                               - Added webcam recording (based on mess_recordingVideos)
%                                               - Re-integrated ZEST for thresholding
%                                               - running now primarily on HP Pavilion
%                                               - general clean up of code and comments
%                   0.0.13  PJ  05/03/2019    For use with EyecatcherHome edition
%                                               - Added improved luminance calibration routines (and moved calib subdir)
%                                               - Restructured input xml
%                                               - Fixed input parsing/validation
%                   0.0.13  PJ  08/05/2019    Added code to autoset windows brightness to 100%
%                               04/06/2019    Added initial splash screen
%                                              
% @TODO graphics.init (specially: stimWarper) will crash if attempting to
% place a graphic at an offscreen location. This shouldn't happen because
% of earlier checks, however for defensive purposes this error should be
% prevented
%
% @TODO outlier checking now throws errors ("A finished node was
% selected??") if points were aborted [NB: have disabled outlier checking
% for now]
%
% @TODO ensure videos save at a specified location.
%       save video timestamps to data file
%
% @TODO hide mouse cursor?
%
% @TODO have option for feedback to be presented cetrally
%
% @TODO add info about target position and luminance to DEBUG panel?
%
%
% Copyright 2019 : P R Jones <petejonze@gmail.com>
% *********************************************************************
% 


    %%%%%%%
    %% 1 %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Very basic init %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        fprintf('\nSetting up the basics...\n');
        
        %-------------Check OS/Matlab version------------------------------
        if ~strcmpi(computer(),'PCWIN64')
            error('This code has only been tested on Windows 7 running 64-bit Matlab\n  Detected architecture: %s', computer());
        end
        
       	%-------------Ready workspace-------------------------------------- 
        tmp = javaclasspath('-dynamic');
        clearJavaMem();
        close all;
        if length(tmp) ~= length(javaclasspath('-dynamic'))
            % MATLAB calls the clear java command whenever you change
            % the dynamic path. This command clears the definitions of
            % all Java classes defined by files on the dynamic class
            % path, removes all variables from the base workspace, and
            % removes all compiled scripts, functions, and
            % MEX-functions from memory.
            error('clearJavaMem:MemoryCleared','clearJavaMem has modified the java classpath (any items in memory will have been cleared)\nWill abort, since this is highly likely to lead to errors later.\nTry running again, or see ''help PsychJavaTrouble'' for a more permenant solution\n\ntl;dr: Try running again.\n\nFYI: the solution, in short is to open up the matlab classpath.txt file, and manually add the necessary locations. For example, for me I opened up:\n\n  %s\n\nand at the end of the file I added these two lines:\n\n  %s\n  %s\n\nand then I restarted Matlab\n\n\ntl;dr: try running script again (or edit classpath.txt).', 'C:\Program Files\MATLAB\R2016b\toolbox\local', 'C:\Users\petej\Dropbox\MatlabToolkits\Psychtoolbox\PsychJava', 'C:\Users\petej\Dropbox\MatlabToolkits\PsychTestRig\Utilities\memory\MatlabGarbageCollector.jar');
        end

        %-------------Check for requisite toolkits-------------------------
        AssertPTR();
        AssertOpenGL(); % PTB-3 correctly installed? Abort otherwise.

        %-------------Check classpath--------------------------------------
        ivis.main.IvMain.checkClassPath();

        %-------------Hardcoded User params--------------------------------  
        IN_DEBUG_MODE       = false;
        IN_SIMULATION_MODE  = false;
        IN_FINAL_MODE       = true;
        DRAW_FIX_CROSS      = true;
        IN_MOUSE_RESP_MODE	= strcmpi(paradigm.MODE, 'mousepress'); % eyetracking, mousepress
        IN_GAZE_RESP_MODE	= strcmpi(paradigm.MODE, 'eyetracking'); % eyetracking, mousepress
        RECORD_WEBCAM       = true;
        if ~IN_FINAL_MODE
            fprintf('IN_DEBUG_MODE = %i\nIN_SIMULATION_MODE = %i\nIN_FINAL_MODE = %i\nDRAW_FIX_CROSS = %i\nRECORD_WEBCAM = %i\n\n', IN_DEBUG_MODE, IN_SIMULATION_MODE, IN_FINAL_MODE, DRAW_FIX_CROSS, RECORD_WEBCAM);
        end
        % media files
        RESOURCES_DIR   = fullfile('..', 'resources');
        SND_DIR         = fullfile(RESOURCES_DIR, 'audio', 'wav');
        IMG_DIR         = fullfile(RESOURCES_DIR, 'images');
        % location of output: data logs
        LOG_RAW_DIR     = fullfile('..', '..', 'data', '__OUT_EYETRACKING', 'raw');
        LOG_DAT_DIR     = fullfile('..', '..', 'data', '__OUT_EYETRACKING', 'data');
        LOG_DIARY_DIR 	= fullfile('..', '..', 'data', '__OUT_DIARY');
        LOG_DIARY_FULLFN= fullfile(LOG_DIARY_DIR, sprintf('commandline-%s.txt', datestr(now(),30)));
        % location of output: webcam
        WEBCAM_OUT_DIR 	= fullfile('..', '..', 'data', '__OUT_WEBCAM');
        % location of output: images of headline results
        RESULTIMAGES_DIR     = fullfile('..', '..', 'data', '__OUT_RESULTIMAGES');
        % misc
        samplingRate_hz = 55;
        N_CALIB_SAMPLES_PER_LOC = 20;
              
        %-------------Validate-------
        if IN_DEBUG_MODE && IN_FINAL_MODE
            error('Inconsistent user inputs. Cannot be in DEBUG mode if in FINAL mode');
        end
        if IN_SIMULATION_MODE && IN_FINAL_MODE
            error('Inconsistent user inputs. Cannot be in SIMULATE mode if in FINAL mode');
        end
        if ~IN_MOUSE_RESP_MODE && ~IN_GAZE_RESP_MODE
            error('Inconsistent user inputs. Some form of response mode required!');
        end
        
        %-------------Ensure requisite output directories exist--------------------------------  
        dirs = {LOG_RAW_DIR, LOG_DAT_DIR, WEBCAM_OUT_DIR, RESULTIMAGES_DIR};
        for i = 1:length(dirs)
            if ~isfolder(dirs{i})
                if IN_DEBUG_MODE, warning('Required directory not found, creating: %s..\n', dirs{i}); end
                mkdir(dirs{i});
            end
        end 
        
        %-------------Add any requisite paths------------------------------ 
        import ivis.main.* ivis.classifier.* ivis.broadcaster.* ivis.math.* ivis.graphic.* ivis.audio.* ivis.log.* ivis.calibration.*;
        import visfield.graphic.* visfield.math.* visfield.jest.*

        %-------------Clear old memory-------------------------------------
        if IN_GAZE_RESP_MODE
            clear myex
        end
        
        %-------------Display key params to user---------------------------
        if IN_DEBUG_MODE
            dispStruct(metaParams)
        end
        
        %-------------Set windows brightness to max---------------------------
        system('powershell -inputformat none (Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,100)')

        

    %%%%%%%
    %% 2 %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Validate User Inputs  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        if IN_DEBUG_MODE
            fprintf('\nVaidating inputs...\n');
        end

        %-------------runTimeParams----------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('eye',                        	[],     @(x)ismember(x,[0 1 2]));
        p.addParameter('manuallySuppressEyetrackerCalib',false,  @islogical);
        p.addParameter('doPlot',                         true,   @islogical);
        p.addParameter('COMMENT',[]);
        p.parse(runTimeParams);
        % insert optional values:
        runTimeParams.manuallySuppressEyetrackerCalib = p.Results.manuallySuppressEyetrackerCalib;
        runTimeParams.doPlot = p.Results.doPlot;

        %-------------psyParams-------------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('mode',                      	[],     @(x)ismember(lower(x),{'threshold','fixed'}));
        p.addParameter('dynamicRange_db',            	[],     @isPositiveInt);
        p.addRequired('fixed');
        p.addRequired('threshold');
        p.addParameter('COMMENT',[]);
        p.parse(psyParams, 'mode','fixed','threshold');
        
        p = inputParser; p.StructExpand = true;
        p.addParameter('dB_offset',                   	[],     @isnumeric);
        p.addParameter('nFalsePositive',               	[],     @isNonNegativeNum);
        p.addParameter('COMMENT',[]);
        p.parse(psyParams.fixed);
        
        p = inputParser; p.StructExpand = true;
        p.addParameter('dummy',            	[],     @ischar);
        p.addParameter('COMMENT',[]);
        p.parse(psyParams.threshold);
        
        %-------------gridParams-------------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('dummy',                      	[],     @ischar);
        p.addParameter('COMMENT',[]);
        p.parse(gridParams);
        
        %-------------stimParams-------------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('goldmann',                    	[],     @(x)ismember(lower(x),{'i','ii','iii','iv','v'}));
        p.addParameter('screenMargins_deg',          	[],     @(x)isempty(x) || length(x)==4);
        p.addParameter('maxPlaceAttemptsBeforeRefix',  	[],     @(x)isPositiveInt(x) || isinf(x));
        p.addParameter('abortLocationAfterNattempts', 	[],     @(x)isNonNegativeInt(x) || isinf(x));    
        p.addParameter('calibMargins_deg',             	[],     @(x)all(isnumeric(x)) && length(x)==4);
        p.addParameter('stim_cycle_on_secs',           	[],     @isPositiveNum);
        p.addParameter('stim_cycle_off_secs',         	[],     @isNonNegativeNum);
        p.addParameter('stim_cycle_n',                	[],     @isPositiveInt);
        p.addParameter('stim_audio',                 	[],     @islogical);
        p.addParameter('additionalGrabberMargins_px', 	[],     @(x)all(isnumeric(x)) && length(x)==4);
        p.addParameter('minDistFromCentre_px',         	[],     @isNonNegativeInt);
        p.addParameter('minDistFromTopRight_px',     	[],     @isNonNegativeInt);
        p.addParameter('minDistFromTopLeft_px',       	[],     @isNonNegativeInt);
        p.addParameter('minDistFromBottomRight_px',   	[],     @isNonNegativeInt);
        p.addParameter('minDistFromBottomLeft_px',     	[],     @isNonNegativeInt);
        p.addParameter('useStimRamping',               	[],     @islogical);
        p.addParameter('useStimWarping',               	[],     @islogical);
        p.addParameter('useLegacyMode',                	[],     @islogical);
        p.addParameter('COMMENT',[]);
        p.parse(stimParams);
        
        %-------------lumParams--------------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('is10Bit',                    	@islogical);
        p.addParameter('useBitstealing',              	@islogical);
        p.addParameter('useCompressedGamma',           	@islogical);
        p.addParameter('bkgdLum_cdm2',                 	@isPositiveNum);
        p.addParameter('deltaLum_min_cdm2',           	@isPositiveNum);
        p.addParameter('deltaLum_max_cdm2',            	@isPositiveNum);
        p.addParameter('maxAbsLum_cdm2',               	@isPositiveNum);
        p.addParameter('screenCalibSubDir',           	@ischar);
        p.addParameter('screenCalibRaw',              	@ischar);
        p.addParameter('screenCalibFittedBgd',          @ischar);
        p.addParameter('COMMENT',[]);
        p.parse(lumParams);
        
        %-------------graphicParams----------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('screenNum',                   	@isNonNegativeInt);
        p.addParameter('Fr',                         	@isPositiveInt);
        p.addParameter('screenWidth_px',              	@isPositiveInt);
        p.addParameter('screenHeight_px',            	@isPositiveInt);
        p.addParameter('screenWidth_cm',              	@isPositiveNum);
        p.addParameter('screenHeight_cm',              	@isPositiveNum);
        p.addParameter('assumedViewingDistance_cm',    	@isPositiveNum);
        p.addParameter('useGUI',                      	@islogical);
        p.addParameter('GUIscreenNum',              	@isNonNegativeInt);
        p.addParameter('COMMENT',[]);
        p.parse(graphicParams);
        
        %-------------paradigm---------------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('MODE',                          @(x)ismember(x,{'eyetracking','mousepress'}));
        p.addParameter('trialInitContactThreshold_secs',@isPositiveNum);
        p.addParameter('delayMin_secs',                	@isNonNegativeNum);
        p.addParameter('delaySigma_secs',             	@isNonNegativeNum);
        p.addParameter('delayMax_secs',               	@isPositiveNum);
        p.addParameter('trialDuration_secs',          	@isPositiveNum);
        p.addParameter('maxNTestTrials',               	@isPositiveInt);
        p.addParameter('attentionGrabberType',        	@(x)ismember(x,{'VfAttentionGrabberFace'}));
        p.addParameter('refixationType',               	@(x)ismember(x,{'controltrial','animalsprite'}));
        p.addParameter('rewarder_type',               	@(x)ismember(x,{'coin','animalsprite'}));
        p.addParameter('rewarder_duration_secs',       	@isPositiveNum);
        p.addParameter('rewarder_playGraphics',       	@islogical);
        p.addParameter('rewarder_playAudio',           	@islogical);
        p.addParameter('rewarder_isColour',           	@islogical);
        p.addParameter('stationarity_nPoints',        	@isPositiveInt);
        p.addParameter('stationarity_criterion_degsec',	@isPositiveNum);
        p.addParameter('idleAtEndUntilResultsFigClosed',@islogical);
        p.addParameter('COMMENT',[]);
        p.parse(paradigm);

        %-------------eyeParams--------------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('ivisVersion',                  	@isPositiveNum);
        p.addParameter('npoints',                      	@isPositiveNum);
        p.addParameter('relaxClassifierAfterNdegs',  	@isPositiveNum);
        p.addParameter('maxPathDeviation_px',         	@isPositiveNum);
        p.addParameter('boxdims_deg',                   @(x)length(x)==2 && all(isPositiveNum(x)));
        p.addParameter('type',                        	@(x)ismember(x,{'tobii','mouse'}));
        %p.addParameter('eye',                        	@(x)ismember(x,[0 1 2]));
        p.addParameter('calibration_range_criterion_px',@isPositiveNum);
        p.addParameter('recalib_falseNegativeMin',    	@(x)(x>=0 && x <= 1));
        p.addParameter('recalib_minNfalseNegtrials', 	@isPositiveNum);
        p.addParameter('recalib_afterNTrials',         	@isPositiveNum);
        p.addParameter('calibrateDistanceAtStart',    	@islogical);
        p.addParameter('minCredibleViewDist_cm',      	@isPositiveNum);
        p.addParameter('maxCredibleViewDist_cm',      	@isPositiveNum);
        p.addParameter('userInputToSetDist',            @islogical);
        p.addParameter('calibrateGazeAtStart',       	@islogical);
        p.addParameter('gazeCalibNPoints',           	@(x)ismember(x,[5 9]));
        p.addParameter('additiveCalibrationOnTrackBox', @islogical);
        p.addParameter('COMMENT',[]);
        p.parse(eyeParams);
        
        %-------------audioParams------------------------------------------
        p = inputParser; p.StructExpand = true;
        p.addParameter('isEnabled',                     @islogical);
        p.addParameter('interface',                 	@(x)ismember(lower(x),{'psychportaudio','matlabbuiltin'}));
        p.addParameter('devID',                       	@(x)isempty(x) || isNonNegativeInt(x));
        p.addParameter('COMMENT',[]);
        p.parse(audioParams);
        
        %------------------------------------------------------------------
        eyeParams.eye = runTimeParams.eye;
        
        if runTimeParams.manuallySuppressEyetrackerCalib && eyeParams.calibrateGazeAtStart
            warning('!!!Disabling gaze calibration!!!');
            eyeParams.calibrateGazeAtStart = false;
        end
        

    %%%%%%%%
    %% 3  %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Preliminary computations and validation %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %-------------Check luminance params-------------------------------
        % step size minimum on at 8-bit system is:
        %   1/(2^8) by default
        %   1/(2^10.7) if using bitstealing
        %   1/(2^9) if using a compressed LUT (50% size)
        %   1/(2^11.7) if using both bitstealing and a compressed LUT
        if lumParams.is10Bit
            b = 10;
        else
            b = 8;
        end
        if lumParams.useBitstealing
            b = b + 2.7; % e.g., 10.7
        end
        if lumParams.useCompressedGamma
            error('implement me!')
            b = b + 1;
        end
        unitStepSize_norm = 1/(2^b);

        % lumParams.maxAbsLum_cdm2 is the greatest target luminance level (n.b., 
        % minLum_cdm2 is the smallest step in luminance after the
        % background baseline
        % level, where not otherwise stated appears to = (TargLevel -
        % BackLevel)
        dynamicRange_db = 10*log10(lumParams.deltaLum_max_cdm2/lumParams.deltaLum_min_cdm2);

        % check luminance values (more below, once we have the calibration data)
       	if abs(dynamicRange_db - 10*log10(lumParams.deltaLum_max_cdm2/lumParams.deltaLum_min_cdm2)) > 0.01
            error('User specified dynamic range (%1.3f) does not match computed range (%1.3f)', dynamicRange_db, 10*log10(lumParams.deltaLum_max_cdm2/lumParams.deltaLum_min_cdm2))
        end

        %-------------Check dB param---------------------------------------
        if psyParams.dynamicRange_db ~= floor(dynamicRange_db)
            error('psyParams.dynamicRange_db (%1.3f) should equal the FLOOR of the computed dynamic range %i (%1.3f)', psyParams.dynamicRange_db, floor(dynamicRange_db), dynamicRange_db);
        end
        if (psyParams.dynamicRange_db+psyParams.fixed.dB_offset) > psyParams.dynamicRange_db
            error('dB_offset (%1.3f) cannot exceed the dynamic range (%1.3f)', (psyParams.dynamicRange_db+psyParams.fixed.dB_offset), psyParams.dynamicRange_db);
        end
        
        %-------------Check screen params----------------------------------
        if any(stimParams.screenMargins_deg.*[1 1 -1 -1] < 1) && IN_FINAL_MODE
            warning('A minimum of 1 degree margin is required on all four edges of the screen\n  For example: [3 1 -3 -1]\nYou entered: [%1.2f %1.2f %1.2f %1.2f]', stimParams.screenMargins_deg(1), stimParams.screenMargins_deg(2), stimParams.screenMargins_deg(3), stimParams.screenMargins_deg(4))
        end
        
      	%-------------Check stimulus timings-------------------------------   
        % check stimParams.stim_cycle_on_secs (1/2)
        % less than 100 leads to summation issues, more than 200 may have
        % problems with saccades:
        % http://www.perimetry.org/articles/Conventional-Perimetry-Part-I.pdf
        if IN_FINAL_MODE && (stimParams.stim_cycle_on_secs < 0.1 || stimParams.stim_cycle_on_secs > 0.25)
            error('User specified myStimulus duration (%1.3f secs) must lie between 100 and 250 milliseconds', stimParams.stim_cycle_on_secs);
        end
        % check stimParams.stim_cycle_on_secs (2/2)
        x = mod(stimParams.stim_cycle_on_secs * graphicParams.Fr, 1);
        if min(x, abs(1-x)) > 0.01
            error('User specified myStimulus duration (%1.3f secs) must be an integer multiple of stimParams.stim_cycle_on_secs*framerate (%i)', stimParams.stim_cycle_on_secs, graphicParams.Fr);
        end
        %
        % ensure that myStimulus 'off' duration is also a multiple of the
        % framerate
        x = mod(stimParams.stim_cycle_off_secs * graphicParams.Fr, 1);
        if min(x, abs(1-x)) > 0.01
            error('User specified myStimulus ''off'' duration (%1.3f secs) must be an integer multiple of stimParams.stim_cycle_off_secs*framerate (%i)', stimParams.stim_cycle_off_secs, graphicParams.Fr);
        end
        
        %-------------Check input/output directories exist-----------------
        if ~exist(SND_DIR, 'dir')
            error('Resources directory not found: %s\nPwd: %s', SND_DIR, pwd());
        end
        if ~exist(IMG_DIR, 'dir')
            error('Resources directory not found: %s\nPwd: %s', IMG_DIR, pwd());
        end
        
        %-------------Misc------- 
    	% simulate observer
        if IN_SIMULATION_MODE
            sim_thresh_mu = [
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                13    13    13    13    13    13    13    13    13    13
                13    13    13    13    13    13    13    13    13    13
                13    13    13    13    13    13    13    13    13    13
                ];
            sim_thresh_sd = [
                1     1     1     1     1     1     1     1     1     1
                1     1     1     1     1     1     1     1     1     1
                1     1     1     1     1     1     1     1     1     1
                1     1     1     1     1     1     1     1     1     1
                1     1     1     1     1     1     1     1     1     1
                1     1     1     1     1     1     1     1     1     1
            ];
            sim_lapseRate = 0;
            sim_guessRate = 0;
            
            % create Java robot for simulating mouse events
            import java.awt.Robot;
            import java.awt.event.*;
            robot = Robot;
        else
            HideCursor();
        end
        
        
        %-------------Check params appropriate for the selected mode-----------------
        if ~IN_GAZE_RESP_MODE
            if stimParams.abortLocationAfterNattempts > 0
                error('No point attempting to position stimuli multiple times if gaze never moves');
            end
            if ~isinf(stimParams.maxPlaceAttemptsBeforeRefix)
                error('No point attempting to position stimuli multiple times if gaze never moves');
            end
        end
        
    
    %%%%%%%%
    %% 4  %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Initialise variables %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                
        if IN_DEBUG_MODE
            showFixationMarker = true;
            eyetracker.fixationMarker = 'whitedot';
        else
            % can be toggled during the experiment with 'f' key
            showFixationMarker = false;
            eyetracker.fixationMarker = 'none';
        end
        

    %%%%%%%%
    %% 5  %%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Load luminance calibration and intinitialise uniform background %%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        % load calibration: raw
        fn = fullfile('..', 'calib', lumParams.screenCalibSubDir, lumParams.screenCalibRaw);
        calib = load(fn); % e.g., load('calib_26-Feb-2019\step2_fullMatrix_InputOutputFunc_v1_20190218T142409.mat')
        
        % get calibration: uniformity-corrected background (derived from
        % above, but computed in advance for speed/convenience)
        back_fn = fullfile('..', 'calib', lumParams.screenCalibSubDir, lumParams.screenCalibFittedBgd);
        calibBgrd = load(back_fn); % e.g., load('calib_26-Feb-2019\step3_10cdm2_backgroundMatrix_CL_v1_20190226T163100.mat')
        
        % validate: check the two files match each other
        if calib.background_cdm2 ~= calibBgrd.background_cdm2 || calib.isBitStealing ~= calibBgrd.isBitStealing || calib.is10BitGfx ~= calibBgrd.is10BitGfx || calib.screenNum ~= calibBgrd.screenNum || ~strcmpi(calib.computerName, calibBgrd.computerName)
            error('parameter mismatch detected in two calibration files?');
        end
            
        % validate: check that background luminance calibration matches
        % that expected 
        if lumParams.bkgdLum_cdm2 ~= calibBgrd.background_cdm2
            error('Specified background luminance (%1.2f cdm2) does not match that provided by the background calibration file (%1.2f cdm2): %s', lumParams.background_cdm2, calibBgrd.background_cdm2, back_fn);
        end
        backgroundMatrix = calibBgrd.backgroundMatrix_CL;
        
        % validate: check luminance modes match expected
        if lumParams.is10Bit ~= calib.is10BitGfx
            error('Specified is10Bit=%i does not match that stated in calibration file (calib.is10BitGfx = %i)', lumParams.is10Bit, calib.is10BitGfx);
        end
        if lumParams.useBitstealing ~= calib.isBitStealing
            error('Specified useBitstealing=%i does not match that stated in calibration file (calib.isBitStealing = %i)', lumParams.useBitstealing, calib.isBitStealing);
        end

        % validate: check the backgroundMatrix matches screen pixel
        % dimensions
        if calibBgrd.w_px ~= graphicParams.screenWidth_px
            error('luminance calibration pixel width (%i) does not match that of the specified screen (%i)', calibBgrd.w_px, graphicParams.screenWidth_px)
        end
        if calibBgrd.h_px ~= graphicParams.screenHeight_px
            error('luminance calibration pixel height (%i) does not match that of the specified screen (%i)', calibBgrd.h_px, graphicParams.screenHeight_px)
        end

        % validate: check the two files match the current hardware /
        % settings
        % get computer name
        [~,detectedComputerName] = system('hostname');
        detectedComputerName = deblank(detectedComputerName);
        if ~strcmpi(calib.computerName, detectedComputerName)
            error('The computer name specified in the luminance calibration file (%s) does not match the detected name of the present system (%s). Are you sure you selected the correct calibration?', calib.computerName, detectedComputerName);
        end
        
        % validate: check that backgroundMatrix matches the
        % dimensions/resolution of the specified screen
        if calibBgrd.w_px ~= graphicParams.screenWidth_px
            error('luminance calibration pixel width (%i) does not match that of the specified screen (%i)', calibBgrd.w_px, graphicParams.screenWidth_px)
        end
        if calibBgrd.h_px ~= graphicParams.screenHeight_px
            error('luminance calibration pixel height (%i) does not match that of the specified screen (%i)', calibBgrd.h_px, graphicParams.screenHeight_px)
        end

        %% validate user inputs %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % verify that user values are valid given calibration
        if IN_DEBUG_MODE
            fprintf('Loading screen (luminance) calibration..\n');
        end

        % average points if multiple observations
        if size(calib.out_cdm2, 4) > 1
            if IN_DEBUG_MODE
                fprintf('Multiple (repeated) calibration measurements detected. Averaging points..\n');
            end
            calib.out_cdm2 = mean(calib.out_cdm2,4);
        end
        
        % validate possible luminance range
        screen_min_cdm2 = max(calib.out_cdm2(:,:,1),[],'all');
        screen_max_cdm2 = min(calib.out_cdm2(:,:,end),[],'all');
        
        if lumParams.maxAbsLum_cdm2 ~= (lumParams.bkgdLum_cdm2+lumParams.deltaLum_max_cdm2)
            error('maxAbsLum_cdm2 (%1.2f cdm2) should match the background (%1.2f  cdm2) + max DLS (%1.2f  cdm2)', lumParams.maxAbsLum_cdm2, lumParams.bkgdLum_cdm2, lumParams.deltaLum_max_cdm2);
        end
        if lumParams.bkgdLum_cdm2 < screen_min_cdm2 
            error('Specified background luminance value (%1.2f cdm2) is below the displayable range (%1.3fcdm2 -- %1.3fcdm2)', lumParams.bkgdLum_cdm2, screen_min_cdm2, screen_max_cdm2)
        end
        if lumParams.maxAbsLum_cdm2 > screen_max_cdm2
            error('Specified max luminance value (%1.2f cdm2) is above displayable range (%1.3fcdm2 -- %1.3fcdm2)', lumParams.maxAbsLum_cdm2, screen_min_cdm2, screen_max_cdm2)
        end

        % find the smallest luminance difference after the background,
        % given the mean calibration
        mu_in_CL = calib.in_CL(:);
        tmp_mu = mean(mean(calib.out_cdm2,1),2);
        mu_valsRaw = tmp_mu(:);
        fittedmodel = fit(mu_valsRaw, mu_in_CL, 'splineinterp'); % 'splineinterp'); % NB: smoothing spline doesn't work with fzero below https://www.mathworks.co.uk/matlabcentral/newsreader/view_thread/287031
        bkgdLum_norm = fittedmodel(lumParams.bkgdLum_cdm2);
        desired_norm = bkgdLum_norm + unitStepSize_norm;
        objective = @(cdm2) fittedmodel(cdm2) - desired_norm;
        est_targLum_min_cdm2 = fzero(objective, 0); % may actually be 1 step above background, but only looking for stepsize difference anyway
        est_lumParams.deltaLum_min_cdm2 = est_targLum_min_cdm2 - lumParams.bkgdLum_cdm2;

        if abs(est_lumParams.deltaLum_min_cdm2 - lumParams.deltaLum_min_cdm2) > 0.005
            figure()
            plot(mu_valsRaw, mu_in_CL, 'o', mu_valsRaw,fittedmodel(mu_valsRaw),'k-');
            error('Specified delta min (%1.6f) is inconsistent with computed minimum value, given mean screen calibration (%1.6f)', lumParams.deltaLum_min_cdm2, est_lumParams.deltaLum_min_cdm2)
        elseif abs(est_lumParams.deltaLum_min_cdm2 - lumParams.deltaLum_min_cdm2) > 0.005
            warning('Specified delta min (%1.3f) does not match computed minimum value, given screen calibration (%1.3f)', lumParams.deltaLum_min_cdm2, est_lumParams.deltaLum_min_cdm2)
        end

        % check that backgroundMatrix matches raw calibration
        % pick a random value and work out anticipated output
        fittedmodel_backwards = fit(mu_in_CL, mu_valsRaw, 'smoothingspline'); % 'splineinterp');
        pixel_CL = randsample(backgroundMatrix(:),1);
        predictedOutput_cdm2 = fittedmodel_backwards(pixel_CL);
        if abs(predictedOutput_cdm2 - lumParams.bkgdLum_cdm2)/lumParams.bkgdLum_cdm2 > 0.05
            warning('Predicted target background (%1.2f cdm2) differs from target level (%1.2f cdm2) by more than 10 percent!', predictedOutput_cdm2, lumParams.bkgdLum_cdm2)
        end
            
    try % wrap in try..catch to ensure a graceful exit

        
        %%%%%%%%
        %% 6  %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Open webcam interface %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            if RECORD_WEBCAM
                % reset the image acquisition controller (defensive, in case not shut down properly previously)
                warning off % no idea why these commands throw warnings regarding the java.awt.Component EDT, but they are unsightly and pointless
                imaqreset
                imaqmex('feature','-limitPhysicalMemoryUsage',false);
                
                % list devices
                if IN_DEBUG_MODE
                    d = imaqhwinfo('winvideo');
                    dispStruct(d.DeviceInfo)
                end

                % Construct a video input object
                % vobj = videoinput('winvideo',2,'YUY2_1280x720'); % Surfrace Pro; default resolution; 2 is forward facing
                vobj = videoinput('winvideo',1,'YUY2_640x480'); % HP   MJPG_1280x720; CRITICAL RUNSPEED PARAMATER 1
                
                % re-enable warnings
                warning on
                
                % Get Info about Source and Hardware
                source = getselectedsource(vobj);
                Fr = round(str2double(source.FrameRate));
                
                % Set Properties for Videoinput Object
                vobj.TimeOut = Inf; % keep collecting frames until manually specify write
                vobj.FrameGrabInterval = 6; % CRITICAL RUNSPEED PARAMATER 2
                vobj.LoggingMode = 'disk'; % 'disk&memory';
                vobj.FramesPerTrigger = 1;
                vobj.TriggerRepeat = Inf;
                
                % Construct VideoWriter object and set Disk Logger Property
                webcamFn = sprintf('%s-%i-%i-%i-%s.avi', metaParams.expID, metaParams.partID, metaParams.sessID, getBlockNum(), datestr(now(),30));
                fullFn = fullfile(WEBCAM_OUT_DIR, webcamFn);
                v = VideoWriter(fullFn); % , 'MPEG-4'); % , 'Motion JPEG 2000');
                v.Quality = 50; % 0-100; CRITICAL RUNSPEED PARAMATER 3
                v.FrameRate = Fr/vobj.FrameGrabInterval;
                vobj.DiskLogger = v;
                
                % start streaming from the camera
                start(vobj);
            else
                webcamFn = NaN;
            end
        
        
        %%%%%%%%
        %% 6  %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Open eyetracker interface %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            if ~IN_FINAL_MODE
                setpref('ivis','disableScreenChecks',true);
            end
        
            if IN_MOUSE_RESP_MODE
                eyeParams.type = 'IvFixedPoint';
                % disable all calibration
                eyeParams.recalib_falseNegativeMin = inf;
                eyeParams.recalib_minNfalseNegtrials = inf;
                eyeParams.recalib_afterNTrials = inf;
                eyeParams.calibrateDistanceAtStart  = false;
                eyeParams.calibrateGazeAtStart = false;
                % make it so classifier will never trigger unless manually
                % forced
                eyeParams.npoints = inf;
            end
            
            % verify, initialise, and launch the ivis toolbox
            IvMain.assertVersion(eyeParams.ivisVersion);
            config = IvParams.getDefaultConfig('graphics.testScreenNum',graphicParams.screenNum, 'graphics.useScreen',false, 'eyetracker.sampleRate',[], 'audio.isEnabled',audioParams.isEnabled,'audio.devID',audioParams.devID, 'keyboard.handlerClass','MyInputHandler', 'eyetracker.type',eyeParams.type, 'eyetracker.fixationMarker',eyetracker.fixationMarker, 'GUI.useGUI',graphicParams.useGUI, 'GUI.screenNum',graphicParams.GUIscreenNum, 'classifier.nsecs',paradigm.trialDuration_secs, 'log.raw.dir',LOG_RAW_DIR, 'log.data.dir',LOG_DAT_DIR, 'log.diary.fullFn',LOG_DIARY_FULLFN); % , 'audio.isConnected',false));
            if IN_SIMULATION_MODE && ~IN_MOUSE_RESP_MODE
                config.eyetracker.type = 'mouse';
            end
            IvMain.initialise(config);
            [eyetracker, logs, InH, winhandle, params] = IvMain.launch(graphicParams.screenNum);

            % Crucial that the geometry of the task is correctly specified,
            % for when converting between pixels/cm/degrees. Just to be
            % safe, we will therefore set the parameters manually here
            % (n.b., though viewDist may get updated based on new
            % eyetracking data).
            screenHeight_cm = graphicParams.screenHeight_cm;
            screenWidth_cm = graphicParams.screenWidth_cm;
            screenWidth_px = graphicParams.screenWidth_px;
            viewingDist_cm = graphicParams.assumedViewingDistance_cm;
            IvUnitHandler(screenWidth_cm, screenWidth_px, viewingDist_cm);
            
            % init keyboard
            USER_INPUT_CODE = InH.INPT_SPACE.code; % InH.INPT_CLICK.code; % InH.INPT_SPACE.code
            
            % misc
            if IN_MOUSE_RESP_MODE
                eyetracker.setLastKnownViewingDistance(graphicParams.assumedViewingDistance_cm * 10);
            end
            
            
        %%%%%%%%
        %% 7  %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Open PTB screen %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % PTB-3 correctly installed and functional? Abort otherwise.
            AssertOpenGL;

            % !!!!required to work on slow computers!!! Use with caution!!!!!
            Screen('Preference', 'SkipSyncTests', 2);
            
            % Setup Psychtoolbox for OpenGL 3D rendering support and initialize the
            % mogl OpenGL for Matlab wrapper:
            InitializeMatlabOpenGL(1); % necessary for, e.g., trackbox
                        
            % open the screen
            PsychImaging('PrepareConfiguration');
            % This will try to get 32 bpc float precision if the hardware supports
            % simultaneous use of 32 bpc float and alpha-blending. Otherwise it
            % will use a 16 bpc floating point framebuffer for drawing and
            % alpha-blending, but a 32 bpc buffer for gamma correction and final
            % display. The effective stimulus precision is reduced from 23 bits to
            % about 11 bits when a 16 bpc float buffer must be used instead of a 32
            % bpc float buffer:
            PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible'); % 'FloatingPoint32Bit');
            if lumParams.is10Bit
                % Enable GPU's 10 bit framebuffer under certain conditions
                % (see help for this file):
                PsychImaging('AddTask', 'General', 'EnableNative10BitFramebuffer');
            end
            if lumParams.useBitstealing
                PsychImaging('AddTask', 'General', 'EnablePseudoGrayOutput');
            end
            % PsychImaging('AddTask', 'FinalFormatting', 'DisplayColorCorrection', 'GainMatrix');
            [winhandle, winrect_px] = PsychImaging('OpenWindow', graphicParams.screenNum, 0); % fullscreen
%             [winhandle, winrect_px] = PsychImaging('OpenWindow', graphicParams.screenNum, 0, [0 0 500 500]); % small window for debugging
            
            % set alpha blending mode
            Screen('BlendFunction', winhandle, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

            % compute values
            masterGammaTable = Screen('ReadNormalizedGammaTable', winhandle);
            Fr_obs = 1./Screen('GetFlipInterval', winhandle);
            [screenWidth_px, screenHeight_px] = RectSize(Screen('Rect', winhandle));
            
            % verify that user values are valid given PTB screen
            if ~(graphicParams.Fr == round(Fr_obs))
                error('Specified framerate (%1.6f) does not match observed value (%1.6f)', graphicParams.Fr, Fr_obs)
            end
            if ~(screenWidth_px == graphicParams.screenWidth_px)
                if IN_FINAL_MODE
                    error('Specified screen width (%1.6f) does not match observed value (%1.6f)', graphicParams.screenWidth_px, screenWidth_px) %#ok<*UNRCH>
                else
                    warning('Specified screen width (%1.6f) does not match observed value (%1.6f)', graphicParams.screenWidth_px, screenWidth_px)
                end
            end
            if ~(screenHeight_px == graphicParams.screenHeight_px)
                if IN_FINAL_MODE
                    error('Specified screen height (%1.6f) does not match observed value (%1.6f)', graphicParams.screenHeight_px, screenHeight_px)
                else
                    warning('Specified screen height (%1.6f) does not match observed value (%1.6f)', graphicParams.screenHeight_px, screenHeight_px)
                end
            end
            
            % Currently we need to explicitly register the screen with
            % ivis, once it has opened. At one point it was possible to
            % open the screen first and then pass it into ivis upon
            % initilisation. However, ivis GUIs do not work if a PTB window
            % is open, so here we: (1) Open Ivis; (2) Open PTB window; (3)
            % manually register the window.
            IvParams.registerScreen(winhandle)

            % Create a convolution shader for a gaussian blur of width 5 and
            % stddev. 1.5. Needs image processing toolbox for fspecial() function, or
            % alternatively compute your own 5 x 5 kernel matrix with a gaussian
            % convolution kernel inside:            
            kernel = fspecial('gaussian', 7, 7); % kernel = fspecial('gaussian', 5, 1.5);
            shader = EXPCreateStatic2DConvolutionShader(kernel, 4, 4, 0, 2);
            % for details, see DrawManuallyAntiAliasedTextDemo.m

            % Create image warper for correcting for flat screen (see
            % VfStimulusWarper.exampleOfUse() for more info)
            %   <moved to later, in order to use empirical distance values>

            
        %%%%%%%%
        %% 8  %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Initialise myStimulus grid %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

         	% initialise grid
            if eyeParams.eye == 0
                if IN_DEBUG_MODE
                    fprintf('loading LEFT eye grid..\n');
                end
            elseif eyeParams.eye == 1
                if IN_DEBUG_MODE
                    fprintf('loading RIGHT eye grid..\n');
                end
            elseif eyeParams.eye == 2
                if IN_DEBUG_MODE
                    fprintf('Running Binocularly. Will load RIGHT eye grid..\n'); % tmp hack!
                end
            else
                error('Unknown eye: %1.2f', eyeParams.eye)
            end    
            
            % initialise psychometric controller
            switch lower(psyParams.mode)
                case 'fixed'
                    PsychoController = MyPsychoControllerWrapper(eyeParams.eye, psyParams.fixed.dB_offset, psyParams.fixed.nFalsePositive, lumParams.deltaLum_max_cdm2);
                    PsychoController = MyPsychoControllerWrapperButton(eyeParams.eye, psyParams.fixed.dB_offset, psyParams.fixed.nFalsePositive, lumParams.deltaLum_max_cdm2);
                case 'threshold'
                    maxLum_cdm2     = lumParams.deltaLum_max_cdm2               % tmp hack
                    domain          = 0:1:psyParams.dynamicRange_db  	% tmp hack
                    doPlot          = false;
                    nFalsePositives = 10
                    nFalseNegatives = 0
                    PsychoController = myZestWrapper(eyeParams.eye, maxLum_cdm2, domain, doPlot, nFalsePositives, nFalseNegatives)
                otherwise
                    error('Unknown input: %s', psyParams.mode);
            end
            
            % initialise unit handler
            VfUnitHandler(screen_min_cdm2, screen_max_cdm2, lumParams.bkgdLum_cdm2, lumParams.deltaLum_min_cdm2, lumParams.deltaLum_max_cdm2)
            
            % compute any further params
            stimDiam_deg = VfStimulusClassic.getGoldmannDiameter(stimParams.goldmann); % stimDiam_deg = 0.5
            if isempty(stimParams.screenMargins_deg)
                stimParams.screenMargins_deg = repmat(stimDiam_deg*2, 1, 4) .* [1 1 -1 -1];
            end

            % validate screen dimensions
            [screenWidth_px, screenHeight_px] = RectSize(Screen('Rect', graphicParams.screenNum));
            if screenWidth_px~=graphicParams.screenWidth_px
                error('Detected screen width (%i) not as specified (%i)\n', screenWidth_px, graphicParams.screenWidth_px);
            end
            if screenHeight_px~=graphicParams.screenHeight_px
                error('Detected screen width (%i) not as specified (%i)\n', screenHeight_px, graphicParams.screenHeight_px);
            end 
            % can't check physical size reliably, since the queried info is
            % highly suspect in absolute terms, but the relative dimensions
            % are usually about right
            [width_mm, height_mm]=Screen('DisplaySize', graphicParams.screenNum);
            if abs(screenWidth_cm/screenHeight_cm - width_mm/height_mm) > 0.01
                error('Specified aspect ratio (%1.2f x %1.2f = %1.2f) do not match those returned by the monitor itself (%1.2f x %1.2f = %1.2f)', screenWidth_cm, screenHeight_cm, screenWidth_cm/screenHeight_cm, width_mm, height_mm, width_mm/height_mm)
            end
            
            screenDims_deg = [screenWidth_px, screenHeight_px] / (screenWidth_px / (2*rad2deg(atan(graphicParams.screenWidth_cm/(2*graphicParams.assumedViewingDistance_cm))))); % IvUnitHandler.getInstance().deg2px([screenWidth_px, screenHeight_px], graphicParams.assumedViewingDistance_cm) - stimParams.screenMargins_deg*2
            validPlacementDims_deg = screenDims_deg - [sum(abs(stimParams.screenMargins_deg([1 3]))) sum(abs(stimParams.screenMargins_deg([2 4])))];

            fprintf('Screen dimensions = %1.4f x %1.4f DVA\n',screenDims_deg);
            fprintf('Usable screen dimensions = %1.4f x %1.4f DVA\n',validPlacementDims_deg);

            xy_deg = reshape(PsychoController.zObj.locations_deg, [],2); % reshape into 2 columns (x/y)
            if any(any(bsxfun(@gt, abs(xy_deg), validPlacementDims_deg)))
                disp(abs(xy_deg))
                error('targets are too far appart to EVER fit on the viewable screen area (Screen dims approx: %1.2f x %1.2f; valid lims: %1.2f x %1.2f)', screenDims_deg, validPlacementDims_deg);
            end
            if any(any(bsxfun(@gt, abs(xy_deg), validPlacementDims_deg/2)))
                warning('some targets are too far appart to be placed when observer is fixating centrally (eccentic viewing required)');
            end

            
      	%%%%%%%&
        %% 9 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Load Resources %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
             
            %-------------Load Sounds--------------------------------------
            %fprintf('\nLoading sounds...\n');
            % audio = IvAudio.getInstance();
            %nurseryRhymes = audio.loadAll(fullfile(params.toolboxHomedir,'resources','audio','nurseryrhymes'), '*.wav', 0.1);
            %n = length(nurseryRhymes);

            
            %-------------Synth Sounds-------------------------------------
            %fprintf('\nSynthesising sounds...\n');
            
            
            %-------------Load Images--------------------------------------
            fprintf('\nLoading images...\n');

            switch lower(paradigm.attentionGrabberType)
                case lower('VfAttentionGrabberFace')
                    attentionGrabber = VfAttentionGrabberFace(winhandle, IMG_DIR, SND_DIR);
                otherwise
                    error('Unknown VfAttentionGrabber: %s', paradigm.attentionGrabberType);
            end

            switch lower(paradigm.rewarder_type)
                case 'animalsprite'
                    rewarder = VfAttentionGrabberAnimals(winhandle, paradigm.rewarder_duration_secs, params.graphics.Fr, IMG_DIR, SND_DIR);
                case 'coin'
                    rewarder = VfAttentionGrabberCoin(winhandle, paradigm.rewarder_duration_secs, params.graphics.Fr, IMG_DIR, SND_DIR, paradigm.rewarder_isColour);
                otherwise
                    error('Unrecognised rewarder type: %s', paradigm.rewarder_type);
            end

    
            %-------------Synth Images-------------------------------------
            fprintf('\nSynthesising images...\n');
            
            % fixation cross
            FixCrossImage=zeros(32,32,4)*255; % make a black/blank canvas. (useful to be a power of two)
            % make red
            FixCrossImage(:,:,1) = 192;
            % add the transparency layer in shape of a cross
            FixCrossImage(15:18,    :,      4)=255;
            FixCrossImage(:,        15:18,  4)=255;
            % make texture
            FixCrossTexture = Screen('MakeTexture', winhandle, FixCrossImage); % convert image matrix to texture
            FixCrossRect = [0 0 size(FixCrossImage,2) size(FixCrossImage,1)];
           	% start on sceen center
            FixCrossDrawRect = CenterRectOnPoint(FixCrossRect, params.graphics.mx, params.graphics.my);
            
            % make background luminance texture
            %   backgroundMatrix -> PTB texture
            backTex = Screen('MakeTexture', winhandle, backgroundMatrix, [], [], 1); % high precision (16 bit)

            % make a hacky flat version of the grey background for when
            % only using 8-bits
            backgroundMatrix_mu = backgroundMatrix;
            backgroundMatrix_mu(:,:) = mean(mean(backgroundMatrix_mu));
            backTex_mu = Screen('MakeTexture', winhandle,  backgroundMatrix_mu, [], [], 1); % high precision (16 bit)

            % set the background screen for when feedback is being given
            % (hacky?)
            if paradigm.rewarder_isColour && ~lumParams.is10Bit 
                backTex_fback = backTex_mu;
            else
                backTex_fback = backTex;
            end

          	% create grid point stimulus-object         
         	myTestpointStimulus = VfStimulusClassic(stimParams.goldmann, stimParams.stim_cycle_on_secs, stimParams.stim_cycle_off_secs, stimParams.stim_cycle_n, false);

            % create refixation stimulus-object
            switch lower(paradigm.refixationType)
                case 'controltrial'
                    myRefixationStimulus = VfStimulusClassic(stimParams.goldmann, stimParams.stim_cycle_on_secs, stimParams.stim_cycle_off_secs, stimParams.stim_cycle_n, true);
                case 'animalsprite'
                    myRefixationStimulus = VfAttentionGrabberAnimals();
                otherwise
                    error('Unrecognised refixation type: %s', paradigm.refixationType);
            end              
            
    
        %%%%%%%%
        %% 10 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Precache key function to prevent slow-down on trial 1    %%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%           
            
            fprintf('Executing/Precaching key functions..\n');

            % disable warnings
            warning('off','all')

            % initialise the classifier to be used throughout testing
            myGraphic = IvGraphic('target', [], 0, 0, 1, 1, [], winhandle); % will make 1x1 pixel, and control classifier margins using IvClassifierBox margins
            myClassifier = IvClassifierBox(myGraphic, eyeParams.boxdims_deg, eyeParams.npoints, [], [], eyeParams.maxPathDeviation_px); % use default margin size of 2 degrees for now
            % 1D classifier, for bootstrapping the calibration
            graphicObjs             = {IvPrior(), attentionGrabber.ivGraphicStub}; % modify VfAttentionGrabberFace.GRAPHIC_DIM_MOD (i.e., attentionGrabber.ivGraphicStub) to change width
            likelihoodThresh        = [inf 30]; %300 % can play with threshold to control robustness
            bufferlength          	= 250; % can also play with onset ramp to control smoothing
            GUIidx                  = 5;
            timeout_secs            = 10;
            xyWeight                = [1 0];
            printDebugInfoToConsole = false;
            calibClassifier = IvClassifierLL(graphicObjs, likelihoodThresh, bufferlength, GUIidx, timeout_secs, xyWeight, printDebugInfoToConsole);
            % start classifiers
            myClassifier.start(false);
            calibClassifier.start(false);
            % poll keyboard
            InH.getInput();
            % Perform animation
            attentionGrabber.init(1, 1)
            attentionGrabber.setScale(1); % log scaling from 1 to 0.25
            attentionGrabber.setSway(1);
            % create stimulus
            myStimulus = myTestpointStimulus;
            myStimulus.setLuminance(1);
            myStimulus.setLocation(params.graphics.mx, params.graphics.my);
            stimDiameter_px = 2*round(IvUnitHandler.getInstance().deg2px(1, 68)/2);  % round to nearest even number
            n = stimDiameter_px + 2*myStimulus.PADDING_PX;
            yidx = params.graphics.my+((-n/2+1):(n/2)); % +1 hack
            xidx = params.graphics.mx+((-n/2+1):(n/2));
            back = nan(length(yidx), length(xidx));
            iy = yidx>0 & yidx<=screenHeight_px;
            ix = xidx>0 & xidx<=screenWidth_px;
            back(iy,ix) = backgroundMatrix(yidx(iy), xidx(ix));
            warper = visfield.graphic.VfStimulusWarper(screenWidth_cm, screenHeight_cm, screenWidth_px, screenHeight_px, 68, 68);
            myStimulus.initGraphic(winhandle, stimDiameter_px, warper, shader, back, stimParams.useStimRamping, stimParams.useStimWarping, stimParams.useLegacyMode)
            % start graphics
            myGraphic.reset(1, 1);
            myClassifier.start();
            myStimulus.start();
            attentionGrabber.start();
            % update classifiers
            myClassifier.update();
            calibClassifier.update();
            % Draw graphics
            Screen('DrawTexture', winhandle, backTex);
            attentionGrabber.draw(winhandle);
            myStimulus.draw(winhandle);
            Screen('DrawTexture', winhandle, backTex_mu); % end with background to minimize apparent change
            % Update eyetracker
            eyetracker.refresh(false); % false to supress logging
            % flip screen
            Screen('Flip', winhandle); % clear screen

            % re-enable warnings
%             if IN_DEBUG_MODE
                warning('on','all')
%             end
    
            
        %%%%%%%%
        %% 11 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Set viewing distance %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%            

            lastKnownViewingDistance_cm = NaN;
        	crosstargXY_px = [params.graphics.mx*1.25, params.graphics.my*1.25];
        
            if ~eyeParams.calibrateDistanceAtStart 
                if IN_FINAL_MODE && ~IN_MOUSE_RESP_MODE
                    error('In final mode distance MUST be calibrated (unless in mouse mode)');
                end
                
                lastKnownViewingDistance_cm = graphicParams.assumedViewingDistance_cm;
            else
                %  enter viewing distance, set lastKnownViewingDistance_cm

                % Start displaying trackbox, if so specified
                if eyeParams.userInputToSetDist
                    TrackBox.getInstance().start();
                end

                fprintf('\nRunning distance calibration...\n   > Press SPACE when the user is sat %1.2f cm away from the centre of the screen\n', graphicParams.assumedViewingDistance_cm);
                calibIsSet = false;
                % Play until:
                %   (1) the z-distance of the eyetracker has been
                %       successfully calibrated
                %   (2) The user has pressed space again (if in DEBUG mode)
                while 1
                    
                    % update eyetracker
                    eyetracker.refresh(true); % logging
                    
                    % evaluate whether eyetracker is tracking
                    isTracking = false;
                    if logs.data.getN()>0
                        [estXY, t] = logs.data.getLastKnownXY(1, true, false); % [useRaw, allowNan]
                        timeNow = GetSecs();
                        if (timeNow-t) <= 0.4 % must have recent non-NaN data
                            isTracking = true;
                        end
                    end
                    
                    % check for input
                    if InH.getInput() == USER_INPUT_CODE || ~eyeParams.userInputToSetDist
                        if calibIsSet % if have already set calibration, and are just loitering in debug mode
                            break
                        else
                            if ~isTracking % defensive check (also performed internally by IvDataInput
                                fprintf('Cannot perform distance calibration; not currently tracking!\n'); 
                            else
                                % distance calibrate
                                calibIsSet = eyetracker.calibrateDistanceToScreen(10*graphicParams.assumedViewingDistance_cm);
                                if calibIsSet
                                    fprintf('Additive distance calibration successfully set\n\n');
                                    lastKnownViewingDistance_cm = eyetracker.getLastKnownViewingDistance()/10;
                                    
                                    % gaze calibrate
                                    if eyeParams.additiveCalibrationOnTrackBox
                                        trueXY_px           = crosstargXY_px;
                                        estXY_px            = estXY;
                                        maxCorrection_deg   = 20;
                                        weight              = 1;
                                        eyetracker.updateDriftCorrection(trueXY_px, estXY_px, maxCorrection_deg, weight)
                                        fprintf('Additive drift correction set successfully set\n\n');
                                    end
                                    
                                    if ~IN_DEBUG_MODE % if in debug mode will continue running until space pressed again, so as to confirm that the eyetracker is now returning the calibrated value
                                        break;
                                    end
                                else
                                    fprintf('Calibration failed.\nPress SPACE when the user is sat %1.2f cm away from the centre of the screen\n', graphicParams.assumedViewingDistance_cm);
                                end
                            end
                        end
                    end
                    
                    % report current state by writing text directly onto
                    % the screen
                    if ~isTracking
                        DrawFormattedText(winhandle, 'Not Tracking', params.graphics.mx, 50, [1 0 0]);
                    else
                        DrawFormattedText(winhandle, sprintf('%1.1f cm',eyetracker.getLastKnownViewingDistance()/10), params.graphics.mx, 50, [0 1 0]);
                    end
                    
                    % draw fixation cross
                    if eyeParams.additiveCalibrationOnTrackBox
                        FixCrossDrawRect = CenterRectOnPoint(FixCrossRect, crosstargXY_px(1), crosstargXY_px(2));
                        Screen('DrawTexture', winhandle, FixCrossTexture, FixCrossRect, FixCrossDrawRect);
                    end
                    
                    % write the expected eye in the middle of the screen
                    Screen('TextSize',winhandle, 32);
                    eyes = {'L', 'R', 'B'};
                    txt = sprintf('%s / %i cm', eyes{eyeParams.eye+1}, graphicParams.assumedViewingDistance_cm);
                    %DrawFormattedText(winhandle, txt, params.graphics.mx, params.graphics.my, [255 255 255]); % appears cropped
                    Screen('DrawText', winhandle, txt, params.graphics.mx, params.graphics.my, [255 255 255]);
                    
                    % update screen
                    Screen('Flip', winhandle);
                    WaitSecs(.01);
                end
   
                % Stop displaying video and trackbox
                if eyeParams.userInputToSetDist
                    fprintf('STOPPING TRACKBOX\n');
                    
                    TrackBox.getInstance().stop();

                    % pause for a short moment on blank screen to readjust
                    Screen('DrawTexture', winhandle, backTex);
                    Screen('Flip', winhandle);
                    WaitSecs(.15);
                end
            end
                
            % defensive check
            if isnan(lastKnownViewingDistance_cm)
                error('lastKnownViewingDistance_cm must be set by this point');
            end
            
            % Create image warper for correcting for flat screen (see
            % VfStimulusWarper.exampleOfUse() for more info)
            %   <moved to later, in order to use empirical distance values>         
            zdistBottom_cm = lastKnownViewingDistance_cm + 4; % 64.5     % in cm
            zdistTop_cm    = lastKnownViewingDistance_cm + 4; % 64.5     % in cm
            % create warper object
            warper = visfield.graphic.VfStimulusWarper(screenWidth_cm, screenHeight_cm, screenWidth_px, screenHeight_px, zdistBottom_cm, zdistTop_cm);
          
    
        %%%%%%%%
        %% 12 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Pre-Run: Splash Screen %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
            eyes = {'Left', 'Right', 'Both'};
            Screen('TextFont',winhandle, 'Helvetica');
            Screen('TextSize',winhandle, 48);
            
            % make sure mouse NOT pressed
            [~,~,buttons] = GetMouse();
            if any(buttons)
                
                Screen('DrawTexture', winhandle, backTex);
                
                txt = 'Please release button';
                Screen('DrawText', winhandle, txt, params.graphics.mx/2-100, params.graphics.my, [1 1 1]);
                Screen('Flip', winhandle);
                
                while 1
                    [~,~,buttons] = GetMouse();
                    if ~any(buttons)
                        break
                    end
                    WaitSecs(0.01);
                end
                
                FlushEvents();
            end
            
            
            % wait for mouse release
            mouseWasPressed = false;
            while 1
                % check for mouse press
                [~,~,buttons] = GetMouse();
                if any(buttons)
                    mouseWasPressed = true;
                else
                    if mouseWasPressed % mouse was pressed, but now isn't
                        break;
                    end
                end
                
                % check keyboard in case quit key
                InH.getInput();
                
                % draw text
            	Screen('DrawTexture', winhandle, backTex);
                %
                idx = runTimeParams.eye+1;
                txt = sprintf('Testing %s eye', eyes{idx});
                Screen('DrawText', winhandle, txt, params.graphics.mx/2-100, params.graphics.my-200, [1 1 1]);
                %
                if runTimeParams.eye<2
                    idx = (1-runTimeParams.eye)+1;
                    txt = sprintf('Place patch over your %s eye', eyes{idx});
                    Screen('DrawText', winhandle, txt, params.graphics.mx/2-100, params.graphics.my, [1 1 1]);
                end
                %
                txt = 'When ready, press button to begin';
                Screen('DrawText', winhandle, txt, params.graphics.mx/2-100, params.graphics.my+200, [1 1 1]);
                
                % Flip screen
                Screen('Flip', winhandle);
                
                % Brief pause
                WaitSecs(0.01);
            end
            
            % reset
            FlushEvents();
            Screen('DrawTexture', winhandle, backTex);
            Screen('Flip', winhandle);
                
            
        %%%%%%%%
        %% 13 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Run: Trials %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            fprintf('Starting Trials\n');
            
            % initialise counters
            nTestTrial = 0;
            trialNum = 0;
            nCorrect = 0;
            
            % init point to return to (after a refixation trial)
            stimulusToReturnTo = []; % x_rel_deg, y_rel_deg, targLum_dB

            % initialise calibration parameters
            % recalib params
            triggerRecalib = eyeParams.calibrateGazeAtStart;
            %falseNegative_rate = NaN;
            falseNegative_nPossible = 0;
            falseNegative_n = 0;
            % init adult calib values
            screenMargins_px = round(IvUnitHandler.getInstance().deg2px(stimParams.screenMargins_deg, lastKnownViewingDistance_cm));
            calibMargins_px = round(IvUnitHandler.getInstance().deg2px(stimParams.calibMargins_deg, lastKnownViewingDistance_cm));
            calibRect_px = winrect_px + (screenMargins_px+calibMargins_px);
            % set locations
            switch eyeParams.gazeCalibNPoints
                case 5 % N = 5
                    xcalib_px = [params.graphics.mx calibRect_px(3) calibRect_px(1) calibRect_px(3) calibRect_px(1)];
                    ycalib_px = [params.graphics.my calibRect_px(2) calibRect_px(2) calibRect_px(4) calibRect_px(4)];
                case 9 % N = 9
                    xcalib_px = [params.graphics.mx calibRect_px(3) calibRect_px(1) calibRect_px(3) calibRect_px(1) params.graphics.mx  calibRect_px(3)     params.graphics.mx  calibRect_px(1)];
                    ycalib_px = [params.graphics.my calibRect_px(2) calibRect_px(2) calibRect_px(4) calibRect_px(4) calibRect_px(2)     params.graphics.my  calibRect_px(4)     params.graphics.my];
                otherwise % defensive
                    error('Specified number of calibration targets (%i) not recognised', eyeParams.gazeCalibNPoints)
            end
            % ADD FINAL POINT TO MOVE BACK TO RIGHT OF MIDDLE
            xcalib_px = [xcalib_px params.graphics.mx+200];
            ycalib_px = [ycalib_px params.graphics.my-100];
            % flags
            isCalibrated = false;
            forceBlankCatchTrial = true;

            if IN_SIMULATION_MODE
                % start fixation centre of screen
                SetMouse(params.graphics.mx, params.graphics.my)
            end

            %%%%%%%%%%%%%%%%%%%%%% Begin Trial Loop %%%%%%%%%%%%%%%%%%%%%%%
            
            % n.b., while loop also useful, because we can manually
            % decremenet 'trialNum', on control (null) trials
            %while (trialNum < maxNTrials) && grid.hasSelectablePoints();
            while ~PsychoController.isFinished() && (nTestTrial < paradigm.maxNTestTrials)
                trialNum = trialNum + 1;

                % clear eye tracker buffer
                eyetracker.flush();
                
                % init log file name (with time of trial onset)
                eyeTrackerLogFn = sprintf('%s-%i-%i-%i-%s', metaParams.expID, metaParams.partID, metaParams.sessID, getBlockNum(), datestr(now(),30));

               
                %%%%%%%%%%%%%%%%%%%%% Calibrate, if necessary %%%%%%%%%%%%%%%%%%%%%

                % recalibrate automatically every N trials
                if IN_GAZE_RESP_MODE && 0 == mod(trialNum-1, eyeParams.recalib_afterNTrials) && trialNum>1
                    triggerRecalib = true;
                end
                
                if triggerRecalib
                    % clear any existing calibartion
                    IvCalibration.getInstance().clearMeasurements();
                    IvCalibration.getInstance().clear();            
                    %IvCalibration.getInstance().resetDriftCorrection(); % disabled in v0_0_5
                	isCalibrated = false;
                    calibClassifier.resetOnsetRampParams();
                    WaitSecs(0.1); % wait a bit to make sure buffer cleared (????)
                    eyetracker.flush();
                    
                    % Enable colour display (disable pseudogray)
                    if lumParams.useBitstealing
                        Screen('HookFunction', winhandle, 'Disable', 'FinalOutputFormattingBlit');
                    end
                
                    % present points, record gaze
                    tLastData_secs = GetSecs();
                    tmp_xcalib_px = xcalib_px;
                    tmp_ycalib_px = ycalib_px;
                    
                    while ~isempty(tmp_xcalib_px)
              
                        % shuffle presentation order (pick a random point
                        % to test)
%                         [tmp_xcalib_px,idx] = Shuffle(tmp_xcalib_px);
%                         tmp_ycalib_px = tmp_ycalib_px(idx);

                        % Run animation-loop: move cue
                        % If not first target, transpose the old target to
                        % the new location
                        if length(tmp_xcalib_px) < length(xcalib_px)
                            d_secs = 0.66;
                            T_x     = getTween(attentionGrabber.x_px, tmp_xcalib_px(1), d_secs, params.graphics.Fr, 'norm');
                            T_y     = getTween(attentionGrabber.y_px, tmp_ycalib_px(1), d_secs, params.graphics.Fr, 'norm');
                            T_scale	= getTween(attentionGrabber.scaleFactor, 1, d_secs, params.graphics.Fr, 'norm');
                            T_sway  = getTween(attentionGrabber.sway_deg, 0, d_secs, params.graphics.Fr, 'norm');
                            attentionGrabber.setSwaySpeed(0);
                            for i = 1:length(T_x)
                                % Query for input (to allow quitting)
                                InH.getInput();
                                
                                % Perform animation
                                attentionGrabber.init(T_x(i), T_y(i))
                                attentionGrabber.setScale(T_scale(i)); % log scaling from 1 to 0.25
                                attentionGrabber.setSway(T_sway(i));
                                
                                % Draw graphics
                                Screen('DrawTexture', winhandle, backTex);
                                attentionGrabber.draw(winhandle);
                                
                                % Update eyetracker
                                eyetracker.refresh(false); % false to supress logging
                                
                                % flip screen
                                Screen('Flip', winhandle);
                                
                                % pause momentarily
                                WaitSecs(params.graphics.ifi);
                            end
                        end
                        
                        % get next point & set positions
                        attentionGrabber.init(tmp_xcalib_px(1), tmp_ycalib_px(1))
                     	myGraphic.reset(tmp_xcalib_px(1), tmp_ycalib_px(1));
                        
                        % Start: classifier, audio
                        attentionGrabber.start();
                        calibClassifier.start();
                        eyetracker.refresh(false); % false to supress logging

                        % If in simulation mode, simulate an appropriate response
                        if IN_SIMULATION_MODE
                            SetMouse(tmp_xcalib_px(1), tmp_ycalib_px(1));
                        end
                        
                        % Run animation-loop until decision (or timeout)
                        % will keep testing each point until we detect a
                        % fixation or until N seconds have elapsed
                        isForcedHit = false;
                        while 1
                            % Query for input (to allow quitting or forcing)
                            if any(InH.getInput() == InH.INPT_SPACE.code)
                                isForcedHit = true;
                                fprintf('calibration point forced\n');
                                break
                            end

                            % Draw graphics
                            Screen('DrawTexture', winhandle, backTex);
                            attentionGrabber.draw(winhandle);
                            % Update eyetracker
                            [n, saccadeOnTime, blinkTime] = eyetracker.refresh(true); % false to supress logging
                            if n > 0 % Update classifier
                                %calibClassifier.update();
                                if ~isempty(saccadeOnTime)  || ~isempty(blinkTime)
                                    calibClassifier.start(false);
                                else
                                    calibClassifier.update();
                                end
                                
                                % determine how close to a decision we are, and animate the calibration-target (smiley face) accordingly
                                [~,propComplete] = calibClassifier.interogate();
                                p = max(propComplete(2),0);
                                % attentionGrabber.setScale(1 - p / 4); % linear scaling from 1 to 0.25
                                attentionGrabber.setScale(1./exp10(p)*0.835+0.165); % log scaling from 1 to 0.25
                                attentionGrabber.setSwaySpeed(0.25 + 6*p^2); % square scaling from 0.25 to 6.25
                                
                                % log when data last received (for
                                % warning operator)
                                tLastData_secs = GetSecs();
                                
                                % Assess stop-criteria
                                if calibClassifier.status == calibClassifier.STATUS_HIT % see if reached decision
                                    fprintf('calibration target hit\n');
                                    break
                                elseif calibClassifier.status == calibClassifier.STATUS_RETIRED
                                    fprintf('calibration point timed out\n');
                                    break
                                end
                            else
                                if (GetSecs() - tLastData_secs) > 1
                                    fprintf('waiting for data... [%1.2f seconds since last data]\n', GetSecs()-tLastData_secs);
                                end
                                % draw warning on screen
                                if (GetSecs() - tLastData_secs) > 4
                                    Screen('FillOval', winhandle, [255 0 0], [20 20 80 80]);
                                end
                            end
                            % flip screen
                            Screen('Flip', winhandle);
                            % pause momentarily
                            WaitSecs(params.graphics.ifi);
                        end
                        
                        % Restart calibration if no decision was reached, or if the
                        % classifier deemed that the observer did NOT fixate the
                        % target
                        if ~isForcedHit
                            anscorrect = strcmpi(calibClassifier.interogate().name, 'target');
                            if calibClassifier.isUndecided() || ~anscorrect
                                %eyetracker.setFixationMarker('whitedot'); % enable fixation marker for debugging
                                continue % restart trial (Aborted?)
                            end
                        end
                        
                        % remove fixation marker (in case has been
                        % manually reenabled previously for any reason)
                        if ~showFixationMarker
                            eyetracker.setFixationMarker('none');
                        end
                        
                        % add measurements to poly-calib
                        trueXY = [tmp_xcalib_px(1), tmp_ycalib_px(1)]; % assume fixating middle of target
                        estXYs = logs.data.getLastKnownXY(N_CALIB_SAMPLES_PER_LOC, true, false); % [useRaw, allowNan] : Use RAW rather than processed (n.b., no drift correction will be applied), don't permit NaNs
                        IvCalibration.getInstance().addMeasurements(trueXY, estXYs);
                        
                        % if was first point, use additive drift correction
                        % to help with next points, and disable onset-ramp
                        % henceforth
                        if length(tmp_xcalib_px) == length(xcalib_px)
                            fprintf('First calbration point complete: Performing drift correction\n;');
                            trueXY_px           = [tmp_xcalib_px(1), tmp_ycalib_px(1)]; % assume fixating middle of target
                            estXY_px            = nanmean(logs.data.getLastKnownXY(N_CALIB_SAMPLES_PER_LOC, true, false)); %nanmean defensive
                            maxCorrection_deg   = 15;
                            IvCalibration.getInstance().updateDriftCorrection(trueXY_px, estXY_px, maxCorrection_deg);
                            %
                            calibClassifier.resetOnsetRampParams(0,0);
                        end
                        
                        % done with calibrating this point, remove from
                        % test set
                        tmp_xcalib_px(1) = [];
                        tmp_ycalib_px(1) = [];
                        
                    end % end of all calibration points

                    % attempt to compute the eye-tracker calibration
                    if IvCalibration.getInstance().compute()
                        isCalibrated = true;
                        triggerRecalib = false;
                        % reset FN counters
                        falseNegative_n = 0;
                        falseNegative_nPossible = 0;
                        %falseNegative_rate = NaN;
                        fprintf('.. Success.');
                    else
                        beep();
                        warning('calibration failed(?)');
                        triggerRecalib = true;
                        continue % skip to next trial, whereupon calibration will start again (i.e., since triggerRecalib==true)
                    end

                    % reset fixation cross so it starts where the final calibration
                    % point left off
                    FixCrossDrawRect = CenterRectOnPoint(FixCrossRect, trueXY(1), trueXY(2));
                    
                    % lurk on a plain screen for a while, to give the
                    % observer a chance to evaluate the calibration
                    if IN_DEBUG_MODE
                        eyetracker.setFixationMarker('whitedot');
                        while ~any(InH.getInput() == USER_INPUT_CODE)
                            Screen('Flip', winhandle);
                            % Update eyetracker
                            eyetracker.refresh(false); % false to supress logging
                            % pause momentarily
                            WaitSecs(params.graphics.ifi);
                        end
                        if ~showFixationMarker
                            eyetracker.setFixationMarker('none');
                        end
                    end
                    
                    % pause for a short moment on blank screen to readjust
                    Screen('DrawTexture', winhandle, backTex);
                    if DRAW_FIX_CROSS
                        Screen('DrawTexture', winhandle, FixCrossTexture, FixCrossRect, FixCrossDrawRect);
                    end
                    Screen('Flip', winhandle);
                    WaitSecs(.33);
                end % end of calibration

                
                %%%%%%%%%%%%%%%%%%% !!! START TRIAL !!! %%%%%%%%%%%%%%%%%%%
                
                if IN_DEBUG_MODE
                    fprintf('\nStarting trial %i..\n', trialNum);
                end
                
                % determine first video frame of new trial
                if RECORD_WEBCAM
                    webcam_firstFrameNofCurrentTrial = vobj.FramesAcquired;
                    if IN_DEBUG_MODE
                        fprintf('  > Webcam status at start of trial %i:   %i (%i)\n', trialNum, vobj.FramesAcquired, vobj.DiskLoggerFrameCount);
                    end
                else
                    webcam_firstFrameNofCurrentTrial = NaN;
                end
                
                % init
                inCalibrationMode = false;
                
                % don't want to reset log, since we *want* to know where they
                % were last looking!! The downside of this is that can't
                % have a nice, compartmentalised data file for each trial
                %IvDataLog.getInstance().reset();
                            
                %%%%%%%%%%%%%%%%%%% Initialise Graphics %%%%%%%%%%%%%%%%%%%
                
                % ensure that pseudo-gray is enabled
                if lumParams.useBitstealing
                    Screen('HookFunction', winhandle, 'Enable', 'FinalOutputFormattingBlit');
                end

                %%%%%%%%%%%%%%%%% Ensure Eyes Are Tracked %%%%%%%%%%%%%%%%%
                %
                % Pause here and ensure eyetracker contact before
                % continuing (n.b., crucial for knowing where to place the
                % myStimulus). Key outcomes:
                %       - gaze_xy_px
                %       - lastKnownViewingDistance_cm
                %
                % NB: still required even if MOUSE_RESP mode

                % if no acceptably recent contact, or if gaze is too
                % variable (e.g., mid-saccade), play an attention grabber,
                % and wait until it is fixated (using a liberal classifier)
                startTime_secs = GetSecs();
                while 1
                    % get eye-tracking data
                    eyetracker.refresh(true); % logging
                    [gaze_xy_px, t] = logs.data.getLastKnownXY(1, false, false); % [useRaw, allowNan] : important that post-processing
                    
                    % no point continuing if data buffer is empty
                    if isempty(gaze_xy_px)
                        WaitSecs(0.05);
                        continue;
                    end
                    
                    % are the eyes sufficiently stationarity?
                    v = logs.data.getLastN(min(paradigm.stationarity_nPoints,logs.data.getN()), 8, false); % allow NaNs, get as many velocity points (column 8) as we can (up to paradigm.stationarity_nPoints)
                    if any(v > 999)
                        xyt = logs.data.getLastN(min(paradigm.stationarity_nPoints,logs.data.getN()), 1:3, false);
                        fprintf('%1.2f  %1.2f  %1.2f\n', xyt');
                        fprintf('%1.2f\n', v);
                        warning('Velocity > 999 deg/sec detected - this is most likely an error in the eyetracker timing code??');
                    end
                    stationarity_isViolated = any(v > paradigm.stationarity_criterion_degsec);

                    % compute the viewing distance, so that we can
                    % convert visual-degree parameters to pixels (N.B. this
                    % code is repeated below, within the while loop)
                    z_mm = eyetracker.getLastKnownViewingDistance();
                    lastKnownViewingDistance_cm = z_mm/10; % + graphicParams.monitorTrackerOffset_cm; % offset no longer required because explicit calibration has been performed
                    if lastKnownViewingDistance_cm < eyeParams.minCredibleViewDist_cm || lastKnownViewingDistance_cm > eyeParams.maxCredibleViewDist_cm
                        warning('impossible viewing distance? [%1.2f]. Value has been supressed.\n', lastKnownViewingDistance_cm);
%                         lastKnownViewingDistance_cm = NaN;
                        lastKnownViewingDistance_cm = graphicParams.assumedViewingDistance_cm;
                    end
                                        
                    %--- break loop if all in order -----------------------
                    % ensure that stationary tracking data is available
                    % from an acceptably recent time
                    if ~isempty(gaze_xy_px) && ((GetSecs()-t) < paradigm.trialInitContactThreshold_secs) && ~stationarity_isViolated && ~isnan(lastKnownViewingDistance_cm)
                        break
                    end
                
                    %--- give feedback to experimenter --------------------
                    if stationarity_isViolated
                        fprintf('waiting for eyes... [stationarity violated]\n');
                    elseif isnan(lastKnownViewingDistance_cm)
                        fprintf('waiting for eyes... [no known viewing distance]\n');
                    elseif isempty(gaze_xy_px)
                        fprintf('waiting for eyes... [no data found]\n');
                    else
                        fprintf('t = %1.3f    now = %1.3f\n', t, GetSecs())
                        fprintf('waiting for eyes... [latest data too old]\n');
                    end
                        
                    %--- grace period before attention grabber ------------
                    if (GetSecs()-startTime_secs) < 0.5
                        WaitSecs(0.02);
                        continue
                    end
                    
                    %--- run attention grabber ----------------------------
                    %  make this next bit run in colour
                    if lumParams.useBitstealing
                        Screen('HookFunction', winhandle, 'Disable', 'FinalOutputFormattingBlit');
                    end
                    
                    % determine attention-grabber placement
                    screenMargins_px = round(IvUnitHandler.getInstance().deg2px(stimParams.screenMargins_deg, lastKnownViewingDistance_cm));
                    grabberMargins_px = stimParams.additionalGrabberMargins_px; % [250 250 -250 -250];
                    grabberRect_px = winrect_px + (screenMargins_px+grabberMargins_px);
                    % if its lost eyes just place it in the middle of the
                    % screen and hope for the best!
                    if any(isnan(grabberRect_px))
                        targx_px = params.graphics.mx;
                        targy_px = params.graphics.my;
                    else
                        % otherwise try to pick a random location
                        try
                            targx_px = randi([grabberRect_px(1) grabberRect_px(3)]);
                            targy_px = randi([grabberRect_px(2) grabberRect_px(4)]);
                        catch ME
                            disp(grabberRect_px);
                            error(ME);
                        end
                    end
 
                    % Start: flush eyetracker, start classifier, start audio
                    attentionGrabber.init(targx_px, targy_px);
                    % n.b., using myGraphic rather than
                    % attentionGrabber.ivGraphicStub so that we don't have
                    % to make a new classifier in-between trials
                    myGraphic.reset(targx_px, targy_px);
                    myClassifier.setCriterion(20);
                    myClassifier.start();
                    attentionGrabber.start();
                    
                    % If in simulation mode, simulate an appropriate response
                    if IN_SIMULATION_MODE
                        SetMouse(targx_px, targy_px);
                    end
                    
                    % Run until decision (or timeout)
                    while 1
                        % Query for input (to allow quitting)
                        InH.getInput();
                        
                        % Draw background
                        if lumParams.is10Bit
                            Screen('DrawTexture', winhandle, backTex);
                        else
                            Screen('DrawTexture', winhandle, backTex_mu);
                        end
                        
                        % Draw graphic
                        attentionGrabber.draw(winhandle);
                        Screen('Flip', winhandle);
                        
                        % Update eyetracker
                        n = eyetracker.refresh(true); % logging

                        % Update classifier % compute velocity
                        if n > 0
                            myClassifier.update();
                            
                            % compute whether gaze is sufficiently
                            % stationary, by checking whether *any* of the
                            % previous N velocity samples exceed some
                            % specified value (deg-per-sec)
                            v = logs.data.getLastN(min(paradigm.stationarity_nPoints,logs.data.getN()), 8, false); % allow NaNs, get as many velocity points (column 8) as we can (up to paradigm.stationarity_nPoints)
                            stationarity_isViolated = any(v > paradigm.stationarity_criterion_degsec & v < 999);
                            
                            if ~myClassifier.isUndecided() && ~stationarity_isViolated % see if reached decision
                                % update calibration - if we've reached
                                % this point then the subject has looked at
                                % the attention grabber. So we might as
                                % well add the data to the eyetracker
                                % calibration
                                resp = myClassifier.interogate().name;
                                anscorrect = strcmpi(resp, 'target');
                                if anscorrect
                                    trueXY = [targx_px targy_px];
                                    % update drift correction
                                    %estXY = logs.data.getLastKnownXY(1, false, false); % [useRaw, allowNan] : Use PROCESSED rather than raw, don't permit NaNs (mportant that post-processing)
                                    % update calibration
                                    estXYs = logs.data.getLastKnownXY(20, true, false); % [useRaw, allowNan] : Use RAW rather than processed, don't permit NaNs
                                    IvCalibration.getInstance().addMeasurements(trueXY, estXYs);
                                    IvCalibration.getInstance().compute();
                                end
                                
                                % stop the attention grabber routine
                                break
                            end
                        end
                
                        % pause momentarily, before continuing to the next
                        % frame of the attentiongrabber routine
                        WaitSecs(params.graphics.ifi);
                    end

                    % ensure that pseudo-gray is re-enabled
                    if lumParams.useBitstealing
                        Screen('HookFunction', winhandle, 'Enable', 'FinalOutputFormattingBlit');
                    end
                end % end waiting-for-eyes loop

                %%%%%%%%%%%%% Determine Stimulus Placement %%%%%%%%%%%%%%%%
                %
                % Key outcomes:
                %       - stimOffset_px
                %       - gridPoint
                %       - myStimulus
                %       - myStimulus.setLocation(x_px, y_px)
                %       - isBlankCatchTrial
                
                % validation (defensive)
                if isnan(lastKnownViewingDistance_cm) || lastKnownViewingDistance_cm < eyeParams.minCredibleViewDist_cm || lastKnownViewingDistance_cm > eyeParams.maxCredibleViewDist_cm
                    error('lastKnownViewingDistance_cm cannt be NaN at this point!');
                end
                
                % init
                screenMargins_px = round(IvUnitHandler.getInstance().deg2px(stimParams.screenMargins_deg, lastKnownViewingDistance_cm));
                validRect_px = winrect_px + screenMargins_px;
                nStimPlacementFails = 0;

                isRefixationTrial = false;
                isEasyCatchTrial = false;
                isBlankCatchTrial = false;
                isValidPlacement = false;
                while ~PsychoController.isFinished() && ~isValidPlacement % PsychoController may finish during attempted placement if the last point gets aborted
                    
                    % see if there is already a stimulus queued for
                    % presentation (i.e., if we just refixated to be able
                    % to view this point..)
                    if ~isempty(stimulusToReturnTo)
                        x_rel_deg = stimulusToReturnTo.x_rel_deg;
                        y_rel_deg = stimulusToReturnTo.y_rel_deg;
                        targLum_dB = stimulusToReturnTo.targLum_dB;
                        % clear queue
                        stimulusToReturnTo = [];
                    else
                        % select a random gridpoint
                        [x_rel_deg, y_rel_deg, targLum_dB] = PsychoController.getTarget();
                    end

                    % compute target location, in pixels
                    % @TODO account for arc tangent?                    
                    x_rel_px = IvUnitHandler.getInstance().deg2px(x_rel_deg, lastKnownViewingDistance_cm);
                    y_rel_px = -IvUnitHandler.getInstance().deg2px(y_rel_deg, lastKnownViewingDistance_cm); % n.b., y inverted so as to match PTB (in PTB origin, <0,0>, is at top-left)
                    x_px = round(gaze_xy_px(1) + x_rel_px); % offset from current gaze position, to get absolute location on screen
                    y_px = round(gaze_xy_px(2) + y_rel_px);
                    % x_rel_px = round(x_rel_px);
                    % y_rel_px = round(y_rel_px);

                    % compute whether grid point lies at a valid location
                    distFromCentre_px   = sqrt(sum([x_px-params.graphics.mx y_px-params.graphics.my ].^2));
                    distFromTopLeft_px  = sqrt(sum([x_px-validRect_px(1)    y_px-validRect_px(2)    ].^2));
                    distFromTopRight_px = sqrt(sum([x_px-validRect_px(3)    y_px-validRect_px(2)    ].^2));
                    distFromBottomLeft_px  = sqrt(sum([x_px-validRect_px(1)    y_px-validRect_px(4)    ].^2));
                    distFromBottomRight_px = sqrt(sum([x_px-validRect_px(3)    y_px-validRect_px(4)    ].^2));
                    
                    % if placement is valid, create a standard myStimulus
                    % object, and set location.
                    if IsInRect(x_px, y_px, validRect_px)                               ...
                        && (distFromCentre_px > stimParams.minDistFromCentre_px)        ...
                        && (distFromTopRight_px > stimParams.minDistFromTopRight_px) 	... 
                        && (distFromTopLeft_px > stimParams.minDistFromTopLeft_px)   	...
                        && (distFromBottomRight_px > stimParams.minDistFromBottomRight_px) ... 
                        && (distFromBottomLeft_px > stimParams.minDistFromBottomLeft_px)
                        
                        % myStimulus successfully placed: create...
                        % ...and note if it is a catch trial
                        switch targLum_dB
                            case {Inf, forceBlankCatchTrial*targLum_dB}
                                isBlankCatchTrial = true;
                                forceBlankCatchTrial = false;
                            case -Inf
                                isEasyCatchTrial = true;
                            otherwise
                                nTestTrial = nTestTrial + 1;
                        end
                        myStimulus = myTestpointStimulus;

                        % break loop
                        isValidPlacement = true;
                    else
                        % myStimulus placement failed
                        if IN_DEBUG_MODE
                            beep();
                            fprintf('myStimulus {%1.1f %1.1f} placement failed {%1.1f %1.1f} [%1.1f %1.1f]\n', x_rel_deg, y_rel_deg, gaze_xy_px(1), gaze_xy_px(2), x_px, y_px);
                        end
                        nStimPlacementFails = nStimPlacementFails + 1;
                        
                        % record number of attempts: abort point if it's
                        % failed to be placed too many times
                        n = PsychoController.registerPlacementFailure(x_rel_deg, y_rel_deg);
                        if n > stimParams.abortLocationAfterNattempts
                            warning('Giving up on point: %i, %i', x_rel_deg, y_rel_deg);
                            PsychoController.abortPoint(x_rel_deg, y_rel_deg);
                        end
                        
                        % if too many failed attempts have occurred, attempt to
                        % refixate elsewhere, and then try again
                        if nStimPlacementFails >= stimParams.maxPlaceAttemptsBeforeRefix
                            if IN_DEBUG_MODE
                                fprintf('Stimulus presentation critical failure: resorting to fixation cue\n');
                            end
                             
                            % set flag to true
                            isRefixationTrial = true;
                            
                            % store previous gridPoint so that we can
                            % return to it after this refixation trial
                            stimulusToReturnTo.x_rel_deg = x_rel_deg;
                            stimulusToReturnTo.y_rel_deg = y_rel_deg;
                            stimulusToReturnTo.targLum_dB = targLum_dB;

                            % Set targLum_dB to minimum value (same as with
                            % False Negative catch trials)
                            targLum_dB = -Inf;
                            
                            % Determine fixation-shifter placement. Rather
                            % than dumbly placing in centre, will put it
                            % somewhere more likely to allow the previous
                            % point to be shown. But will add some
                            % randomness to stop things getting too
                            % predictable

                            % determine location limits given normal
                            % stimulus placement constraints (aside from
                            % the corner constraints)
                            %xmin = round(max(validRect_px(1), validRect_px(1) - x_rel_px)); % n.b., validRect_px includes a margin
                            %xmax = round(min(validRect_px(3), validRect_px(3) - x_rel_px));
                            %ymin = round(max(validRect_px(2), validRect_px(2) - y_rel_px));
                            %ymax = round(min(validRect_px(4), validRect_px(4) - y_rel_px));
                            
                            % not required to fall within standard screen
                            % area. Instead, will make sure only that the
                            % full refixation stimulus falls on the screen
                            %
                            % NB: This is not ideal, because these points
                            % are used to measure false-negatives, and to
                            % (thereby) trigger recalibrations. Arguibaly
                            % they should therefore be constrained to fall
                            % within the standard stimulus placement area,
                            % but since we are currently very tight for
                            % space this seems the preferable compromise
                            %screenRefixMargins_px = round(IvUnitHandler.getInstance().deg2px(myRefixationStimulus.diameter_deg/2, lastKnownViewingDistance_cm));
                            % allow for half a width's gap
                            screenRefixMargins_px = round(IvUnitHandler.getInstance().deg2px(myRefixationStimulus.diameter_deg, lastKnownViewingDistance_cm));
                            validRefixRect_px = winrect_px + [screenRefixMargins_px screenRefixMargins_px -screenRefixMargins_px -screenRefixMargins_px];
                            xmin = round(min(validRefixRect_px(3), max(validRefixRect_px(1), validRefixRect_px(1) - x_rel_px))); % n.b., validRect_px includes a margin
                            xmax = round(max(validRefixRect_px(1), min(validRefixRect_px(3), validRefixRect_px(3) - x_rel_px)));
                            ymin = round(min(validRefixRect_px(4), max(validRefixRect_px(2), validRefixRect_px(2) - y_rel_px)));
                            ymax = round(max(validRefixRect_px(2), min(validRefixRect_px(4), validRefixRect_px(4) - y_rel_px)));
                            
                            if xmax<xmin
                                if IN_DEBUG_MODE
                                    warning('xmax < xmin!!!!');
                                    beep();
                                end
                                xmax = max(xmin, xmax);
                            end
                            if ymax<ymin
                                if IN_DEBUG_MODE
                                    warning('ymax < ymin!!!!');
                                    beep();
                                end
                                ymax = max(ymin, ymax);
                            end
                            
                            try
                                if IN_DEBUG_MODE
                                    fprintf('Attempting to generate random stimulus position..\n');
                                end
                                %x_px = randi([xmin xmax]);
                                %y_px = randi([ymin ymax]);
                                
                                % generate N random positions, and select
                                % that one that is maximally far from the
                                % original target
                                N = 6;
                                % X
                                refix_x_px = randi([xmin xmax], N,1);
                                [~,idx] = max(abs(x_px - refix_x_px));
                                x_px = refix_x_px(idx);
                                % Y
                                refix_y_px = randi([ymin ymax], N,1);
                                [~,idx] = max(abs(y_px - refix_y_px));
                                y_px = refix_y_px(idx);
                            catch ME
                                disp([xmin xmax]);
                                disp([ymin ymax]);
                                disp(y_px);
                                disp(y_rel_px);
                                disp(validRect_px);
                                rethrow(ME);
                            end

                            % initialise myStimulus
                            myStimulus = myRefixationStimulus;
                            
                            % break loop
                            isValidPlacement = true;
                        end
                    end
                end
                
                % check if finished(?)
                if PsychoController.isFinished()
                    continue;
                end
                
                % !Set location!
                myStimulus.setLocation(x_px, y_px);
                
                
                %%%%%%%% Rescale classification box based on distance %%%%%
                % further away points should be classified more liberally
                % (e.g., larger hit box, and fewer gaze-points required),
                % while near points should be classified more
                % conservatively
%                 if ~isCalibrated && IN_FINAL_MODE
%                     error('NOT CALIBRATED??????')                    
%                 end
 
                % compute distance-sensitive modifiers (relax classifier at
                % more distant locations)
                d_deg = sqrt(x_rel_deg^2 + y_rel_deg^2);
                addscale_deg = max(0,d_deg-eyeParams.relaxClassifierAfterNdegs)/4; % an extra 2.5 deg at 15 deg
                addpoints_n = 0; % -round(min(eyeParams.npoints-1, eyeParams.npoints * max(0,d_deg-eyeParams.relaxClassifierAfterNdegs)/20));

                % apply classifier settings
                boxdims_px = IvUnitHandler.getInstance().deg2px(eyeParams.boxdims_deg+addscale_deg, lastKnownViewingDistance_cm);
                myClassifier.setBoxMargins(boxdims_px);
                myClassifier.setCriterion(eyeParams.npoints + addpoints_n);

                % should take at least the number of samples, but some
                % arbitrary offset to respond (see/saccade) to the
                % stimulus. If the trial is shorter than this then probably
                % a calibration/stimulus-placement error, and the trial
                % should be repeated
                if IN_MOUSE_RESP_MODE
                    minAcceptableTrialDuration_secs = 0.01;
                else
                    %minAcceptableTrialDuration_secs = (1/samplingRate_hz) * (eyeParams.npoints + addpoints_n) + (1/3);
                 	minAcceptableTrialDuration_secs = (0.5/samplingRate_hz) * (eyeParams.npoints + addpoints_n) + (1/3);
                end
                
                %%%%%%%%%%%%%%%%%% Calibrate Luminance %%%%%%%%%%%%%%%%%%%%
                %
                % Determine luminance calibration for this screen
                % coordinate. Key outcomes:
                %       - myStimulus.setLuminance(stimLuminance_norm);

                % ---------------------------------------------------------
                % Get target luminance, in cdm2 and normalised (0 to 1)
                % units 
                if isEasyCatchTrial || isRefixationTrial
                    %targAbs_cdm2 = 999; %lumParams.maxAbsLum_cdm2;
                    stimLuminance_norm = 1;
                    targAbs_cdm2 = fittedmodel_backwards(stimLuminance_norm);
                elseif isBlankCatchTrial
                    stimLuminance_norm = 0; % won't actually be shown anyway
                    targAbs_cdm2 = fittedmodel_backwards(stimLuminance_norm);
                else
                    if targLum_dB < 0
                        warning('PsychoController requested targLum_dB < 0 (%1.2). Will change to 0 value for actual presentation', targLum_dB)
                    end
                    [~, targAbs_cdm2] = VfUnitHandler.getInstance().db2cd(max(targLum_dB,0));
                    % map to normalised (0 to 1) units
                    stimLuminance_norm = fittedmodel(targAbs_cdm2); %square_luminance_norm = (fittedmodel(targ_luminance) - volts_min) / (volts_max - volts_min)
                end

                % !Set luminance!
                myStimulus.setLuminance(stimLuminance_norm);

                
                %%%%%%%%%%%%%%%%% Compute myStimulus Size %%%%%%%%%%%%%%%%%%%
                %
                % Rescale myStimulus size based on current viewing distance.
                % Key outcomes:
                %       - myStimulus.setDiameter(stimDiameter_px);

                % get desired stimulus size (DVA)
                stimDiameter_deg = myStimulus.diameter_deg;

                % convert to pixels
                stimDiameter_px = IvUnitHandler.getInstance().deg2px(stimDiameter_deg, lastKnownViewingDistance_cm);
                stimDiameter_px = 2*round(stimDiameter_px/2);  % round to nearest even number
                n = stimDiameter_px + 2*myStimulus.PADDING_PX;
                
                % Get subset of the background that surrounds/encorporates
                % the stimulus. Set any pixels outside of screen area to be
                % NaNs  
                yidx = y_px+((-n/2+1):(n/2)); % +1 hack
                xidx = x_px+((-n/2+1):(n/2));
                back = nan(length(yidx), length(xidx));
                iy = yidx>0 & yidx<=screenHeight_px;
                ix = xidx>0 & xidx<=screenWidth_px;
                back(iy,ix) = backgroundMatrix(yidx(iy), xidx(ix));
                
                % initialise figure. Apply warping/smoothing
                try
                    myStimulus.initGraphic(winhandle, stimDiameter_px, warper, shader, back, stimParams.useStimRamping, stimParams.useStimWarping, stimParams.useLegacyMode)
                catch ME
                    fprintf('FAILED TO INIT GRAPHIC WITH THESE PARAMS????:\n')
                    %winhandle, stimDiameter_px, warper, shader, back, stimParams.useStimRamping, stimParams.useStimWarping, stimParams.useLegacyMode %#ok
                    rethrow(ME);
                end
                
                %%%%%%%%%%%%% Pause for a variable duration %%%%%%%%%%%%%%%
% should this be here, what if they move their eyes during this intervening period?                
                d = min(paradigm.delayMin_secs + abs(randn)*paradigm.delaySigma_secs, paradigm.delayMax_secs);
                delta = d-(GetSecs()-startTime_secs);  % account for any processing time taken to get to this point from trial onset
% @todo !!!!SUBTRACT ANY DELAY FROM RECORD_WEBCAM also!!!                
                if delta < 0 && (d-(GetSecs()-startTime_secs)) > 0.01 % don't bother warning for small infringements
                    warning('Missed the trial onset deadline (by %1.2f secs)   ::  Processing time was %1.2f\n', d-(GetSecs()-startTime_secs), delta);
                    delta = 0;
                end
                WaitSecs(d-delta);
                
                
                %%%%%%%%%%%% Present stimulus / Get response %%%%%%%%%%%%%%
                
                % set colour (if necessary)
                if lumParams.useBitstealing
                    if myStimulus.IS_COLOUR
                        Screen('HookFunction', winhandle, 'Disable', 'FinalOutputFormattingBlit');
                    else
                        Screen('HookFunction', winhandle, 'Enable', 'FinalOutputFormattingBlit');
                    end
                end
                
                
                % short pause before stimulus on trial 1
                if trialNum==1
                    % draw background
                    Screen('DrawTexture', winhandle, backTex);

                    % draw fixation cross
                    if DRAW_FIX_CROSS
                        Screen('DrawTexture', winhandle, FixCrossTexture, FixCrossRect, FixCrossDrawRect);
                    end
                    
                    % update display
                    Screen('Flip', winhandle); % n.b., requires that ivis.broadcaster.* has been imported
                    WaitSecs(1/graphicParams.Fr); 
                    
                    % short pause
                    WaitSecs(2);
                end
                
                % let's go!
                trialStartTime_secs = GetSecs();
               	FlushEvents(); % keyboard/mouse
                eyetracker.flush();
                myGraphic.reset(myStimulus.x_px, myStimulus.y_px); % note that this is not the same as "myGraphic.reset(x_px, y_px);", as the stimulus centroid may have shifted during the warping process. Also note that this only affects the classifier, not where the image is drawn
                myClassifier.start();
                myStimulus.start();
                
                % show classifier box, if debugging
                if IN_DEBUG_MODE
                    myClassifier.show();
                end
                
                % if in simulation mode, move gaze to the target if below
                % threshold
                if IN_SIMULATION_MODE
                    % get true threshold at this location (for ease, will
                    % assume true threshold == prior
                    idx = PsychoController.zObj.locations_deg(:,:,1)==x_rel_deg & PsychoController.zObj.locations_deg(:,:,2)==y_rel_deg;

                    % determine if answer was correct
                    anscorrect = false;
                    if targLum_dB < normrnd(sim_thresh_mu(idx), sim_thresh_sd(idx))
                        if rand()<(1-sim_lapseRate) % lapse rate 10%
                            anscorrect = true;
                        end
                    elseif rand()<sim_guessRate
                        anscorrect = true;
                    end
                    
                    % Pause before making response: necessary to prevent trial being aborted for being too fast!
                    WaitSecs(0.5);
                    
                    % if answer WAS correct, move mouse to target location
                    if anscorrect
                        if IN_GAZE_RESP_MODE
                            SetMouse(myStimulus.x_px, myStimulus.y_px);
                        end
                        if IN_MOUSE_RESP_MODE
                            robot.mousePress(InputEvent.BUTTON1_MASK);
                        end
                       fprintf('Hit: targ=%1.2f dB; thresh=%1.2f dB\n', targLum_dB, sim_thresh_mu(idx)) 
                    else
                        
                            robot.mouseRelease(InputEvent.BUTTON1_MASK);
                       fprintf('Missed: targ=%1.2f dB; thresh=%1.2f dB\n', targLum_dB, sim_thresh_mu(idx)) 
                    end
                end

                % present myStimulus and get response
                while myClassifier.isUndecided()
                    
                    % draw background
                    Screen('DrawTexture', winhandle, backTex);

                    % if in debug mode, annotate the screen with debug info
                    if IN_DEBUG_MODE
                        % print distance to screen
                        Screen('DrawText', winhandle, sprintf('%1.2f',lastKnownViewingDistance_cm), params.graphics.mx, params.graphics.my, [1 1 1]);
                        % print margins
                        Screen('FrameRect', winhandle, 255, validRect_px);
                        Screen('FrameOval', winhandle, 255, [0 0 0 0]'+stimParams.minDistFromTopLeft_px*[-1 -1 1 1]');
                        Screen('FrameOval', winhandle, 205, [screenWidth_px 0 screenWidth_px 0]'+stimParams.minDistFromTopRight_px*[-1 -1 1 1]');
                        Screen('FrameOval', winhandle, 155, [params.graphics.mx params.graphics.my params.graphics.mx params.graphics.my]' + stimParams.minDistFromCentre_px*[-1 -1 1 1]');
                        Screen('FrameOval', winhandle, 255, [0 screenHeight_px 0 screenHeight_px]'+stimParams.minDistFromBottomLeft_px*[-1 -1 1 1]');
                        Screen('FrameOval', winhandle, 205, [screenWidth_px screenHeight_px screenWidth_px screenHeight_px]'+stimParams.minDistFromBottomRight_px*[-1 -1 1 1]');
                        % print target location
                        Screen('FillRect', winhandle, [0 1 0], [x_px-5 y_px-5 x_px+5 y_px+5]);
                    end
                    
                    % check for mouse press (NB: this should really be done
                    % through the input handler, below, but mouse button
                    % press detection doesn't seem to be working?)
                    if IN_MOUSE_RESP_MODE
                        [~,~,buttons] = GetMouse();
                        if any(buttons)
                            myClassifier.forceAnswer(1);
                        end
                    end
                    
                    % get user input
                    switch first(InH.getInput())
                        % case InH.INPT_CLICK.code
                        %     if IN_MOUSE_RESP_MODE
                        %         myClassifier.forceAnswer(1);
                        %         beep();
                        %     end
                        % case InH.INPT_RIGHTCLICK.code
                        %     if IN_MOUSE_RESP_MODE
                        %         myClassifier.forceAnswer(1);
                        %         beep();
                        %     end
                        case InH.INPT_SPACE.code
                            break
                     	case InH.INPT_SHOWFIXATION.code
                            showFixationMarker = ~showFixationMarker;
                            if showFixationMarker
                                eyetracker.setFixationMarker('whitedot');
                            else
                                eyetracker.setFixationMarker('none');
                            end
                        case InH.INPT_DRAWGRID.code
                            lx_px = linspace(0,screenWidth_px,7); % vertical lines
                            %lx_px = [200 400 450]; % vertical manual
                            ly_px = linspace(0,screenHeight_px,9); % horizontal lines
                            for y=ly_px
                                hlines = [0 screenWidth_px; y y];
                                Screen('DrawLines', winhandle, hlines, 2, [0 1 0]);
                            end
                            for x=lx_px
                                vlines = [x x; 0 screenHeight_px];
                                Screen('DrawLines', winhandle, vlines, 2, [0 1 0]);
                            end
                            Screen('Flip', winhandle); % n.b., requires that ivis.broadcaster.* has been imported
                            KbWait([],2);
                        case InH.INPT_WRONG.code
                            myClassifier.forceAnswer(0);
                        case InH.INPT_RIGHT.code
                            myClassifier.forceAnswer(1);
                        case InH.INPT_TRIGGER_EYETRACKER_CALIBRATION.code % eyetracker recalibration
                            triggerRecalib = true;
                        case InH.INPT_CALIBRATE_SCREEN.code % monitor calibration
                            fprintf('Target luminance: %1.2f dB  =>  %1.4f cd/m2  =>  %1.6f (norm)\n', targLum_dB, targAbs_cdm2, stimLuminance_norm);
                            ListenChar(0)
                            % Set position
                            x_px = getRealInput('(blank to leave) x_px = ',true);
                            y_px = getRealInput('(blank to leave) y_px = ',true);
                            if ~isempty(x_px) && ~isempty(y_px)
                                myStimulus.setLocation(x_px, y_px);
                            end
                            % Set luminance
                            [~, targAbs_cdm2] = VfUnitHandler.getInstance().db2cd(targLum_dB);
                            stimLuminance_norm = fittedmodel(targAbs_cdm2); %square_luminance_norm = (fittedmodel(targ_luminance) - volts_min) / (volts_max - volts_min)
                            myStimulus.setLuminance(stimLuminance_norm);
                            fprintf('Target luminance: %1.2f dB  =>  %1.4f cd/m2  =>  %1.6f (norm)\n', targLum_dB, targAbs_cdm2, stimLuminance_norm);
                    end
 
                    % query eyetracker
                    n = eyetracker.refresh(true); % false to supress logging
                    
                    % if any new data, update classifier
                    if n > 0 && ~inCalibrationMode % update classifier
                        myClassifier.update();
                       	responseLatency_secs = GetSecs() - myStimulus.startTime_secs;
                    end
                    
                    % draw fixation cross
                    if DRAW_FIX_CROSS
                        Screen('DrawTexture', winhandle, FixCrossTexture, FixCrossRect, FixCrossDrawRect);
                    end
                                
                    % draw stimulus
                    if ~isBlankCatchTrial
                        myStimulus.draw(winhandle);                      
                    end

                    % update display
                    Screen('Flip', winhandle); % n.b., requires that ivis.broadcaster.* has been imported
                    WaitSecs(1/graphicParams.Fr);           
                end
                
                % record end time
                trialEndTime_secs = GetSecs();
                
                % record average response location
                xy = logs.data.getLastN(min(eyeParams.npoints, logs.data.getN()), 1:2, true); % don't allow NaNs, get as many xy coordinates (columns 1:2) as we can, up to eyeParams.npoints
                obs_x_px = nanmean(xy(:,1)); % defensive
                obs_y_px = nanmean(xy(:,2));
                
                % defensive                
                myStimulus.stop();

                % ensure classifier is hidden (e.g., if in debugging mode)
                myClassifier.hide();
                
                % note end time in webcam frames
                if RECORD_WEBCAM
                    webcam_lastFrameNofCurrentTrial = vobj.FramesAcquired;
                else
                    webcam_lastFrameNofCurrentTrial = NaN;
                end
                
                %%%%%%%%%%%%%%%%%%%% Evaluate Response  %%%%%%%%%%%%%%%%%%%
                
                % evaluate resposne
                resp = myClassifier.interogate().name;
                anscorrect = strcmpi(resp, 'target');
                respDeviatedFromPath = strcmpi(resp, 'nothing'); % actively looked in the wrong region
                nCorrect = nCorrect + anscorrect;
                           
                % check valid
                isTrialValid = true;
                if IN_DEBUG_MODE &&  anscorrect
                    fprintf('  > Response latency (minus classification): %1.2f\n', responseLatency_secs - (1/samplingRate_hz) * (eyeParams.npoints + addpoints_n))
                end
                if responseLatency_secs < minAcceptableTrialDuration_secs && ~IN_SIMULATION_MODE
                    warning('  > Response latency (%1.2f) below minimum required (%1.2f). Trial will be aborted', responseLatency_secs, minAcceptableTrialDuration_secs);
                    isTrialValid = false;
                end
                
                if isTrialValid
                    % update system
                    if ~isRefixationTrial % refixation trials won't correspond to anything on grid
                        % PsychoControllerWrapper will automatically detect if
                        % isinf(targLum_dB), and will treat as catch trial
                        PsychoController.update(x_rel_deg, y_rel_deg, targLum_dB, anscorrect, responseLatency_secs/1000);
                    else
                        PsychoController.registerRefixationCue(anscorrect);
                    end
                    
                    % update false positive count if necessary (assume that
                    % refixation points should always be seen)
                    if isRefixationTrial || isEasyCatchTrial
                        falseNegative_nPossible = falseNegative_nPossible + 1;
                        if ~anscorrect
                            falseNegative_n = falseNegative_n + 1;
                        end
                        
                        % compute miss rate
                        falseNegative_rate = falseNegative_n / falseNegative_nPossible;
                        
                        % see whether a recalibration is required
                        if (falseNegative_rate > eyeParams.recalib_falseNegativeMin) && (falseNegative_nPossible > eyeParams.recalib_minNfalseNegtrials)
                            fprintf('False negative rate too high (%i of %i; %1.2f%%). Triggering recalibration\n', falseNegative_n, falseNegative_nPossible, 100*falseNegative_rate);
                            triggerRecalib = true;
                            % reset counters
                            falseNegative_n = 0;
                            falseNegative_nPossible = 0;
                            %falseNegative_rate = NaN;
                        end
                    end
                    
                    % update eye-tracker calibration iff answer scored as
                    % correct
                    if anscorrect && ~IN_MOUSE_RESP_MODE
                        trueXY = [myStimulus.x_px, myStimulus.y_px]; % assume fixating middle of target
                        n = min(eyeParams.npoints-2, 3);
                        if size(xy) < n
                            if IN_DEBUG_MODE
                                fprintf('NOT ENOUGH POINTS??!?!?!?!?! ABORTING!\n');
                            end
                        else
                            estXYs = xy(1:n,1:2); % get last N samples
                            % add measurements to poly-calib
                            IvCalibration.getInstance().addMeasurements(trueXY, estXYs);
                            % recompute
                            n = IvCalibration.getInstance().getNMeasurements();
                            if n > 100 % tmp hack!
                                ok = IvCalibration.getInstance().compute([],[],[],[],0); %#ok force silent
                                %fprintf('Eye-tracker calibration status: %i\n', ok)
                            end
                        end
                    end
                end


                %%%%%%%%%%%%%%%%%%%% Provide Feedback  %%%%%%%%%%%%%%%%%%%%

                % command line feedback
                if IN_DEBUG_MODE
                    if anscorrect
                        fprintf('  > Hit\n');
                    else
                        fprintf('  > Miss\n');
                    end
                end
                        
                % some stimuli (e.g., certain fixation grabbers) should not
                % be rewarded
                if myStimulus.IS_REWARDABLE
                    
                    if anscorrect
                        % enable colour
                        if lumParams.useBitstealing && rewarder.isInColour
                            Screen('HookFunction', winhandle, 'Disable', 'FinalOutputFormattingBlit');
                        end
                        
                        % give feedback
                        rewarder.init(myStimulus.x_px, myStimulus.y_px);
                        rewarder.start(paradigm.rewarder_playAudio);
                        
                        % Run
                        if paradigm.rewarder_playGraphics
                            for i = 1:rewarder.nFrames
                                % Query for input (to allow quitting)
                                InH.getInput();
                                % Draw graphics
                                Screen('DrawTexture', winhandle, backTex_fback);  % draw background
                                if DRAW_FIX_CROSS
                                    if ~IN_MOUSE_RESP_MODE % update fixation cross to be where last stimulus was
                                        FixCrossDrawRect = CenterRectOnPoint(FixCrossRect, myStimulus.x_px, myStimulus.y_px);
                                    end
                                    Screen('DrawTexture', winhandle, FixCrossTexture, FixCrossRect, FixCrossDrawRect);
                                end
                                rewarder.draw(winhandle);
                                % Update eyetracker
                                eyetracker.refresh(true); % logging
                                % pause momentarily
                                Screen('Flip', winhandle);
                                WaitSecs(params.graphics.ifi);
                            end
                        elseif paradigm.rewarder_playAudio % still wait to wait for audio
                            WaitSecs(.3);
                        end
   
                        % restore pseudogray
                        if rewarder.isInColour && lumParams.useBitstealing
                            Screen('HookFunction', winhandle, 'Enable', 'FinalOutputFormattingBlit');
                        end
                        
                        % make sure audio finished
                        rewarder.stop();
                    elseif respDeviatedFromPath && IN_DEBUG_MODE
                        % only bother to flag up deviations in debug mode
                        % (though in future versions could consider playing
                        % a stern 'beep' to discourage such behaviour)
                        rewarder.playIncorrect();
                    end
                end               
                
                
                %%%%%%%%%%%%%%%%%%%%%%%% Update experimenter on progress %%%%%%%%%%%%%%%%%%%%%%%
                % only print updates to console every Nth trial, to avoid
                % clutter
                if mod(trialNum,50)==0
                    if IN_DEBUG_MODE
                        approxPercentComplete = 100 * trialNum ./ 330;
                        fprintf('%i. approx %1.2f%% complete\n', trialNum, approxPercentComplete);
                    end
                    PsychoController.printSummary();
                end
                
                %%%%%%%%%%%%%%%%%%%%%%%% Save Data  %%%%%%%%%%%%%%%%%%%%%%%
                % save trial data
				eye = eyeParams.eye;
                grid_estimates = PsychoController.getEstimatesString();
                writeData(trialNum,nTestTrial, eye, isBlankCatchTrial,isEasyCatchTrial,isRefixationTrial, nStimPlacementFails, isCalibrated, lastKnownViewingDistance_cm, x_rel_deg,y_rel_deg, x_px,y_px, x_rel_px,y_rel_px, d_deg, stimDiameter_deg,stimDiameter_px, targLum_dB, targAbs_cdm2,stimLuminance_norm,  minAcceptableTrialDuration_secs, responseLatency_secs,resp,anscorrect, grid_estimates, trialStartTime_secs,trialEndTime_secs, obs_x_px,obs_y_px, eyeTrackerLogFn, webcamFn,webcam_firstFrameNofCurrentTrial,webcam_lastFrameNofCurrentTrial)
            
                %%%%%%%%%%%%%%%%%%%%%%%% Save video data  %%%%%%%%%%%%%%%%%%%%%%%
                if RECORD_WEBCAM
                    if IN_DEBUG_MODE, tic(); end
                    drawnow();
                    if IN_DEBUG_MODE, fprintf('  > Saving webcam data: Elapsed time is %1.5f seconds\n', toc()); end
                end
            end % end of trials
            
            % save eye tracking data
            IvDataLog.getInstance().save(eyeTrackerLogFn);
            
            % Construct info to tag final plot with
          	timestamp = datestr(now(), 31);
            computerName = sprintf('%s%s', getenv('COMPUTERNAME'), getenv('HOSTNAME'));
            titleStr = sprintf('%s / %s  / %s / %s / %s', computerName, metaParams.cfgID, any2str(metaParams.partID), any2str(metaParams.partInfo.dob), timestamp);
            fn = sprintf('ECL_%s_%s.png', any2str(metaParams.partID), datestr(now(), 30));
            outputDir = '../../data/__OUT_RESULTIMAGES';
            fullFn = fullfile(RESULTIMAGES_DIR, fn);

            % print final summary of results to console
            fprintf('\n\n\n-------------------------------\nFINAL RESULTS:\n-------------------------------\n\n');
            PsychoController.printSummary();
            if runTimeParams.doPlot
                hFig = PsychoController.plotResults(titleStr, fullFn);
                close(hFig);
            end
            
            if IN_SIMULATION_MODE
                fprintf('\n\n\n-------------------------------\nSIMULATION TRUE THRESHOLDS:\n-------------------------------\n\n');
                disp(round(sim_thresh_mu))
            end
            
            
        %%%%%%%%
        %% 14 %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Finish up %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % that's it! close open windows and release memory
            Screen('LoadNormalizedGammaTable', winhandle, masterGammaTable);
            IvMain.finishUp();
            if RECORD_WEBCAM
                delete(vobj);
                clear vobj;
            end
            
        catch ME
            warning on
            try
                % attempt to restore previous gamma table
                Screen('LoadNormalizedGammaTable', winhandle, masterGammaTable);
            catch
                warning('Failed to restore masterGammaTable');
            end
            IvMain.finishUp();
            if RECORD_WEBCAM
                try
                    delete(vobj);
                    clear vobj;
                catch ME1
                    warning(ME1.message);
                end
            end
            rethrow(ME);
    end 

    fprintf('All done, thanks for playing. nCorrect = %i\n', nCorrect);
    
    % wait for results plot to be closed before continuing
%     if paradigm.idleAtEndUntilResultsFigClosed
%         fprintf('< Close results figure-window to continue... >');
%         waitfor(hResultsFig);
%         fprintf('\n\n');
%     end
end