classdef (Sealed) IvFixedPoint < ivis.eyetracker.IvDataInput
    % Singleton instantiation of IvDataInput, designed to always return
    % center of screen (or a user specified value?)
    %
    %   long_description
    %
    % IvTobiiEyeX Methods:
    %   * connect	- Establish a link to the eyetracking hardware.
    %   * reconnect	- Disconnect and re-establish link to eyetracker.
    %   * refresh  	- Query the eyetracker for new data; process and store.
    %   * flush   	- Query the eyetracker for new data; discard.
    %   * validate  - Validate initialisation parameters.
    %
    % IvTobiiEyeX Static Methods:
    %   * readRawLog    - Parse data stored in a .raw binary file (hardware-brand specific format).
    %
    % See Also:
    %   none
    %
    % Example:
    %   none
    %
    % Author:
    %   Pete R Jones <petejonze@gmail.com>
    %
    % Verinfo:
    %   1.0 PJ 07/2018 : first_build\n
    %
    % Copyright 2018 : P R Jones
    % *********************************************************************
    %
    
    
    %% ====================================================================
    %  -----PROPERTIES-----
    %$ ====================================================================
    
    properties (Constant)
        NAME = 'IvMouse';
        RAWLOG_PRECISION = 'single'; % 'double'
        RAWLOG_NCOLS = 3 % 2 + CPUtime
        RAWLOG_HEADERS = {'x','y','CPUtime'};  
        PREFERRED_VIEWING_DISTANCE_MM = 500;
        TRACKBOX_SIZE_MM = 300;  
    end
    
    properties (GetAccess = private, SetAccess = private)
        % other internal parameters
        oldSecs
        windowPtrOrScreenNumber = [];
        fixedX_px
        fixedY_px
        fixedDistance_mm = 600;
    end
    
    
    
    %% ====================================================================
    %  -----PUBLIC METHODS-----
    %$ ====================================================================
    
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = IvFixedPoint()
            % IvFixedPoint Constructor.
            %
            % @return   IvFixedPoint
            %
            % @date     05/07/18
            % @author   PRJ
            %
            
            % set timer
            obj.Fs = 120;
            obj.resetClock();
            
            % set screen centre
            winhandle = ivis.main.IvParams.getInstance().graphics.testScreenNum;
            [obj.fixedX_px, obj.fixedY_px] = RectCenter(Screen('Rect', winhandle));
        end
        
        function delete(obj) %#ok<INUSD>
            % IvFixedPoint Destructor.
            %
            % @date     05/07/18
            % @author   PRJ
            %
        end
        
        %% == METHODS =====================================================
        
        function [] = connect(obj) % interface implementation
        end
        
        function [] = reconnect(obj) % interface implementation
        end
        
        
        function [n, saccadeOnTime, blinkTime] = refresh(obj, logData) % interface implementation
            if nargin < 2 || isempty(logData)
                % init
                logData = true; % may want to set false to suppress data logging
            end
            
            % init
            saccadeOnTime = [];
            blinkTime = [];
            
            % ala IvSimulator
            n = floor(obj.getSecsElapsed()*obj.Fs); % Fs*t
            if n > 0
                % generate timestamps (linearly spaced from last refresh
                % time)
                t = obj.oldSecs + (1:n)'./obj.Fs;
                obj.resetClock();
                
                % generate data (linearly space from last position)
                x = repmat(obj.fixedX_px,n,1);
                y = repmat(obj.fixedY_px,n,1);
                
                % dummy vals
                vldty = ones(size(x));
                pd = ones(size(x));
                zL_mm = zeros(size(x));
                zR_mm = zeros(size(x));

                %-----------Send Data to Buffer------------------------------
                % send the data to an internal buffer which handles filtering
                % and feature extraction, and then passes the data along to the
                % central DataLog and any relevant GUI elements
                [saccadeOnTime, blinkTime] = obj.processData(x,y,t,vldty,pd, zL_mm,zR_mm, logData);
                
                % log data if requested in launch params (and not countermanded
                % by user's refresh call)
                if logData
                    obj.RAWLOG.write([x y t], obj.RAWLOG_PRECISION);
                end
            end
        end
        
        function n = flush(obj) %  interface implementation
            n = floor(obj.getSecsElapsed()*obj.Fs); % Fs*t
            obj.resetClock();
        end
        
        % tmp hack:
        function [lastKnownViewingDistance_mm, t] = getLastKnownViewingDistance(obj)
            lastKnownViewingDistance_mm = obj.fixedDistance_mm;
            t = obj.oldSecs;
        end
        
        function [] = setLastKnownViewingDistance(obj, x_mm)
            obj.fixedDistance_mm = x_mm;
        end
        
    end
    
    
    %% ====================================================================
    %  -----PRIVATE METHODS-----
    %$ ====================================================================
    
    methods (Access = private)
        
        function secsElapsed = getSecsElapsed(obj)
            % ######### blaaaah.
            %
            % @return   secsElapsed
            %
            % @date     05/07/18
            % @author   PRJ
            %
            newSecs = GetSecs();
            secsElapsed = newSecs - obj.oldSecs;
        end
        
        function [] = resetClock(obj)
            % ######### blaaaah.
            %
            % @date     05/07/18
            % @author   PRJ
            %
            obj.oldSecs = GetSecs();
        end
    end
    

    %% ====================================================================
    %  -----PROTECTED STATIC METHODS-----
    %$ ====================================================================    
    
    methods (Static, Access = protected)
        
        function [] = validate(varargin) % interface implementation
            % ######### blaaaah.
            %
            % @param    varargin
            %
            % @date     05/07/18
            % @author   PRJ
            %    
            
        end
    end
    
    
    %% ====================================================================
    %  -----STATIC METHODS (public)-----
    %$ ====================================================================
    
    methods (Static, Access = public)

        function [structure, xy, CPUtime, headers] = readRawLog(fullFn)
            % ######### blaaaah.
            %
            % @param    fullFn
            % @return   structure
            % @return   xy
            % @return   CPUtime
            % @return   headers
            %
            % @date     05/07/18
            % @author   PRJ
            %
            
            % get data matrix
            data = ivis.log.IvRawLog.read(fullFn, ivis.eyetracker.IvFixedPoint.RAWLOG_PRECISION, ivis.eyetracker.IvFixedPoint.RAWLOG_NCOLS);
            
            % parse data in submatrices
            xy = data(:, 1:2);
            CPUtime = data(:, 3);

            % parse data into structure
            headers = ivis.eyetracker.IvFixedPoint.RAWLOG_HEADERS;
            structure = cell2struct(num2cell(data, 1), headers, 2);   
        end  
    end
    
end