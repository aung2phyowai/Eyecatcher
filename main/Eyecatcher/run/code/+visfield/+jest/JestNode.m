classdef JestNode < handle
	% ########.
    %
    % Public JestNode Methods:
    %   none (all access via Zest.m)
    %
  	% Public Static Methods:
    %   * runTests  	- Run basic test-suite to ensure functionality.
    %
    % See Also:
    %   Jest.m
    %
    % Example:
    %   none
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

    properties (GetAccess = public, SetAccess = private)
        % mandatory user-specified parameters
        stimLvl_dB
        rowId  	% i index, in testing grid
        colId  	% j index, in testing grid

        % will terminate if minNHit reached, or if 'minNTrials & minPMiss'
        % reached
       	minNHit           	= 2
      	minNTrials          = 2
       	minPMiss          	= 0.67
        
        % measured variables
        stimLvls_dB         = []  	% vector of stims shown
        responses_wasSeen 	= []	% vector of responses (1 seen, 0 not)
        responseTimes_ms    = []    % vector of response times
    end

    
 	%% ====================================================================
    %  -----PUBLIC METHODS (but only generally be accessed from Zest.m)----
    %$ ====================================================================
    
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = JestNode(rowId, colId, stimLvl_dB)
            % parse inputs
            obj.rowId       = rowId;
            obj.colId       = colId;
            obj.stimLvl_dB  = stimLvl_dB;
            
            % ensure that stimLvl_dB is scalar
            if length(obj.stimLvl_dB)~=1 || ~isnumeric(obj.stimLvl_dB)
                error('invalid stimLvl_dB');
            end

        end
        
        %% == METHODS =================================================

        function stim_dB = getStimLvl(obj)
            % ensure not finished (defensive)
            if obj.isFinished()
                error('State is finished??')
            end
            
            % get stimulus value
            stim_dB = obj.stimLvl_dB;
        end
 
        function isFin = isFinished(obj)
            % ################################################################################
            % # Return TRUE if JEST should stop, FALSE otherwise
            %
            % # Returns
            % #   TRUE or FALSE
            % ################################################################################

            isFin = ~isnan(obj.getState());
            
        end
        
        function value = getState(obj)
            % ################################################################################
            % # Given a state, return an estimate of threshold
            % #
            % # 1 for seen, 0 for not seen, NaN for undecided
            % ################################################################################
            
            nTrials = length(obj.responses_wasSeen);
            nHits = sum(obj.responses_wasSeen);
            pMiss = sum(obj.responses_wasSeen==0)/nTrials;
            
            if nHits >= obj.minNHit
                value = 1;
                return
            elseif nTrials>=obj.minNTrials && pMiss >= obj.minPMiss
                value = 0;
                return
            end
            
            value = NaN;
        end
    
        function [] = update(obj, presentedStimLvl_dB, stimWasSeen, responseTime_ms)
        
            % ################################################################################
            % # Update state given response.
            % ################################################################################

            % validate (defensive)
            if (presentedStimLvl_dB ~= obj.stimLvl_dB)
                error('????')
            end
            
            % store trial (just gone) record
            obj.stimLvls_dB(end+1)      = presentedStimLvl_dB;
            obj.responses_wasSeen(end+1)= stimWasSeen;
            obj.responseTimes_ms(end+1)	= responseTime_ms;
        end
        
    end

    
   	%% ====================================================================
    %  -----STATIC METHODS (public)-----
    %$ ====================================================================
      
    % little helper functions
    methods (Static, Access = public)

        % visfield.jest.JestNode.runTests()
        function [] = runTests()
            import visfield.jest.*
            
            % create example state object
            js = JestNode(1, 1, 10);

            % check: getCurrentStimLvl
            if js.getStimLvl ~= 10
                error('wrong level??');
            end

            % check: isFinished
            if js.isFinished()
                error('should not be finished??');
            end
            
           	% check: update(), isFinished()
            js = JestNode(1, 1, 10);
            js.update(js.getStimLvl(), true, 400)
            js.update(js.getStimLvl(), true, 400)
            try
                js.update(js.getStimLvl(), true, 400)
            catch ME %#ok
            end
            if ~exist('ME','var')
                error('error should have been thrown??')
            end
            
            % check: update(), getStimLvl(), isFinished()
            js = JestNode(1, 1, 10);
            js.update(js.getStimLvl(), true, 400)
            js.update(js.getStimLvl(), true, 400)
            if ~js.isFinished()
                error('should be finished??');
            end
            if js.getState ~= 1
                error('state should be 1??');
            end
            
            % isFinished(): 1 - 1
            js = JestNode(1, 1, 10);
            js.update(js.getStimLvl(), true, 400)
            js.update(js.getStimLvl(), false, 400)
            if js.isFinished()
                error('should not be finished??');
            end
            
            % isFinished(): 2 - 1
            js = JestNode(1, 1, 10);
            js.update(js.getStimLvl(), true, 400)
            js.update(js.getStimLvl(), false, 400)
            js.update(js.getStimLvl(), true, 400)
            if ~js.isFinished()
                error('should be finished??');
            end
            if js.getState ~= 1
                error('state should be 1??');
            end
            
            % isFinished(): 2 - 2
            js = JestNode(1, 1, 10);
            js.update(js.getStimLvl(), true, 400)
            js.update(js.getStimLvl(), false, 400)
            js.update(js.getStimLvl(), false, 400)
            js.update(js.getStimLvl(), true, 400)
            if ~js.isFinished()
                error('should be finished??');
            end
            if js.getState ~= 1
                error('state should be 1??');
            end
            
            % isFinished(): 1 - 3
            js = JestNode(1, 1, 10);
            js.update(js.getStimLvl(), true, 400)
            js.update(js.getStimLvl(), false, 400)
            js.update(js.getStimLvl(), false, 400)
            js.update(js.getStimLvl(), false, 400)
            if ~js.isFinished()
                error('should be finished??');
            end
            if js.getState ~= 0
                error('state should be 0??');
            end

            % all done
            fprintf('\n\nAll checks ok\n');
        end
    end
  
end