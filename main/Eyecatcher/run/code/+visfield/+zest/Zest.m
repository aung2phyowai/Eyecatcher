classdef Zest < handle
	% 24-2 Zest.
    %
    % # Perform a ZEST procedure at each location in a 24-2 pattern, using
    % # the HFA growth pattern to set the priors at each location. 
    % #
    % # The prior pdf at each location is bimodal, with the guess from the
    % # HFA growth pattern as the mode of the normal part of the pdf, and
    % # the damaged part is fixed. The guess for the primary points is
    % # taken from previous normative data, as detailed in the code.
    %
    % This code is based on the OPI R functions, written by Andrew Turpin &
    % Luke Chong (on 12 Jun 2013).
    %
    % To cite the ZEST method:
    %     Turpin A., McKendrick A.M., Johnson C.A., & Vingrys A.J. (2003) Properties of perimetric threshold estimates from full threshold, ZEST, and SITA-like strategies, as determined by computer simulation. IOVS, 44(11), 4787-4795.
    %     Turpin A., McKendrick A.M., Johnson C.A., & Vingrys A.J. (2002) Development of Efficient Threshold Strategies for Frequency Doubling Technology Perimetry Using Computer Simulation. IOVS, 43(2), 322-331.
    %
    % Further reading:
    %     Anderson A.J. (2003) Utility of a dynamic termination criterion in the ZEST adaptive threshold method. Vis. Res., 43, 165-170.
    %     McKendrick A.M. & Turpin A. (2005) Advantages of Terminating Zippy Estimation by Sequential Testing (ZEST) With Dynamic Criteria for White-on-White Perimetry. Optometry and Vis. Sci., 82(11), 981-987.
    %
    % For simplicity the stimulus location grid is built-in, however it
    % would be simple to modify the code to allow the user to pass custom
    % grid parameters into the constructor.
    %
    % Note that in the original, OPI version, the node object itself was
    % passed back to the user. In this version, for simplicity, the node
    % object is kept internal, and the user is just simply queries the Zest
    % master object for the next <x, y, luminance level>. To update, the
    % user then feeds these values back to Zest, along with the user's
    % response.
    %
    % Public Zest Methods:
    %   * Zest          - Constructor.
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
    %   Zest.runTests();
    %
    % Author:
    %   Pete R Jones <petejonze@gmail.com>
    %
    % Verinfo:
    %   1.0 PJ 04/2015 : first_build\n
    %
    % Copyright 2014 : P R Jones
    % *********************************************************************
    % 
    % @TODO:L update as per Jest (rename 'nodes' as 'nodes', move logic
    % from wrapper in Zest itself)

    %% ====================================================================
    %  -----PROPERTIES-----
    %$ ====================================================================      

    properties (GetAccess = public, SetAccess = ?visfield.zest.ZestWrapper) % SetAccess = protected)
        growthPattern
        locations_deg
        
        nPresentations
        thresholds % final thresholds
        
      	currentWave
        
        nodes
        currentNodes
        redonenodes = {};
        
        plotObj
        
        priorThresholds
        
        nFailedPlacementAttempts
    end
    properties (GetAccess = private, SetAccess = protected)
        currentThresholds
    end

    
    %% ====================================================================
    %  -----PUBLIC METHODS-----
    %$ ====================================================================
  
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = Zest(eye, prior, domain, locations_deg, growthPattern, doPlot)
            import visfield.zest.*;
            
            % N.B. if growth-pattern is specified then it must be
            % passed in for the RIGHT eye (will be automatically flipped if
            % a left eye requested)
            
            if nargin < 1 || isempty(eye)
                error('Eye must be specified (0==left, 1===right, 2==both)');
            end
            if nargin < 2 || isempty(prior) || isempty(regexp(class(prior), 'ThresholdPriors$','once')) % ~isa(prior, 'ThresholdPriors') % isa cannot handle package prefixes, e.g., visfield.zest.ThresholdPriors
                error('a ThresholdPriors object is required.\n  %s detected', class(prior));
            end
            if nargin < 3 || isempty(domain) || ~all(isnumeric(domain))
                error('a domain row vector is required');
            end
            if nargin < 4
                obj.locations_deg = [];
            else
                obj.locations_deg = locations_deg;
            end
            if nargin < 5
                obj.growthPattern = [];
                if ~isempty(obj.locations_deg)
                    error('If a custom locations_deg grid has been specified, then a growth pattern must also be specified');
                end
            else
                obj.growthPattern = growthPattern;
            end
            if nargin < 6 || isempty(doPlot)
                doPlot = false;
            end
            
            % check domain is valid
            if (any(domain>54)) || (~all(round(domain)==domain))
                error('domain must be a vector of integers, 0:N, where N < 55');
            end
            
            % defensive: check that prior comes from same eye
            if eye ~= prior.eye
                error('Mismatch between specified ZEST eye (%i) and the eye in the prior normative data (%i)', eye, prior.eye)
            end

            % #####################################################################
            % # 'wave' patterns
            % # Each location derives its start value from the average of all of the
            % # immediate 9 neighbours that are lower than it.
            % # Numbers should start at 1 and increase, not skipping any.
            % ####################################################################
            
            if isempty(obj.growthPattern)
                % default right eye growth pattern
                obj.growthPattern = [
                    NaN, NaN, NaN,  3,  3,  3,  3, NaN, NaN, NaN
                    NaN, NaN,  2,   2,  2,  2,  2,  2,  NaN, NaN
                    NaN,  3,   2,   1,  2,  2,  1,  2,   3,  NaN
                    4,    3,   2,   2,  2,  2,  2, NaN,  3,  NaN
                    4,    3,   2,   2,  2,  2,  2, NaN,  3,  NaN
                    NaN,  3,   2,   1,  2,  2,  1,  2,   3,  NaN
                    NaN, NaN,  2,   2,  2,  2,  2,  2,  NaN, NaN
                    NaN, NaN, NaN,  3,  3,  3,  3, NaN, NaN, NaN
                    ];
            end
        
            % flip growth pattern if left eye specified
            if (eye == 0) % left
                obj.growthPattern = fliplr(obj.growthPattern);
            elseif (eye == 1) % right
                % no action required
            elseif (eye == 2) % binocular
				% no action required
			else
                error('Eye code not recognized: %i\nSupport eye codes are 0 (left eye) and 1 (right eye) and 2 (binocular)', eye);
            end

            % locations, in degrees visual angle
            if isempty(obj.locations_deg)
                % default locations pattern (eye invariant)
                obj.locations_deg  = cat(3, ones(8,1) * (-27:6:27), (21:-6:-21)' * ones(1,10));
                % obj.locations_deg(:,:,1) =
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %    -27   -21   -15    -9    -3     3     9    15    21    27
                %
                % obj.locations_deg(:,:,2) =
                %    
                %     21    21    21    21    21    21    21    21    21    21
                %     15    15    15    15    15    15    15    15    15    15
                %      9     9     9     9     9     9     9     9     9     9
                %      3     3     3     3     3     3     3     3     3     3
                %     -3    -3    -3    -3    -3    -3    -3    -3    -3    -3
                %     -9    -9    -9    -9    -9    -9    -9    -9    -9    -9
                %    -15   -15   -15   -15   -15   -15   -15   -15   -15   -15
                %    -21   -21   -21   -21   -21   -21   -21   -21   -21   -21
            end
                 
            % validate
            if ~all(size(obj.locations_deg(:,:,1)) == size(obj.growthPattern))
                error('mismatch');
            end
            
            % #####################################################################
            % # set priors for first wave
            % ####################################################################

            % get priors for all locations
            obj.priorThresholds = nan(size(obj.growthPattern));
            for i = 1:size(obj.growthPattern,1)
                for j = 1:size(obj.growthPattern,2)
                    x_deg = obj.locations_deg(i, j, 1);
                    y_deg = obj.locations_deg(i, j, 2);
                    DLS_dB = prior.getThreshold(x_deg, y_deg); % get Differential Light Sensitivity, in dB
                    obj.priorThresholds(i, j) = DLS_dB;
                end
            end
            % flip priorThresholds if left eye specified
            if (eye == 0) % left
                obj.priorThresholds = fliplr(obj.priorThresholds);
            end
            obj.priorThresholds(isnan(obj.growthPattern)) = NaN; % blank out untested points
            
            % initialise thresholds
            obj.thresholds = nan(size(obj.growthPattern));
            obj.currentThresholds = nan(size(obj.growthPattern));
            
            % initialise nFailedPlacementAttempts
            obj.nFailedPlacementAttempts = zeros(size(obj.growthPattern));
            obj.nFailedPlacementAttempts(isnan(obj.growthPattern)) = NaN;
            
            % make starting guesses for the "1" locations,  based on prior
            % normative data
            idx = obj.growthPattern==1;
            obj.currentThresholds(idx) = obj.priorThresholds(idx);
            % obj.currentThresholds = [
            %     NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
            %     NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
            %     NaN, NaN, NaN, p11, NaN, NaN, p12, NaN, NaN, NaN
            %     NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
            %     NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
            %     NaN, NaN, NaN, p21, NaN, NaN, p22, NaN, NaN, NaN
            %     NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
            %     NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
            % ];

            % initialise answers
            obj.nPresentations 	= nan(size(obj.currentThresholds));
            obj.currentWave    	= 1;
            
            % create a 'node' object at each testable location on the
            % grid. Note that each of these will need to be explicitly
            % .initialise()'d with a starting guess before they can be used
            obj.nodes = cell(size(obj.currentThresholds));
            for i = 1:size(obj.growthPattern,1)
                for j = 1:size(obj.growthPattern,2)
                    if ~isnan(obj.growthPattern(i,j))
                        obj.nodes{i,j} = ZestNode(i, j, domain, 'stdev', 1.5);
                    end
                end
            end
            
            % fill the 'currentNodes' buffer with all the nodes
            % corresponding to wave 1
            obj.currentNodes = [obj.nodes{obj.growthPattern==1}];
            
            % create a visual plot, if requsted by user
            if doPlot
                obj.plotObj = ZestPlot(obj.locations_deg, ~isnan(obj.growthPattern));
            end
        end
        
        %% == METHODS =================================================

        function [x_deg, y_deg, targDLum_dB, i, j] = getTarget(obj)
            % get node
            node = obj.getNode();
            % derive test parameters
            i = node.rowId;
            j = node.colId;
            x_deg = obj.locations_deg(i, j, 1);
            y_deg = obj.locations_deg(i, j, 2);
            targDLum_dB = node.getCurrentStimLvl('mean');
        end
        
        function T = update(obj, x_deg, y_deg, presentedStimLvl_dB, stimWasSeen, responseTime_ms)
            % get node
            idx = obj.locations_deg(:,:,1)==x_deg & obj.locations_deg(:,:,2)==y_deg;
            node = obj.nodes{idx};
            
            % update this node
            T = node.update(presentedStimLvl_dB, stimWasSeen, responseTime_ms);
            
            % update nodes list (if this node is finished)
            if node.isFinished()
                % store threshold estimate
                obj.currentThresholds(node.rowId, node.colId) = node.getFinalThresholdEst(); % specify method?????
                obj.nPresentations(node.rowId, node.colId) = node.nPresentations;
                obj.thresholds(node.rowId, node.colId) = obj.currentThresholds(node.rowId, node.colId);
                
                % remove this node from node list
                obj.currentNodes(obj.currentNodes==node) = [];
            
                % if node list now depleted...
                if isempty(obj.currentNodes)
                    %...increment wave counter...
                    obj.currentWave = obj.currentWave + 1;
                    
                    %...& if wave still within limits, grab some new nodes
                    if obj.currentWave <= max(obj.growthPattern(:))
                        obj.currentNodes = [obj.nodes{obj.growthPattern==obj.currentWave}];
                    end
                end
            end
            
            % update any graphics
            if ~isempty(obj.plotObj)
                obj.plotObj.update(obj.thresholds);
            end
        end
        
        
        % new! (from Jest)
        function [n, nFullMatrix] = registerPlacementFailure(obj, x_deg, y_deg)
            % get node
            idx = obj.locations_deg(:,:,1)==x_deg & obj.locations_deg(:,:,2)==y_deg;
            % increment counter
            obj.nFailedPlacementAttempts(idx) = obj.nFailedPlacementAttempts(idx) + 1;
            n = obj.nFailedPlacementAttempts(idx);
            nFullMatrix = obj.nFailedPlacementAttempts;
        end
        
        % new! (from Jest)
        function [] = abortPoint(obj, x_deg, y_deg)
            % get node
            idx = obj.locations_deg(:,:,1)==x_deg & obj.locations_deg(:,:,2)==y_deg;
            node = obj.nodes{idx};
            
            % store threshold estimate
            obj.thresholds(node.rowId, node.colId) = NaN;
            
            % remove this node from node list
            obj.currentNodes(obj.currentNodes==node) = [];
        end
        
        function isFin = isFinished(obj)
            % return true iff no more nodes left unfinished, and we have
            % reached the last wave
            if isempty(obj.currentNodes) && (obj.currentWave >= max(obj.growthPattern(:)))
                isFin = true;
            else
                isFin = false;
            end
        end

    end
        
        
    
    %% ====================================================================
    %  -----PRIVATE METHODS-----
    %$ ====================================================================
  
    methods (Access = private)
        
        function dB = makeGuess(obj, rw, cl)
       	% use available info to guess the observer's threshold for a given
        % location. After the first wave, this is computed by averaging all
        % immediate 9 neighbours that have num less than "wave"
            % ####################################################################
            % # INPUTS
            % #   rw   - row of location
            % #   cl   - column of location
            % #
            % # RETURNS: start guess for location (rw, cl) which is average of
            % #          neighbours that are less than "wave" in "gp"
            % ####################################################################

            % check valid
            if obj.growthPattern(rw, cl) ~= obj.currentWave
                error('Attempting to select a node with a wave number (%i) different from the current wave number (%i)', obj.growthPattern(rw, cl), obj.currentWave); 
            end
                  
            % in wave 1, simply use the prior as the starting guess
            if (obj.currentWave == 1)
                dB = obj.currentThresholds(rw, cl);
                return;
            end
            
            % get values
            iidx = max(rw-1,1):min(rw+1,size(obj.growthPattern,1));
            jidx = max(cl-1,1):min(cl+1,size(obj.growthPattern,2));
            vals = obj.currentThresholds(iidx, jidx);

            % find values from lower wave (and check not nan - defensive
            % check, since shouldn't be possible anyway)
            %idx = obj.growthPattern(iidx, jidx) < obj.currentWave ...
            %    & ~isnan(vals);
            % Also allow current wave to contribute:
            idx = obj.growthPattern(iidx, jidx) <= obj.currentWave ...
                & ~isnan(vals);
            
            % defensive check that at least 1 value found
            if ~any(idx)
                disp(obj.growthPattern)
                disp(obj.currentThresholds)
                obj.growthPattern(iidx, jidx)
                warning('Could not find neighbour for {%i, %i}. Will rely solely on normative data', rw, cl)
                dB = obj.priorThresholds(rw, cl);
            else
                % compute mean of earlier empirical value(s)
                tmp = vals(idx);
                dB = mean(tmp(:));
                
                % Also, use generic prior information to further inform
                % starting guess
                wPriorGuess = 1/obj.currentWave; % amount of weight given to prior evidence (weights sum to 1. 0==total reliance on current empirical data. 1=total reliance on prior normative data)
                dB = (1-wPriorGuess)*dB + wPriorGuess*obj.priorThresholds(rw, cl);
            end
            
fprintf('Zest.m makeGuess() says: initialising at level: %1.2f\n', dB);            
        end
        
        function node = getNode(obj)
            % Get a node object directly (should not be required - use
            % getTarget() instead).
            
            % defensive
            if obj.isFinished()
                error('Cannot select a node - Zest algorithm has finished');
            end
            
            % pick a random node from the list
            idx = randi(length(obj.currentNodes));
            node = obj.currentNodes(idx);
            
            % initialise node, if necessary (i.e., if a new node, not
            % previously tested)
            if ~node.isInitialised
                startingGuess = obj.makeGuess(node.rowId, node.colId);
                node.initialise(startingGuess)
            elseif node.isFinished() % defensive
                error('A finished node was selected??');
            end
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
            
            % Try running a uniform grid ----------------------------------
            % initialise grid
            prior = ThresholdPriors(0, 10000/pi, false);
            Z = Zest(0, prior, 0:30);
            % run loop
            while ~Z.isFinished()
                % pick a node
                [x_deg, y_deg, targDLum_dB] = Z.getTarget();
                fprintf('wave=%i, {%i, %i}\n', Z.currentWave, x_deg, y_deg);
                % test the point
                anscorrect = targDLum_dB < 25; % based on a uniform threshold
                % update the node, given observer's response
                Z.update(x_deg, y_deg, targDLum_dB, anscorrect, 400);
            end
            % report summary
            Z.thresholds
            fprintf('Total n stimulus presentations: %i\n', sum(Z.nPresentations(~isnan(Z.nPresentations))));
            
            % Try running a non-uniform grid ------------------------------
            % initialise grid
            prior = ThresholdPriors(1, 155, false);
            Z = Zest(1, prior, 0:30);
            % initialise observer parameters
            trueThresh = [
                NaN, NaN, NaN,  15,  15,  12,  9,  NaN,  NaN,  NaN
                NaN, NaN,  15,  14,  15,  15,  14,  13,  NaN,  NaN
                NaN,  14,  17,  20,  18,  20,  20,  17,   12,  NaN
                10,   12,  18,  20,  19,  20,  19, NaN,   12,  NaN
                11,   16,  18,  18,  17,  20,  17, NaN,   11,  NaN
                NaN,  14,  17,  20,  18,  20,  20,  15,   12,  NaN
                NaN, NaN,  15,  16,  14,  15,  17,  13,  NaN,  NaN
                NaN, NaN, NaN,  9,   11,  9,   7,  NaN,  NaN,  NaN
           	];
            % run loop
            while ~Z.isFinished()
               	% pick a node
                [x_deg, y_deg, targDLum_dB,  i, j] = Z.getTarget();
                fprintf('wave=%i, {%i, %i}\n', Z.currentWave, x_deg, y_deg);
                % defensive check
                [ii,jj] = find(Z.locations_deg(:,:,1)==x_deg & Z.locations_deg(:,:,2)==y_deg);
                if (ii~=i) || (jj~=j)
                    error('row/column validation failed?? (i=%i, ii=%i;  j=%i, jj=%i)',i,ii,j,jj);
                end
                % test the point
                anscorrect = targDLum_dB < trueThresh(i, j); % based on above matrix
                % update the node, given observer's response
                Z.update(x_deg, y_deg, targDLum_dB, anscorrect, 400);
            end
            % report summary
            fprintf('\nTrue Thresholds:\n');
            disp(trueThresh)
            fprintf('Estimated Thresholds:\n');
            disp(Z.thresholds)
            fprintf('Total n stimulus presentations: %i\n', sum(Z.nPresentations(~isnan(Z.nPresentations))));
            
            % Try running a non-uniform grid with internal variability ----
            % initialise grid
            prior = ThresholdPriors(1, 155, false);
            Z = Zest(1, prior, 0:30);
            % initialise observer parameters
            trueThresh = [
                NaN, NaN, NaN,  15,  15,  12,  9,  NaN,  NaN,  NaN
                NaN, NaN,  15,  14,  15,  15,  14,  13,  NaN,  NaN
                NaN,  14,  17,  20,  18,  20,  20,  17,   12,  NaN
                10,   12,  18,  20,  19,  20,  19, NaN,   12,  NaN
                11,   16,  18,  18,  17,  20,  17, NaN,   11,  NaN
                NaN,  14,  17,  20,  18,  20,  20,  15,   12,  NaN
                NaN, NaN,  15,  16,  14,  15,  17,  13,  NaN,  NaN
                NaN, NaN, NaN,  9,   11,  9,   7,  NaN,  NaN,  NaN
           	];
            inoise = 3; % std/slope of psychometric function, in dB
            % run loop
            while ~Z.isFinished()
               	% pick a node
                [x_deg, y_deg, targDLum_dB, i, j] = Z.getTarget();
                fprintf('wave=%i, {%i, %i}\n', Z.currentWave, x_deg, y_deg);
                % test the point
                anscorrect = (targDLum_dB+randn()*inoise) < trueThresh(i, j); % based on above matrix
                % update the node, given observer's response
                Z.update(x_deg, y_deg, targDLum_dB, anscorrect, 400);
            end
            % report summary
            fprintf('\nTrue Thresholds:\n');
            disp(trueThresh)
            fprintf('Estimated Thresholds:\n');
            disp(Z.thresholds)
            fprintf('Total n stimulus presentations: %i\n', sum(Z.nPresentations(~isnan(Z.nPresentations))));
            
            % all done
            fprintf('\n\nAll checks ok\n');
        end
    end
  
end