classdef Jest < handle
	% Suprathreshold test
    %
    % Public Zest Methods:
    %   * Jest          - Constructor.
    %   * getTarget  	- Get x, y, luminance values for next presentation.
    %   * update        - Update a given state, specifying what the user's response was.
    %   * isFinished	- Returns True if Zest algorithm complete.
    %
    % Public Static Methods:
    %   * runTests  	- Run basic test-suite to ensure functionality.
    %
    % See Also:
    %   JestNode.m
    %
    % Example:
    %   Jest.runTests();
    %
    % Author:
    %   Pete R Jones <petejonze@gmail.com>
    %
    % Verinfo:
    %   1.0 PJ 04/2017 : first_build\n
    %
    % Copyright 2017 : P R Jones
    % *********************************************************************
    % 

    %% ====================================================================
    %  -----PROPERTIES-----
    %$ ====================================================================      

    properties (GetAccess = public, SetAccess = ?visfield.jest.JestWrapper) % SetAccess = protected)
        growthPattern
        locations_deg
        stimLvl_dB

      	currentWave
        
        nodes
        currentNodes
        redoneNodes = {};
        
        estimates
        
        nTimesToChecksForOutliers = 1;
        outlierCheckCount = 0;
        
        nFailedPlacementAttempts
    end

    
    %% ====================================================================
    %  -----PUBLIC METHODS-----
    %$ ====================================================================
  
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = Jest(eye, stimLvl_dB, locations_deg, growthPattern, nTimesToChecksForOutliers)
            import visfield.jest.*;
            
            % N.B. if growth-pattern is specified then it must be
            % passed in for the RIGHT eye (will be automatically flipped if
            % a left eye requested)
            
            if nargin < 1 || isempty(eye)
                error('Eye must be specified (0==left, 1===right, 2==both)');
            end
            if nargin < 2 || isempty(stimLvl_dB)
                error('a stimLvl_dB value is required');
            end
            if nargin < 3
                obj.locations_deg = [];
            else
                obj.locations_deg = locations_deg;
            end
            if nargin < 4
                obj.growthPattern = [];
                if ~isempty(obj.locations_deg)
                    error('If a custom locations_deg grid has been specified, then a growth pattern must also be specified');
                end
            else
                obj.growthPattern = growthPattern;
            end
            if nargin >= 5 && ~isempty(nTimesToChecksForOutliers)
                obj.nTimesToChecksForOutliers = nTimesToChecksForOutliers;
            end

            % locations, in degrees visual angle
            if isempty(obj.locations_deg)
                error('test locations pattern must be specified manually');
%                 % default locations pattern (eye invariant)
%                 obj.locations_deg  = cat(3, ones(8,1) * (-27:6:27), (21:-6:-21)' * ones(1,10));
%                 % obj.locations_deg(:,:,1) =
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %    -27   -21   -15    -9    -3     3     9    15    21    27
%                 %
%                 % obj.locations_deg(:,:,2) =
%                 %    
%                 %     21    21    21    21    21    21    21    21    21    21
%                 %     15    15    15    15    15    15    15    15    15    15
%                 %      9     9     9     9     9     9     9     9     9     9
%                 %      3     3     3     3     3     3     3     3     3     3
%                 %     -3    -3    -3    -3    -3    -3    -3    -3    -3    -3
%                 %     -9    -9    -9    -9    -9    -9    -9    -9    -9    -9
%                 %    -15   -15   -15   -15   -15   -15   -15   -15   -15   -15
%                 %    -21   -21   -21   -21   -21   -21   -21   -21   -21   -21
            end
            
            % check stimLvl_dB is valid
            %if length(stimLvl_dB) ~= 1 || ~isnumeric(stimLvl_dB) || stimLvl_dB>55 || stimLvl_dB<0 
            %    error('stimLvl_dB must be a numeric value 0 <= x <= 55');
            %end
            if ~all(isnumeric(stimLvl_dB)) || (size(stimLvl_dB,1) ~= size(obj.locations_deg,1)) || (size(stimLvl_dB,2) ~= size(obj.locations_deg,2))
                error('stimLvl_dB must be a numeric matrix with the same dimensions as locations_deg');
            end
            if any(stimLvl_dB>55 | stimLvl_dB<0)
                error('stimLvl_dB must be 0 <= x <= 55');
            end
            
            % store
            obj.stimLvl_dB = stimLvl_dB;

            % #####################################################################
            % # 'wave' patterns
            % # Each location derives its start value from the average of all of the
            % # immediate 9 neighbours that are lower than it.
            % # Numbers should start at 1 and increase, not skipping any.
            % ####################################################################
            
            if isempty(obj.growthPattern)
                error('growth pattern must be specified manually');
%                 % default right eye growth pattern
%                 obj.growthPattern = [
%                     NaN, NaN, NaN,  3,  3,  3,  3, NaN, NaN, NaN
%                     NaN, NaN,  2,   2,  2,  2,  2,  2,  NaN, NaN
%                     NaN,  3,   2,   1,  2,  2,  1,  2,   3,  NaN
%                     4,    3,   2,   2,  2,  2,  2, NaN,  3,  NaN
%                     4,    3,   2,   2,  2,  2,  2, NaN,  3,  NaN
%                     NaN,  3,   2,   1,  2,  2,  1,  2,   3,  NaN
%                     NaN, NaN,  2,   2,  2,  2,  2,  2,  NaN, NaN
%                     NaN, NaN, NaN,  3,  3,  3,  3, NaN, NaN, NaN
%                     ];
            end
        
            % flip growth pattern if left eye specified
            if (eye == 0) % left
                obj.growthPattern = fliplr(obj.growthPattern);
            elseif (eye == 1) % right
                % no action required
            elseif (eye == 2) % both
                % no action required
            else
                error('Eye code not recognized: %i\nSupport eye codes are 0 (left eye), 1 (right eye), and 2 (both eyes [uses right eye grid])', eye);
            end

            % validate
            if ~all(size(obj.locations_deg) == [size(obj.growthPattern) 2])
                error('test location matrix dimensions do not match growth pattern?');
            end

            % initialise answers
            obj.currentWave    	= 1;
            
            % create a 'state' object at each testable location on the
            % grid. Note that each of these will need to be explicitly
            % .initialise()'d with a starting guess before they can be used
            obj.nodes = cell(size(obj.growthPattern));
            for i = 1:size(obj.growthPattern,1)
                for j = 1:size(obj.growthPattern,2)
                    if ~isnan(obj.growthPattern(i,j))
                        obj.nodes{i,j} = JestNode(i, j, obj.stimLvl_dB(i,j));
                    end
                end
            end
            
            % fill the 'currentNodes' buffer with all the nodes
            % corresponding to wave 1
            obj.currentNodes = [obj.nodes{obj.growthPattern==1}];
            
            % initialise estimates of thresholds/states
            obj.estimates = nan(size(obj.growthPattern));
            
            % initialise nFailedPlacementAttempts
            obj.nFailedPlacementAttempts = zeros(size(obj.growthPattern));
            obj.nFailedPlacementAttempts(isnan(obj.growthPattern)) = NaN;
        end
        
        %% == METHODS =================================================

        function [x_deg, y_deg, targDLS_dB, idx] = getTarget(obj)
            % get state
            state = obj.getNode();
            % derive test parameters
            x_deg = obj.locations_deg(state.rowId, state.colId, 1);
            y_deg = obj.locations_deg(state.rowId, state.colId, 2);
            targDLS_dB = state.getStimLvl;
            idx = obj.locations_deg(:,:,1)==x_deg & obj.locations_deg(:,:,2)==y_deg;
        end
        
        function [] = update(obj, x_deg, y_deg, presentedStimLvl_dB, stimWasSeen, responseTime_ms)
            % get state
            idx = obj.locations_deg(:,:,1)==x_deg & obj.locations_deg(:,:,2)==y_deg;
            state = obj.nodes{idx};
            
            % update this state
            state.update(presentedStimLvl_dB, stimWasSeen, responseTime_ms);
            
            % update nodes list (if this state is finished)
            if state.isFinished()
                
                % store threshold estimate
                obj.estimates(state.rowId, state.colId) = state.getState();
                
                % remove this state from state list
                obj.currentNodes(obj.currentNodes==state) = [];
            
                % if state list now depleted...
                if isempty(obj.currentNodes)
                    %...increment wave counter...
                    obj.currentWave = obj.currentWave + 1;
                    
                    %...& if wave still within limits, grab some new nodes
                    if obj.currentWave <= max(obj.growthPattern(:))
                        obj.currentNodes = [obj.nodes{obj.growthPattern==obj.currentWave}];
                    end
                end
            end

        end
        
        % new!
        function [n, nFullMatrix] = registerPlacementFailure(obj, x_deg, y_deg)
            % get state
            idx = obj.locations_deg(:,:,1)==x_deg & obj.locations_deg(:,:,2)==y_deg;
            % increment counter
            obj.nFailedPlacementAttempts(idx) = obj.nFailedPlacementAttempts(idx) + 1;
            n = obj.nFailedPlacementAttempts(idx);
            nFullMatrix = obj.nFailedPlacementAttempts;
        end
        
        % new!
        function [] = abortPoint(obj, x_deg, y_deg)
            % get state
            idx = obj.locations_deg(:,:,1)==x_deg & obj.locations_deg(:,:,2)==y_deg;
            state = obj.nodes{idx};
            
            % store threshold estimate
            obj.estimates(state.rowId, state.colId) = NaN;
            
            % remove this state from state list
            obj.currentNodes(obj.currentNodes==state) = [];
        end
        
        function isFin = isFinished(obj)
            % return true iff no more nodes left unfinished, and we have
            % reached the last wave
            isFin = false;
            if isempty(obj.currentNodes)   &&   (obj.currentWave >= max(obj.growthPattern(:)))
                if obj.outlierCheckCount < obj.nTimesToChecksForOutliers
                    obj.checkForOutliers();
                    isFin = obj.isFinished();
                else
                    isFin = true;
                end
            end
        end
        
        function [nPresentations, nHits, nMiss, meanRespTime_ms, nPresentationsTotal] = getStats(obj)
            % init
            nPresentations 	= zeros(size(obj.growthPattern));
            nHits           = nan(size(obj.growthPattern));
            nMiss           = nan(size(obj.growthPattern));
            meanRespTime_ms = nan(size(obj.growthPattern));
            
            % fill in grid of test values
            for i = 1:size(obj.nodes,1)
                for j = 1:size(obj.nodes,2)
                    node = obj.nodes{i,j};
                    if ~isempty(node)
                        nPresentations(i,j) = length(node.stimLvls_dB);
                        nHits(i,j)          = sum(node.responses_wasSeen);
                        nMiss(i,j)          = sum(~node.responses_wasSeen);
                        idx = node.responses_wasSeen==1;
                        meanRespTime_ms(i,j)= mean(node.responseTimes_ms(idx));
                    end
                end
            end
            
            % validate
            tmp = (nHits+nMiss) == nPresentations | isnan(nHits+nMiss);
            if ~all(tmp(:))
                error('internal computation error??')
            end
            
            % add data for discarded/redone points
            nPresentationsTotal = nansum(nPresentations(:));
            for i = 1:length(obj.redoneNodes)
                nPresentationsTotal = nPresentationsTotal + length(obj.redoneNodes{i}.stimLvls_dB);
            end
        end

        function [] = printSummary(obj)
            fprintf('Estimated Thresholds:\n');
            disp(obj.estimates)
            
            [nPresentations, nHits, nMiss, meanRespTime_ms, nPresentationsTotal] = obj.getStats();
            fprintf('Total n stimulus presentations:        %i\n', nansum(nPresentations(:)));
            fprintf('Total n hits:                          %i\n', nansum(nHits(:)));
            fprintf('Total n misses:                        %i\n', nansum(nMiss(:)));
            fprintf('Mean response time:                    %i\n', nanmean(meanRespTime_ms(:)));
            fprintf('Total n stumulus presentations TOTAL: 	%i\n', nPresentationsTotal);
        end
        
    end
        
        
    
    %% ====================================================================
    %  -----PRIVATE METHODS-----
    %$ ====================================================================
  
    methods (Access = private)
        
        function node = getNode(obj)
            % Get a state object directly (should not be required - use
            % getTarget() instead).
            
            % defensive
            if obj.isFinished()
                error('Cannot select a state - Jest algorithm has finished');
            end
            
            % pick a random state from the list
            idx = randi(length(obj.currentNodes));
            node = obj.currentNodes(idx);
            
            % defensive
            if node.isFinished() 
                error('A finished node was selected??');
            end
        end
        
        
        function [] = checkForOutliers(obj)
            import visfield.jest.*;
            
            % defensive, ensure that this is only done once
            if obj.outlierCheckCount >= obj.nTimesToChecksForOutliers
                error('Have already checked for outliers sufficient N times?');
            end
            
            % check for outliers
            fprintf('Checking for outliers...\n');
            % any that are zero
            %outliers = (obj.estimates==0);
            % any that are zero, that have at least one adjacent point that
            % is non-zero
            idx      = padarray(0, [1 1], 1); % ALT: = [1 1 1; 1 0 1; 1 1 1];
            outliers = (conv2(single(obj.estimates==1), idx, 'same') .* (obj.estimates==0)) >= 1;
            
            % if any outliers, retest
            if any(outliers(:))
                % display
                disp(obj.estimates)
                disp(outliers)
            
                fprintf('...redoing %i points\n', sum(outliers(:)));
                for i = 1:size(outliers,1)
                    for j = 1:size(outliers,2)
                        if outliers(i,j)==1
                            % store for posterity
                            obj.redoneNodes{end+1} = obj.nodes{i,j};
                            % re-init
                            obj.nodes{i,j} = JestNode(i, j, obj.stimLvl_dB(i,j));
                        end
                    end
                end

                % fill the 'currentStates' buffer with all the states
                % corresponding to wave N
                obj.growthPattern(outliers==1) = obj.currentWave;
                obj.currentNodes = [obj.nodes{obj.growthPattern==obj.currentWave}]; 
                obj.estimates(outliers==1) = NaN;
                
                % register that the check has been performed, to prevent
                % unnecessary repetitions
                obj.outlierCheckCount = obj.outlierCheckCount + 1;
                
            else
                fprintf('...OK\n');
                % force no further checks
                obj.outlierCheckCount = obj.nTimesToChecksForOutliers;
            end
                    
        end

    end
    
    
   	%% ====================================================================
    %  -----STATIC METHODS-----
    %$ ====================================================================
  
    % little helper functions
    methods (Static, Access = public)
        
        % tests: visfield.jest.Jest.runTests()
        function [] = runTests()
            import visfield.jest.*
            
            % Try running a simple grid ----------------------------------
            fprintf('\n\n\n----------------------------\n1\n----------------------------\n');
            % initialise grid
            eye = 0;
            stimLvl_dB = [
                30    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20              
           	];
            growthPattern = [
                 3    NaN   NaN   NaN    3     3    NaN   NaN   NaN    3 
                NaN    3  	NaN    3    NaN   NaN    3    NaN    3    NaN
                NaN   NaN    2    NaN    2     2    NaN    2    NaN   NaN
                NaN    3    NaN    1    NaN   NaN    1    NaN    3    NaN
                 3    NaN    2    NaN   NaN   NaN   NaN    2    NaN    3 
                 3    NaN    2    NaN   NaN   NaN   NaN    2    NaN    3 
                NaN    3    NaN    1    NaN   NaN    1    NaN    3    NaN
                NaN   NaN    2    NaN    2     2    NaN    2    NaN   NaN
                NaN    3    NaN    3    NaN   NaN    3    NaN    3    NaN 
                 3    NaN   NaN   NaN    3     3    NaN   NaN   NaN    3                
           	];
            locations_deg  = cat(3, ones(10,1) * (-9:2:9), (9:-2:-9)' * ones(1,10));
            % create
            J = Jest(eye, stimLvl_dB, locations_deg, growthPattern, 7);
            % run loop
            while ~J.isFinished()
                % pick a state
                [x_deg, y_deg, targDLS_dB] = J.getTarget();
%                 fprintf('wave=%i, {%i, %i}\n', J.currentWave, x_deg, y_deg);
                % test the point
                anscorrect = targDLS_dB < 25; % based on a uniform threshold
                % update the state, given observer's response
                J.update(x_deg, y_deg, targDLS_dB, anscorrect, 400);
            end
            % report summary
            J.estimates
            [nPresentations, nHits, nMiss, meanRespTime_ms, nPresentationsTotal] = J.getStats(); %#ok
            fprintf('Total n stimulus presentations: %i (%i including redone)\n', nansum(nPresentations(:)), nPresentationsTotal);
            J.printSummary();

            % Try running a simple grid with vision loss ------------------
            fprintf('\n\n\n----------------------------\n2\n----------------------------\n');
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
            stimLvl_dB = [
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20
                20    20    20    20    20    20    20    20    20    20              
           	];
            growthPattern = [
                 3    NaN   NaN   NaN    3     3    NaN   NaN   NaN    3 
                NaN    3  	NaN    3    NaN   NaN    3    NaN    3    NaN
                NaN   NaN    2    NaN    2     2    NaN    2    NaN   NaN
                NaN    3    NaN    1    NaN   NaN    1    NaN    3    NaN
                 3    NaN    2    NaN   NaN   NaN   NaN    2    NaN    3 
                 3    NaN    2    NaN   NaN   NaN   NaN    2    NaN    3 
                NaN    3    NaN    1    NaN   NaN    1    NaN    3    NaN
                NaN   NaN    2    NaN    2     2    NaN    2    NaN   NaN
                NaN    3    NaN    3    NaN   NaN    3    NaN    3    NaN 
                 3    NaN   NaN   NaN    3     3    NaN   NaN   NaN    3                
           	];
            locations_deg  = cat(3, ones(10,1) * (-9:2:9), (9:-2:-9)' * ones(1,10));
            nTimesToChecksForOutliers = 1;
            % create
            J = Jest(eye, stimLvl_dB, locations_deg, growthPattern, nTimesToChecksForOutliers);
            % run loop
            while ~J.isFinished()
                % pick a state
                [x_deg, y_deg, targDLS_dB, idx] = J.getTarget();
                fprintf('wave=%i, {%i, %i}\n', J.currentWave, x_deg, y_deg);
                % test the point
                anscorrect = targDLS_dB < normrnd(trueThresh_mu(idx), trueThresh_sd(idx));
                % update the state, given observer's response
                J.update(x_deg, y_deg, targDLS_dB, anscorrect, 400);
            end
            % report summary
            J.estimates
            [nPresentations, nHits, nMiss, meanRespTime_ms, nPresentationsTotal] = J.getStats(); %#ok
            fprintf('Total n stimulus presentations: %i (%i including redone)\n', nansum(nPresentations(:)), nPresentationsTotal);
            J.printSummary();

            % all done
            fprintf('\n\nAll checks ok\n');
        end
    end
  
end