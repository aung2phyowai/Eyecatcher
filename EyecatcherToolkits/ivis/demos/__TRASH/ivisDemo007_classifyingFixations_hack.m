function [] = ivisDemo007_classifyingFixations()
% ivisDemo007_classifyingFixations. Using a simple hitbox to see if the user is looking at a given object.
%
%   See ivisDemo011_advancedClassifiers.m for more advanced techniques
%
% Requires:        ivis toolbox v1.3
%
% Matlab:          v2015 onwards
%
% See also:        ivisDemo006_trackboxVisualisation.m
%                   ivisDemo008_playingVideos.m
%
% Author(s):    	Pete R Jones <petejonze@gmail.com>
%
% @Current Verion:  1.1.0	PJ  18/10/2013    General tidy up (ivis 1.4).
% Version History: 1.0.0	PJ  23/06/2013    Initial build.
%
% Copyright 2014 : P R Jones
% *********************************************************************
% 

    % Clear memory and set workspace
    clearAbsAll();
    import ivis.classifier.* ivis.control.* ivis.graphic.* ivis.gui.* ivis.main.* ivis.log.*; 
    
    % Initialise toolbox
    params = IvMain.initialise(IvParams.getSimpleConfig('GUI.useGUI',true, 'eyetracker.GUIidx',2, 'classifier.GUIidx',1)); % IvParams.getDefaultConfig());
    [eyetracker, ~, InH, winhandle] = IvMain.launch(params);
    
    % Prepare graphic
%     tex=Screen('MakeTexture', params.graphics.winhandle, ones(100,100,3));
    myGraphic = ivis.graphic.IvGraphic('targ', [], 800, 800, 200, 200); % centre graphic in middle of screen
    
    % Prepare a classifier
%     myClassifier = ivis.classifier.IvClassifierBox(myGraphic);
    myClassifier = IvClassifierLL('2D', {IvPrior(), myGraphic});
    myClassifier.show(); % draw the box around the graphic
    myClassifier.start();
    
    % Main loop (run until decision or user quits)
    while myClassifier.getStatus() == myClassifier.STATUS_UNDECIDED
        % poll peripheral devices for valid user inputs
        InH.getInput();
        % draw graphic
%         myGraphic.draw()
        % poll eyetracker
        eyeTracker.getInstance().refresh();
        myClassifier.update();
        % Pause for short period
        WaitSecs(.01);
    end
    
    % Report whether it was a hit
    anscorrect = strcmpi('targ', myClassifier.interogate().name());
    fprintf('look = %g\n', anscorrect);

    % Finish up
    IvMain.finishUp();
end