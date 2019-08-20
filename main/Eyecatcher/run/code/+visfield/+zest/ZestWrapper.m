classdef (Abstract) ZestWrapper < handle
    % Generic class for...
    %
    %     #####
    %
    % ZestWrapper Methods:
    %   * xxxx  - xxxx
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
    %   1.0 PJ 03/2017 : first_build\n
    %
    %
    % Copyright 2017 : P R Jones
    % *********************************************************************
    %

    
    %% ====================================================================
    %  -----ABSTRACT PUBLIC METHODS-----
    %$ ====================================================================
    
    methods(Abstract, Access = public)  
        % ######
        %
        % @date     04/03/14
        % @author   PRJ
        %
        [x_deg, y_deg, targDLum_dB, i, j] = getTarget(obj)
        
        % ######
        %
        % @date     04/03/14
        % @author   PRJ
        %
        update(obj, x_deg, y_deg, presentedStimLvl_dB, stimWasSeen, responseTime_ms)
        
        % ######
        %
        % @date     04/03/14
        % @author   PRJ
        %
        varargout = getTotalNPresentations(obj)
        
        % ######
        %
        % @date     04/03/14
        % @author   PRJ
        %
        printSummary(obj)
    end

end