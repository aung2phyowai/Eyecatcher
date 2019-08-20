classdef myZestWrapper < visfield.zest.ZestWrapper
	% A wrapper for Zest.m, which adds some custom behaviour
    %
    % Public Zest Methods:
    %   * myZestWrapper - Constructor.
    %   * getTarget  	- Get x, y, luminance values for next presentation.
    %   * update        - Update a given node, specifying what the user's response was.
    %   * isFinished	- Returns True if Zest algorithm complete.
    %
    % Public Static Methods:
    %   * runTests  	- Run basic test-suite to ensure functionality.
    %
    % See Also:
    %   ZestNode.m
    %
    % Example:
    %   myZestWrapper.runTests();
    %
    % Author:
    %   Pete R Jones <petejonze@gmail.com>
    %
    % Verinfo:
    %   1.0 PJ 04/2015 : first_build\n
    %   1.1 PJ 02/2019 : modified for use in EyecatcherHome (made consistent with 'Jest')\n
    %
    % Copyright 2014 : P R Jones
    % *********************************************************************
    % 

    %% ====================================================================
    %  -----PROPERTIES-----
    %$ ====================================================================      

    properties (GetAccess = public, SetAccess = protected)
        zObj
        customLocations_deg
        thresholds
        
        % blind spot nodes
        bs_upObj % upper edge of blind spot
        bs_loObj % true blind spot
        %
        bsX_deg = 15; % (flipped if using left eye)
        bs_upY_deg = 3;
        bs_loY_deg = -3;
        bs_lo_ij
        bs_up_ij
        %
        falsePositive
        falseNegative
        
        % graphcis
        plotObj
        
        trueThresh
    end
    properties (GetAccess = private, SetAccess = protected)
        haveCheckedForOutliers = false;
        domain;
    end
    
    

    
    %% ====================================================================
    %  -----PUBLIC METHODS-----
    %$ ====================================================================
  
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = myZestWrapper(eye, maxLum_cdm2, domain, doPlot, nFalsePositives, nFalseNegatives)
            import visfield.zest.*;
% note that maxLum_cdm2 is the max *Differential* light sensitivity, on top
% of any background pedestal (?)
            
            if nargin < 1 || isempty(eye)
                error('Eye must be specified (0==left, 1===right, 2==both)');
            end
            if nargin < 4 || isempty(doPlot)
                doPlot = false;
            end
            if nargin < 5 || isempty(nFalsePositives)
                nFalsePositives = 10;
            end
            if nargin < 6 || isempty(nFalseNegatives)
                nFalseNegatives = 10;
            end

            % generate a prior object (normative threshold values)
            prior = ThresholdPriors(eye, maxLum_cdm2, false);
            
            % right eye growth pattern (N.B. we will not flip this, since
            % Zest.m expects to get the right-eye format, and will flip it
            % itself if left-eye specified)
%             customGrowthPattern = [
%                 NaN, NaN,  2,   2,  2,  2,  2,  2,  NaN, NaN
%                 NaN,  3,   2,   1,  2,  2,  1,  2,   3,  NaN
%                 4,    3,   2,   2,  2,  2,  2, NaN,  3,  NaN
%                 4,    3,   2,   2,  2,  2,  2, NaN,  3,  NaN
%                 NaN,  3,   2,   1,  2,  2,  1,  2,   3,  NaN
%                 NaN, NaN,  2,   2,  2,  2,  2,  2,  NaN, NaN
%            	];
            % only those points that fit inside the HP screen
            % x_cm = [34.5 19.4]
            % y_deg = rad2deg(2*atan(x_cm/(viewingDist_cm*2)))
            % y_deg/2
            % +/-19.0344   +/-10.9790
            if eye==0 || eye==1
                customGrowthPattern = [
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
                    NaN, NaN,  2,   2,   2,   2,   2,   2,  NaN, NaN
                    NaN, NaN,  2,   1,   2,   2,   1,  NaN, NaN, NaN
                    NaN, NaN,  2,   1,   2,   2,   1,  NaN, NaN, NaN
                    NaN, NaN,  2,   2,   2,   2,   2,   2,  NaN, NaN
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
                    ];
            elseif eye==2
                customGrowthPattern = [
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
                    NaN, NaN,  2,   2,   2,   2,   2,   2,  NaN, NaN
                    NaN, NaN,  2,   1,   2,   2,   1,   2,  NaN, NaN
                    NaN, NaN,  2,   1,   2,   2,   1,   2,  NaN, NaN
                    NaN, NaN,  2,   2,   2,   2,   2,   2,  NaN, NaN
                    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
                    ];
            else
                error('?????');
            end
			
            % create locations
            % x =
            % -27   -21   -15    -9    -3     3     9    15    21    27
            % -27   -21   -15    -9    -3     3     9    15    21    27
            % -27   -21   -15    -9    -3     3     9    15    21    27
            % -27   -21   -15    -9    -3     3     9    15    21    27
            % -27   -21   -15    -9    -3     3     9    15    21    27
            % -27   -21   -15    -9    -3     3     9    15    21    27
            % y =
            % 15    15    15    15    15    15    15    15    15    15
            % 9     9     9     9     9     9     9     9     9     9
            % 3     3     3     3     3     3     3     3     3     3
            % -3    -3    -3    -3    -3    -3    -3    -3    -3    -3
            % -9    -9    -9    -9    -9    -9    -9    -9    -9    -9
            % -15   -15   -15   -15   -15   -15   -15   -15   -15   -15
            obj.customLocations_deg  = cat(3, ones(6,1) * (-27:6:27), (15:-6:-15)' * ones(1,10));
            
            % create Zest object
            obj.zObj = Zest(eye, prior, domain, obj.customLocations_deg, customGrowthPattern, false); % plot supressed in Zest itself, regardless
   
            % create custom blindspot nodes
            if eye==0 % left
                obj.bsX_deg = -obj.bsX_deg;
            end
            if eye==2
                warning('tmp hack for lille');
                obj.bsX_deg = 27;
                obj.bs_upY_deg = 15;
                obj.bs_loY_deg = 9;
            end
            % lower
          	i = find(obj.customLocations_deg(:,1,2)==obj.bs_loY_deg);
            j = find(obj.customLocations_deg(1,:,1)==obj.bsX_deg);
            % if running binocularly disable the blindspot
           	obj.bs_loObj = ZestNode(i, j, [-5:(domain(1)-1) domain]); % ensure domain goes at least as low as -5
            obj.bs_loObj.initialise(0);
            % upper
            i = find(obj.customLocations_deg(:,1,2)==obj.bs_upY_deg);
            j = find(obj.customLocations_deg(1,:,1)==obj.bsX_deg);
            obj.bs_upObj = ZestNode(i, j, domain);
            DLS_dB = prior.getThreshold(9, 9);% N.B. using 9,9 as a rough/arbitrary hack, since the normative values at the upper edge of the blindspot are likely to be an underestimate
            obj.bs_upObj.initialise(DLS_dB);

            % if running binocularly disable the blindspot
            if eye==2
                obj.bs_loObj.forceFin();
                obj.bs_upObj.forceFin();
            end
            
            % init final thresholds matrix
            obj.thresholds = nan(size(customGrowthPattern));
            
         	% create a visual plot, if requsted by user
            if doPlot
                obj.plotObj = ZestPlot(obj.customLocations_deg, ~isnan(obj.zObj.growthPattern)); % N.B. obj.zObj.growthPattern, unlike customGrowthPattern, will be flipped if eye==0
            end
            
            % add some explicit blank/easy trials
            obj.falsePositive.x_deg     = nan(1, nFalsePositives);
            obj.falsePositive.y_deg  	= nan(1, nFalsePositives);
            obj.falsePositive.stimWasSeen= nan(1, nFalsePositives);
            obj.falsePositive.count     = 0;
            obj.falsePositive.prob      = nFalsePositives/110; % assuming about 110 trials total (crude, based on piloting)
            obj.falsePositive.isfin   	= nFalsePositives==0;
            obj.falsePositive.level   	= -Inf;
            
            obj.falseNegative.x_deg     = nan(1, nFalseNegatives);
            obj.falseNegative.y_deg     = nan(1, nFalseNegatives);
            obj.falseNegative.stimWasSeen= nan(1, nFalseNegatives);
            obj.falseNegative.count     = 0;
            obj.falseNegative.prob      = nFalseNegatives/110; % assuming about 110 trials total (crude)
            obj.falseNegative.isfin   	= nFalseNegatives==0;
            obj.falseNegative.level   	= Inf;
            
            % store domain, in case need to reinit nodes later
            obj.domain = domain;
        end
        
        %% == METHODS =================================================

        function [x_deg, y_deg, targDLum_dB, i, j] = getTarget(obj)
            % targDLum_dB is the differential luminance above the
            % background level (e.g., targDLum_dB = 10, means 10 dB greater
            % than background)
            
            % If still required, select an 'impossible' catch trial with random
            % probability, or with certainty if main grid is finished
            if ~obj.falsePositive.isfin && ( (rand()<obj.falsePositive.prob) || obj.zObj.isFinished)
                % pick a random node from the list
                tmp = find(~isnan(obj.zObj.growthPattern));
                idx = tmp(randi(length(tmp)));
                node = obj.zObj.nodes{idx};
                i = node.rowId;
                j = node.colId;
                x_deg = obj.zObj.locations_deg(i, j, 1);
                y_deg = obj.zObj.locations_deg(i, j, 2);
                % set level
                targDLum_dB = obj.falsePositive.level;
                return;
            end
            
            if ~obj.falseNegative.isfin && ( (rand()<obj.falseNegative.prob) || obj.zObj.isFinished)
                % pick a random node from the list
                tmp = find(~isnan(obj.zObj.growthPattern));
                idx = tmp(randi(length(tmp)));
                node = obj.zObj.nodes{idx};
                i = node.rowId;
                j = node.colId;
                x_deg = obj.zObj.locations_deg(i, j, 1);
                y_deg = obj.zObj.locations_deg(i, j, 2);
                % set level
                targDLum_dB = obj.falseNegative.level;
                return;
            end

            % if main grid not finished then pick from here either:
            %   (a) with 95% probability
            %   (b) with 100% probability if blind-spot testing complete
            if ~obj.zObj.isFinished && ((rand()<0.95) || (obj.bs_upObj.isFinished() && obj.bs_loObj.isFinished()))
                [x_deg, y_deg, targDLum_dB, i, j] = obj.zObj.getTarget();
                return
            end
            
            % if not selecting from the main grid, pick the upper of the 2
            % blind-spot locations, either:
            %   (a) with 50% probability
            %   (b) with 100% probability if lower blind-spot testing complete
            if ~obj.bs_upObj.isFinished() && ((rand()<0.50) || obj.bs_loObj.isFinished())
                x_deg = obj.bsX_deg;
                y_deg = obj.bs_upY_deg;
                targDLum_dB = obj.bs_upObj.getCurrentStimLvl('mean');
                i = obj.bs_upObj.rowId;
                j = obj.bs_upObj.colId;
                return
            end
            
            % pick the lower blind spot if reached this point
            x_deg = obj.bsX_deg;
            y_deg = obj.bs_loY_deg;
            targDLum_dB = obj.bs_loObj.getCurrentStimLvl('mean');
            i = obj.bs_loObj.rowId;
            j = obj.bs_loObj.colId;
        end
        
        function [] = update(obj, x_deg, y_deg, presentedStimLvl_dB, stimWasSeen, responseTime_ms)
            if x_deg==obj.bsX_deg && ismember(y_deg,[obj.bs_upY_deg obj.bs_loY_deg])
                % If was a blindspot...
                if y_deg==obj.bs_upY_deg                    
                    T = obj.bs_upObj.update(presentedStimLvl_dB, stimWasSeen, responseTime_ms);
                elseif y_deg==obj.bs_loY_deg                     
                    T = obj.bs_loObj.update(presentedStimLvl_dB, stimWasSeen, responseTime_ms);
                else % defensive
                    error('????');
                end
            elseif presentedStimLvl_dB==obj.falseNegative.level
                % ...else if if False Negative (easy) catch trial ...
                obj.falseNegative.count = obj.falseNegative.count + 1;
                obj.falseNegative.stimWasSeen(obj.falseNegative.count) = stimWasSeen;
                if obj.falseNegative.count == length(obj.falseNegative.x_deg)
                    obj.falseNegative.prob	= 0;
                    obj.falseNegative.isfin	= true;
                end                
                return
            elseif presentedStimLvl_dB==obj.falsePositive.level
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
                T = obj.zObj.update(x_deg, y_deg, presentedStimLvl_dB, stimWasSeen, responseTime_ms);
            end

            % if that terminated the node, update final thresholds, and
            % also update any plot accordingly
            if ~isnan(T)
                i = obj.customLocations_deg(:,1,2)==y_deg;
                j = obj.customLocations_deg(1,:,1)==x_deg;
                obj.thresholds(i,j) = T;
                if ~isempty(obj.plotObj)
                    obj.plotObj.update(obj.thresholds);
                end
            end
        end
        
        % new! (from myJestWrapper)
        function n = registerPlacementFailure(obj, x_deg, y_deg)
            n = obj.zObj.registerPlacementFailure(x_deg, y_deg);
        end
        
        % new! (from myJestWrapper)
        function [] = abortPoint(obj, x_deg, y_deg)
            obj.zObj.abortPoint(x_deg, y_deg);
        end

        function isFin = isFinished(obj)
            isFin = obj.zObj.isFinished() & obj.bs_loObj.isFinished() & obj.bs_upObj.isFinished() & obj.falseNegative.isfin & obj.falsePositive.isfin;
            if isFin
                if ~obj.haveCheckedForOutliers
                    obj.checkForOutliers();
                    isFin = obj.zObj.isFinished() & obj.bs_loObj.isFinished();
                end
            end
        end

        function [N, nTest, nBlindspotUpper, nBlindspotLower, nCatchFalsePos, nCatchFalseNeg] = getTotalNPresentations(obj)
            nTest           = sum(obj.zObj.nPresentations(~isnan(obj.zObj.nPresentations)));
            nBlindspotUpper = obj.bs_upObj.nPresentations;
            nBlindspotLower = obj.bs_loObj.nPresentations;
            nCatchFalsePos  = obj.falsePositive.count;
            nCatchFalseNeg  = obj.falseNegative.count;
            N = nTest + nBlindspotUpper + nBlindspotLower + nCatchFalsePos + nCatchFalseNeg;
        end
        
        function [] = printSummary(obj)
           	fprintf('Estimated Thresholds:\n');
            disp(obj.thresholds)
            
            fprintf('Mean Threshold:                    %1.2f\n', nanmean(obj.thresholds(:)));
            meanExclBlind = (nansum(obj.thresholds(:)) - sum(obj.bs_loObj.getFinalThresholdEst() + obj.bs_upObj.getFinalThresholdEst())) / (sum(~isnan(obj.thresholds(:)))-2);
            fprintf('Mean Threshold (excl blindspot):   %1.2f\n\n', meanExclBlind);
            
            fprintf('Estimated Upper blind spot: %1.2f\n', obj.bs_upObj.getFinalThresholdEst());
            fprintf('Estimated Lower blind spot: %1.2f\n\n', obj.bs_loObj.getFinalThresholdEst());
            
            [N, nTest, nBlindspotUpper, nBlindspotLower, nCatchFalsePos, nCatchFalseNeg] = obj.getTotalNPresentations();
            fprintf('Total n stimulus presentations:        %i\n', nTest);
            fprintf('Total n blindspot trial presentations: %i\n', nBlindspotUpper+nBlindspotLower);
            fprintf('Total n catch trial presentations:     %i\n', nCatchFalsePos+nCatchFalseNeg);
            fprintf('Total trial presentations TOTAL:       %i\n', N);
        end
        
        function str = getEstimatesString(obj)
            str = strtrim(num2str(obj.zObj.thresholds(:)', '%i ')); % remove trailing space
        end
        
        
        function hFig = plotResults(obj, titleStr, fullFn)
            
            % validate
            if ~obj.isFinished()
                error('Not finished yet');
            end
            
            % key params
            heatmap_N_interp = 75;
            
            % get data
            x_deg = obj.zObj.locations_deg(:,:,1);
            y_deg = obj.zObj.locations_deg(:,:,2);
            estimates = obj.zObj.thresholds;
            
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
                    error('Zest plot failed to save: A file called "%s" already exists', fullFn)
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
    %  -----PRIVATE METHODS-----
    %$ ====================================================================
  
    methods (Access = private)
        
        function [] = checkForOutliers(obj)  
            import visfield.zest.*;
            
            % defensive, ensure that this is only done once
            if obj.haveCheckedForOutliers
                error('Have already checked for outliers?');
            end
            
            fprintf('Checking for outliers...\n');
            disp(obj.thresholds);
            
            % compute zscores, in terms of deviation from deviation from
            % norms (i.e., even if points are very different from norms,
            % this is fine, as long as they are consistently so)
            DLS_diffFromNorm = obj.thresholds - obj.zObj.priorThresholds;
           	X = DLS_diffFromNorm(~isnan(DLS_diffFromNorm));
           	z = (DLS_diffFromNorm-mean(X))/std(X); % compute zscores
        
            % redo any point that is more than 2 zscores out
            outliers = abs(z)>2 %#ok abs - can be higher or lower
            if any(outliers(:))
                fprintf('...redoing %i points\n', sum(outliers(:)));
                for i = 1:size(outliers,1)
                    for j = 1:size(outliers,2)
                        obj.zObj.nodes{i,j} = ZestNode(i, j, obj.domain, 'stdev', 1.5);
                    end
                end
                
                % fill the 'currentNodes' buffer with all the nodes
                % corresponding to wave N
                obj.zObj.growthPattern(outliers==1) = obj.zObj.currentWave;
                obj.zObj.currentNodes = [obj.zObj.nodes{obj.zObj.growthPattern==obj.zObj.currentWave}]; 
                obj.thresholds(outliers==1) = NaN;
            else
                fprintf('...OK\n');
            end
            
            
            % redo lower (true) blindspot if greater than or equal to an
            % arbitrary value of 6 dB
            if obj.bs_loObj.nPresentations>0 % HACK: if not disabled
                if obj.bs_loObj.getFinalThresholdEst() >= 6
                    i = find(obj.customLocations_deg(:,1,2)==obj.bs_loY_deg);
                    j = find(obj.customLocations_deg(1,:,1)==obj.bsX_deg);
                    obj.bs_loObj = ZestNode(i, j, [-5:(obj.domain(1)-1) obj.domain]); % ensure domain goes at least as low as -5
                    obj.bs_loObj.initialise(0);
                    obj.thresholds(i,j) = NaN;
                    fprintf('...redoing lower blindspot\n');
                end
            end
            
            % redo upper (boundary) blindspot if more than two Z-scores
            % away from surrounding points (not including the true
            % blindspot point)
            if obj.bs_upObj.nPresentations>0 % HACK: if not disabled
                i = find(obj.customLocations_deg(:,1,2)==obj.bs_upY_deg);
                j = find(obj.customLocations_deg(1,:,1)==obj.bsX_deg);
                vals = obj.thresholds((i-1):(i+1), (j-1):(j+1));
                vals(2:3,2) = NaN; % exclude this point, and the true blindspot just below it
                bs_up_z = (obj.bs_upObj.getFinalThresholdEst()-mean(vals(~isnan(vals))))/std(X); % pseudo-zscore: use mean of surrounding points, but standard deviation across all points
                if abs(bs_up_z) > 2
                    obj.bs_upObj = ZestNode(i, j, obj.domain);
                    obj.bs_upObj.initialise(mean(vals(~isnan(vals)))); % initialise using surrounding values
                    obj.thresholds(i,j) = NaN;
                    fprintf('...redoing upper blindspot\n');
                end
            end
                    
            % register that the check has been performed, to prevent
            % repetitions
            obj.haveCheckedForOutliers = true;
        end
        
    end
    

   	%% ====================================================================
    %  -----STATIC METHODS-----
    %$ ====================================================================
  
    % little helper functions
    methods (Static, Access = public)
        
        % tests
        function [] = runTests()
            import visfield.zest.*
            
            % Try running a non-uniform grid with internal variability ----
            % initialise grid
            Z = myZestWrapper(1, 155, 0:1:30);
            % initialise observer parameters
            Z.trueThresh = [
                NaN, NaN,  15,  14,  15,  15,  14,  13,  NaN,  NaN
                NaN,  14,  17,  20,  18,  20,  20,  17,   12,  NaN
                10,   12,  18,  20,  19,  20,  19,  15,   12,  NaN
                11,   13,  18,  18,  17,  20,  17,   0,   11,  NaN
                NaN,  14,  17,  20,  18,  20,  20,  15,   12,  NaN
                NaN, NaN,  11,  10,  10,  10,  12,  13,  NaN,  NaN
           	];
            inoise = 3; % std/slope of psychometric function, in dB
            % run loop
            while ~Z.isFinished()
               	% pick a node
                [x_deg, y_deg, targDLum_dB, i, j] = Z.getTarget();
                fprintf('wave=%i, {%i, %i}\n', Z.zObj.currentWave, x_deg, y_deg);
                % defensive check
                [ii,jj] = find(Z.zObj.locations_deg(:,:,1)==x_deg & Z.zObj.locations_deg(:,:,2)==y_deg);
                if (ii~=i) || (jj~=j)
                    error('row/column validation failed?? (i=%i, ii=%i;  j=%i, jj=%i)',i,ii,j,jj);
                end
                % test the point
                anscorrect = (targDLum_dB+randn()*inoise) < Z.trueThresh(i, j); % based on above matrix
                % update the node, given observer's response
                Z.update(x_deg, y_deg, targDLum_dB, anscorrect, 400);
            end
            % report summary
            fprintf('\nTrue Thresholds:\n');
            disp(Z.trueThresh)
            Z.printSummary();
        end
    end
  
end