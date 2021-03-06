function [] = ivisDemo009_streamingWebcams()
% ivisDemo009_streamingWebcams. Stream a webcam feed into an ivis GUI window.
%
%   Output will be displayed in the GUI
%
% Requires:         ivis toolbox v1.5
%
% Matlab:           v2015 onwards
%
% See also:         ivisDemo008_playingVideos.m
%                   ivisDemo010_readingRawGazeData.m
%
% Author(s):    	Pete R Jones <petejonze@gmail.com>
%
% Version History:  1.0.1	PJ  02/08/2013    Simplified/neatened/updated.
%                   1.0.0	PJ  22/06/2013    Initial build.
%                   1.1.0	PJ  18/10/2013    General tidy up (ivis 1.4).
%
%
% Copyright 2017 : P R Jones <petejonze@gmail.com>
% *********************************************************************
% 

    % check if really want to run
    fprintf('Playing video is currently very buggy and can cause fatal crashes\n');
    answer=input('Do you wish to continue (y or n)? ','s');
    if ~strcmpi(answer,'y')
        fprintf('Demo aborted\n');
        return;
    end
    
    % Clear memory and set workspace
    clearAbsAll();
    import ivis.main.* ivis.control.* ivis.video.*;

    % Verify, initialise, and launch the ivis toolbox
    IvMain.assertVersion(1.5);
    IvMain.initialise(IvParams.getDefaultConfig('webcam.enable', true, 'graphics.runScreenChecks',false));
    [eyetracker, ~, InH, winhandle] = IvMain.launch();
    
    % Main
    try % wrap in try..catch to ensure a graceful exit
        
        % Open video and start playing
        IvVideo.getInstance().open(IvVideo.getInstance().defaultVidFns{2});
        IvVideo.getInstance().play(true);  % true for fullscreen
        
        % Idle until keypress
        fprintf('Press SPACE to exit\n');
        while ~any(InH.getInput() == InH.INPT_SPACE.code)
            Screen('Flip', winhandle); % n.b., requires that ivis.broadcaster.* has been imported
            eyetracker.refresh(false); % false to suppress data logging
            WaitSecs(1/60);
        end

        % Stop video and close the file
        IvVideo.getInstance().close();
    catch ME
        IvMain.finishUp();
        rethrow(ME);
    end

    % That's it! Close windows and release memory
    IvMain.finishUp();
end