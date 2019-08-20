classdef MyJestWrapperButton < visfield.jest.JestWrapper
	% A wrapper for Jest.m, which adds some custom behaviour
    %
    % Public Jest Methods:
    %   * myJestWrapper - Constructor.
    %   * getTarget  	- Get x, y, luminance values for next presentation.
    %   * update        - Update a given state, specifying what the user's response was.
    %   * isFinished	- Returns True if Jest algorithm complete.
    %
    % Public Static Methods:
    %   * runTests  	- Run basic test-suite to ensure functionality.
    %
    % See Also:
    %   JestState.m
    %
    % Example:
    %   myJestWrapper.runTests();
    %
    % Author:
    %   Pete R Jones <petejonze@gmail.com>
    %
    % Verinfo:
    %   1.0 PJ 04/2015 : first_build\n
    %
    % @todo fix nTimesToChecksForOutliers
    %
    % Copyright 2014 : P R Jones
    % *********************************************************************
    % 

    %% ====================================================================
    %  -----PROPERTIES-----
    %$ ====================================================================      

    properties (GetAccess = public, SetAccess = protected)
        jObj
        falsePositive
        nFalsePositives
        nRefixationCues = 0;
        nRefixationCuesMissed = 0;
    end
    
    

    %% ====================================================================
    %  -----PUBLIC METHODS-----
    %$ ====================================================================
  
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = MyJestWrapperButton(eye, stimLvlOffset_dB, nFalsePositives, delta_max_cdm2)
            import visfield.jest.*;

            % right eye growth pattern (N.B. we will not flip this, since
            % Jest.m expects to get the right-eye format, and will flip it
            % itself if left-eye specified)
            growthPattern = [
               NaN    1    NaN    1    NaN    1     1    NaN
               NaN   NaN    1    NaN   NaN   NaN    1    NaN
               NaN    1    NaN   NaN   NaN   NaN   NaN   NaN
               NaN   NaN   NaN   NaN    1    NaN   NaN   NaN
               NaN    1    NaN   NaN   NaN   NaN    1    NaN
               NaN   NaN   NaN   NaN    1    NaN   NaN   NaN
               NaN   NaN    1    NaN   NaN    1    NaN   NaN
               NaN    1    NaN    1    NaN   NaN    1    NaN          
           	]; % 16 points, including the 11 'most informative' locations (within the testable range) from Henson et al [although the 15/-15 have be shifted to 12/-12!]
            growthPattern = [
               NaN    1     1    NaN   NaN    1     1    NaN
               NaN   NaN    1    NaN   NaN    1    NaN   NaN
               NaN    1    NaN    1     1    NaN    1    NaN
               NaN   NaN    1    NaN   NaN    1    NaN   NaN
               NaN    1    NaN   NaN   NaN   NaN    1    NaN
               NaN   NaN   NaN    1     1    NaN   NaN   NaN
               NaN   NaN    1    NaN   NaN    1    NaN   NaN
               NaN    1     1    NaN   NaN    1     1    NaN          
           	]; % tweaked to make symmetric
            growthPattern = [
               NaN  NaN  NaN  NaN  NaN  NaN  NaN   NaN 
               NaN    1    1    1    1    1    1   NaN
               NaN    1    1    1    1    1    1   NaN
               NaN    1    1    1    1    1    1   NaN
               NaN    1    1    1    1    1    1   NaN
               NaN    1    1    1    1    1    1   NaN
               NaN    1    1    1    1    1    1   NaN
               NaN   NaN  NaN  NaN  NaN  NaN  NaN  NaN          
           	]; % tweaked to make symmetric        
            locations_deg  = cat(3, ones(9,1) * (-21:6:21), (12:-3:-12)' * ones(1,8));
%             locations_deg  = cat(3, ones(9,1) * 2 * (-21:6:21), (12:-3:-12)' * ones(1,8)) %<-- for testing out-of-bound points
            locations_deg(5,:,:) = []; % remove zero-line
            % locations_deg(:,:,1) =
            % 
            %    -21   -15    -9    -3     3     9    15    21
            %    -21   -15    -9    -3     3     9    15    21
            %    -21   -15    -9    -3     3     9    15    21
            %    -21   -15    -9    -3     3     9    15    21
            %    -21   -15    -9    -3     3     9    15    21
            %    -21   -15    -9    -3     3     9    15    21
            %    -21   -15    -9    -3     3     9    15    21
            %    -21   -15    -9    -3     3     9    15    21
            % 
            % 
            % locations_deg(:,:,2) =
            % 
            %     12    12    12    12    12    12    12    12
            %      9     9     9     9     9     9     9     9
            %      6     6     6     6     6     6     6     6
            %      3     3     3     3     3     3     3     3
            %     -3    -3    -3    -3    -3    -3    -3    -3
            %     -6    -6    -6    -6    -6    -6    -6    -6
            %     -9    -9    -9    -9    -9    -9    -9    -9
            %    -12   -12   -12   -12   -12   -12   -12   -12

            % generate values based on HFA priors
            prior = visfield.jest.ThresholdPriors(eye, delta_max_cdm2, false);
            stimLvl_dB = nan(size(growthPattern));
            for i = 1:size(stimLvl_dB,1)
                for j = 1:size(stimLvl_dB,2)
                    stimLvl_dB(i,j) = prior.getThreshold(locations_deg(i,j,1),locations_deg(i,j,2)) + stimLvlOffset_dB;
                end
            end
            % 13.5360   14.7235   15.6866   15.1925   15.1925   15.6866   14.7235   13.5360
            % 14.2851   15.0851   16.4851   16.1851   16.1851   16.4851   15.0851   14.2851
            % 14.9260   15.5358   16.6450   17.0305   17.0305   16.6450   15.5358   14.9260
            % 15.1851   15.9851   16.6851   17.5851   17.5851   16.6851   15.9851   15.1851
            % 15.3851   16.4851   17.1851   17.6851   17.6851   17.1851   16.4851   15.3851
            % 15.4167   15.9757   17.3659   17.3333   17.3333   17.3659   15.9757   15.4167
            % 15.4851   15.3851   17.2851   16.7851   16.7851   17.2851   15.3851   15.4851
            % 15.3076   15.8226   16.1342   16.3555   16.3555   16.1342   15.8226   15.3076

            % !!!!!!
            nTimesToChecksForOutliers = 0;
            
            % create Jest object
            obj.jObj = Jest(eye, stimLvl_dB, locations_deg, growthPattern, nTimesToChecksForOutliers);

            % add some explicit impossible trials
            obj.falsePositive.x_deg     = nan(1, nFalsePositives);
            obj.falsePositive.y_deg  	= nan(1, nFalsePositives);
            obj.falsePositive.stimWasSeen= nan(1, nFalsePositives);
            obj.falsePositive.count     = 0;
            obj.falsePositive.prob      = nFalsePositives/(sum(~isnan(growthPattern(:)))*2.2); % assuming every point observed 2.2 times (crude)
            obj.falsePositive.isfin   	= nFalsePositives==0;
            obj.falsePositive.level   	= Inf;
        end
        
        %% == METHODS =================================================

        function [x_deg, y_deg, targDLum_dB, idx] = getTarget(obj)
            % targDLum_dB is the differential luminance above the
            % background level (e.g., targDLum_dB = 10, means 10 dB greater
            % than background)
            
            % If still required, select an 'impossible' catch trial with random
            % probability, or with certainty if main grid is finished
            if ~obj.falsePositive.isfin && ( (rand()<obj.falsePositive.prob) || obj.jObj.isFinished)
                % pick a random state from the list
                tmp = find(~isnan(obj.jObj.growthPattern));
                idx = tmp(randi(length(tmp)));
                node = obj.jObj.nodes{idx};
                % get values
                x_deg       = obj.jObj.locations_deg(node.rowId, node.colId, 1);
                y_deg       = obj.jObj.locations_deg(node.rowId, node.colId, 2);
                targDLum_dB = obj.falsePositive.level;
                idx         = obj.jObj.locations_deg(:,:,1)==x_deg & obj.jObj.locations_deg(:,:,2)==y_deg;
                return;
            end
            
            % if main grid not finished then pick from it
            if ~obj.jObj.isFinished
                [x_deg, y_deg, targDLum_dB, idx] = obj.jObj.getTarget();
                return
            end
            
            error('Grid complete?')
        end
        
        function [] = update(obj, x_deg, y_deg, presentedStimLvl_dB, stimWasSeen, responseTime_ms)
            if presentedStimLvl_dB==obj.falsePositive.level
                % ...else if if False Positive (blank) catch trial ...
                obj.falsePositive.count = obj.falsePositive.count + 1;
                obj.falsePositive.stimWasSeen(obj.falsePositive.count) = stimWasSeen;
                if obj.falsePositive.count == length(obj.falsePositive.x_deg)
                    obj.falsePositive.prob	= 0;
                    obj.falsePositive.isfin	= true;
                end
                return
            else
                % ... else was a test point
                obj.jObj.update(x_deg, y_deg, presentedStimLvl_dB, stimWasSeen, responseTime_ms);
            end
        end
        
        % new!
        function n = registerPlacementFailure(obj, x_deg, y_deg)
            n = obj.jObj.registerPlacementFailure(x_deg, y_deg);
        end
        
        % new!
        function [] = abortPoint(obj, x_deg, y_deg)
            obj.jObj.abortPoint(x_deg, y_deg);
        end

        function [] = registerRefixationCue(obj, stimWasSeen)   
            obj.nRefixationCues = obj.nRefixationCues + 1;
            obj.nRefixationCuesMissed = obj.nRefixationCuesMissed + (1-stimWasSeen);
        end
        
        function isFin = isFinished(obj)
            isFin = obj.jObj.isFinished() & obj.falsePositive.isfin;
        end

        function [] = printSummary(obj)
            fprintf('\n\n===================================================================\n');
            fprintf('Estimated Thresholds:\n');
            disp(obj.jObj.estimates)
            
            % catch trial data
            nCatchFalsePos = obj.falsePositive.count;
            fprintf('Total n false-pos catch trials: 	%i\n', obj.falsePositive.count);
            fprintf('False-positive rate:              	%i\n\n', sum(obj.falsePositive.stimWasSeen)/obj.falsePositive.count);
            
            % refixation trial data
            fprintf('Total n refixation trials:         %i\n', obj.nRefixationCues);
            fprintf('False-negative rate:              	%i\n\n', obj.nRefixationCuesMissed/obj.nRefixationCues);
            
            
            % get test trial data
            [nPresentations, nHits, nMiss, meanRespTime_ms, nPresentationsTotal] = obj.jObj.getStats();
            fprintf('Total n stimulus presentations:  	%i (incl %i redone)\n', nPresentationsTotal, nPresentationsTotal-nansum(nPresentations(:)));
            fprintf('Total n hits:                    	%i\n', nansum(nHits(:)));
            fprintf('Total n misses:                  	%i\n', nansum(nMiss(:)));
            fprintf('Mean response time:                %i\n\n', nanmean(meanRespTime_ms(:)));
            
            % all
            fprintf('                                 ---------\n');
            fprintf('Total n trials:                 	%i\n', nPresentationsTotal+nCatchFalsePos+obj.nRefixationCues);
            fprintf('                                 ---------\n');
            fprintf('===================================================================\n\n');
        end

        function str = getEstimatesString(obj)
            str = strtrim(num2str(obj.jObj.estimates(:)', '%i ')); % remove trailing space
        end
        
        
        function hFig = plotResults(obj, titleStr, fullFn)
            
            % validate
            if ~obj.isFinished()
                error('Not finished yet');
            end
            
            % key params
            heatmap_N_interp = 75;
            
            % get data
            x_deg = obj.jObj.locations_deg(:,:,1);
            y_deg = obj.jObj.locations_deg(:,:,2);
            estimates = obj.jObj.estimates;
            
            % reshape
            x_deg = x_deg(:);
            y_deg = y_deg(:);
            estimates = estimates(:);

            % fit surface
            xnodes = linspace(min(x_deg)-2, max(x_deg)+2, heatmap_N_interp); % heatmap_N_interp);
            ynodes = linspace(min(y_deg)-2, max(y_deg)+2, heatmap_N_interp); %  heatmap_N_interp);
            [zgrid,xgrid,ygrid] = gridfit(x_deg, y_deg, estimates, xnodes, ynodes, 'interp','nearest', 'regularizer','spring', 'smoothness',0.1, 'overlap',.1);
            zgrid = smooth2a(zgrid,4,4);
            
            % open figure window
            hFig = figure();
            
            % set text interpreter to LaTeX
            set(0,'defaulttextInterpreter','latex');
            
            % make custom colormap (red to green)
            R = linspace(1,0,50); % logspace(log10(1),log10(0.1),50); %
            G = linspace(0,1,50);
            B = linspace(0,0,50);
            cmap = [R', G', B'];
            colormap(cmap);
            
            % plot data
            hSurf = surf(xgrid,ygrid,zgrid,'edgecolor',[0 0 0],'facecolor','interp');
            set(hSurf,'facealpha',0.4, 'edgealpha',0.5,'linestyle','none')
            set(gca, 'View',[0 90]);
            
            % add colorbar
            hCB = colorbar();
            set(hCB, 'Limits',[0 1]);
            caxis([0 1]); % ensure always shows full range
            
            % plot numbers
            zlim([0 1]); % required for numbers to appear
            hold on
            for i = 1:length(estimates)
                if ~isnan(estimates(i))
                    if estimates(i)==round(estimates(i))
                        txt = sprintf(' %i', estimates(i));
                    else
                        txt = sprintf(' %1.1f', estimates(i));
                    end
                    text(x_deg(i),y_deg(i),1.1,txt, 'HorizontalAlignment','center', 'VerticalAlignment','middle', 'FontSize',9, 'color',[.1 .1 .1]);
                end
            end
            
            % add crosshair
            plot3(xlim(),[0 0], [1 1]*min(zlim()),'k-');
            plot3([0 0], ylim(), [1 1]*min(zlim()),'k-');
            
            % measure volume (see volumetric.m)
            % NB: should technically convert to steradians, as areas
            % "cannot be represented perfectly without distortion of any
            % two-dimensional projection of a curved surface.... The
            % graphied visual field... is an azimuthal map projection of
            % the inner surface of the perimetry bowl. This means that
            % distances and directions from the center of the graph are
            % correctly represeted but area, circumferential distances, and
            % directional relationship other than from the center are not
            % correctly represented."
            % - Weleber & Tobler, 1986 (American Journal of Ophthalmology
            %   Volume 101, Issue 4, April 1986, Pages 461–468
            % However, as shown in Table III of the above, the distortion
            % is relatively minor within the central 30-degrees.
            idx = ~isnan(estimates);
            v = scatterquad2(x_deg(idx), y_deg(idx), estimates(idx));
            % result, v, is in deg-cubed
            txt = sprintf('$%1.2f deg^3$', v);
            textLoc(txt, 'NorthEast');

            % add title
            title(titleStr);
            
            % save (if requested)
            if ~isempty(fullFn)
                if exist(fullFn, 'file')
                    set(hFig, 'name', 'Filed to save');
                    error('Jest plot failed to save: A file called "%s" already exists', fullFn)
                end
                set(hFig, 'name', fullFn);
                set(hFig,'Units','Inches');
                pos = get(hFig,'Position');
                set(hFig,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
                fprintf('Saving figure: %s\n', fullFn)
                %print(hFig, fullFn, '-dpdf', '-r0') % .pdf
                saveas(hFig,fullFn,'png'); % .png
                fprintf(' ..done!\n\n');
            end
        end
        
    end
    

   	%% ====================================================================
    %  -----STATIC METHODS-----
    %$ ====================================================================
  
    % little helper functions
    methods (Static, Access = public)
               
        % tests: MyJestWrapper.runTests()
        function [] = runTests()
            import visfield.jest.*
            
            % Try running a simple grid with vision loss ------------------
            fprintf('\n\n\n----------------------------\n1\n----------------------------\n');
            % simulate observer
            trueThresh_mu = [
                 5    NaN   NaN   NaN    20     20    NaN   NaN   NaN    20 
                NaN     1  	NaN    20    NaN   NaN    20    NaN    20    NaN
                NaN   NaN    20    NaN    20     20    NaN    20    NaN   NaN
                NaN     3    NaN    20    NaN   NaN    20    NaN    20    NaN
                 3     NaN    20    NaN   NaN   NaN   NaN    20    NaN    20 
                 20    NaN    20    NaN   NaN   NaN   NaN    20    NaN    20 
                NaN    20    NaN    20    NaN   NaN    20    NaN    20    NaN
                NaN   NaN    20    NaN    20     20    NaN    20    NaN   NaN
                NaN    20    NaN    20    NaN   NaN    20    NaN    20    NaN 
                 20    NaN   NaN   NaN    20     20    NaN   NaN   NaN    20   
           	];
            trueThresh_sd = [
                 3    NaN   NaN   NaN    3     3    NaN   NaN   NaN    3 
                NaN    3  	NaN    3    NaN   NaN    3    NaN    3    NaN
                NaN   NaN    3    NaN    3     3    NaN    3    NaN   NaN
                NaN    3    NaN    3    NaN   NaN    3    NaN    3    NaN
                 3    NaN    3    NaN   NaN   NaN   NaN    3    NaN    3 
                 3    NaN    3    NaN   NaN   NaN   NaN    3    NaN    3 
                NaN    3    NaN    3    NaN   NaN    3    NaN    3    NaN
                NaN   NaN    3    NaN    3     3    NaN    3    NaN   NaN
                NaN    3    NaN    3    NaN   NaN    3    NaN    3    NaN 
                 3    NaN   NaN   NaN    3     3    NaN   NaN   NaN    3   
           	];
            % initialise grid
            eye = 0;
            stimLvl_dB = 15;
            J = MyJestWrapper(eye, stimLvl_dB, 5);
            % run loop
            while ~J.isFinished()
                % pick a state
                [x_deg, y_deg, targDLS_dB, idx] = J.getTarget();
                %fprintf('wave=%i, {%i, %i}\n', J.jObj.currentWave, x_deg, y_deg);
                % test the point
                anscorrect = targDLS_dB < normrnd(trueThresh_mu(idx), trueThresh_sd(idx));
                % update the state, given observer's response
                J.update(x_deg, y_deg, targDLS_dB, anscorrect, 400);
            end
            % report summary
            J.printSummary();
            
            % test plotting
            J.plotResults('Test Plot', []);
        end
        
    end
  
end