classdef VfAttentionGrabberFace < visfield.graphic.VfAttentionGrabber
	% ########.
    %
    %   http://www.perimetry.org/GEN-INFO/standards/IPS90.HTM
    %
    % VfAttentionGrabberFace Methods:
    %   * VfAttentionGrabberFace  	- Constructor.
    %   * ######        - ######.
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
    %   1.0 PJ 07/2014 : first_build\n
    %
    % @todo truncate
    %
    % Copyright 2014 : P R Jones
    % *********************************************************************
    % 

    %% ====================================================================
    %  -----PROPERTIES-----
    %$ ====================================================================      
    
    properties (Constant)
        GRAPHIC_DIM_MOD = 15;
    end
    
    properties (GetAccess = public, SetAccess = private)
        visual
        sound
        
        ivGraphicStub

        % animation
        startTime_sec
        lastDrawTime_sec
        isStarted = false;

%         sway_cpd = 0;
        sway_speed_cpd = 0.5;
        sway_magnitude_deg = 10; % will oscillator +/- this amount
        sway_phi = 0; % http://stackoverflow.com/questions/22597392/generating-swept-sine-waves;
        sway_deg
        swayoverride_deg;
        
        scaleFactor = 1;
        x_px
        y_px 
    end

        
    %% ====================================================================
    %  -----PUBLIC METHODS-----
    %$ ====================================================================
          
    methods (Access = public)
        
        %% == CONSTRUCTOR =================================================
        
        function obj = VfAttentionGrabberFace(winhandle, IMG_DIR, SND_DIR)
            % VfAttentionGrabberFace Constructor.
            %
            % @param    winhandle 	#####
            % @return   obj   	VfAttentionGrabberFace object
            %
            % @date     11/07/14
            % @author   PRJ
            %

            % ####
            obj.visual = PtrVisual(fullfile(IMG_DIR, 'feedback', '500px-Happy_face.svg.png'), winhandle, .35);
            
            % #####
            obj.ivGraphicStub = ivis.graphic.IvGraphic('target', obj.visual.texture, 0, 0, obj.visual.width*obj.GRAPHIC_DIM_MOD, obj.visual.height*obj.GRAPHIC_DIM_MOD, winhandle); %/2 hack

            % init audio
%             obj.sound = 0.1 * ivis.audio.IvAudio.getInstance().wavload(fullfile(SND_DIR, '173881__toam__xylophon-play-melody-c3-loop.wav')); 
            
            % load audio
            audio = ivis.audio.IvAudio.getInstance();
            fn = fullfile(SND_DIR, '173881__toam__xylophon-play-melody-c3-loop.wav');
            obj.sound = audio.wavload(fn);
            obj.sound = obj.sound(50000:54000);
            %
            testChans = audio.outChans;  	% all channels
            lvlFactor = 0.2;    % attenuate it to some arbitrarily low level to avoid blowing anybody's eardrums
            obj.sound = audio.rampOnOff(audio.padChannels(obj.sound*lvlFactor, testChans, audio.outChans));
            clear audio;
            
        end
        
        %% == METHODS =====================================================
        
        
        function [] = init(obj, x_px, y_px)
            % Get x/y coordinates.
            %
            % @param   x_px   #####
            % @param   y_px   #####
            %
            % @date     11/07/14
            % @author   PRJ
            %

            % set graphic position
            obj.x_px = x_px;
            obj.y_px = y_px;
            obj.ivGraphicStub.reset(x_px, y_px);

        end
         
        function [] = start(obj, playAudio)
            % #######.
            %
            % @date     11/07/14
            % @author   PRJ
            %

            % parse inputs
            if nargin < 2 || isempty(playAudio)
                playAudio = false; % no audio by default
            end
            
            % start audio playing
            if playAudio
                blocking = false;
% beep()                
                ivis.audio.IvAudio.getInstance().play(obj.sound, [], blocking);
            end
            
            % reset timer
            obj.startTime_sec = GetSecs();
            obj.lastDrawTime_sec = obj.startTime_sec;
            
            % set internal flag
            obj.isStarted = true;
        end
        
        function [] = draw(obj, winhandle)
            % Get x/y coordinates.
            %
            % @return   x   #####
            % @return   y   #####
            %
            % @date     11/07/14
            % @author   PRJ
            %
            
            % check
            if ~obj.isStarted
                error('Not started??')
            end
            
            % compute params
            if ~isempty(obj.swayoverride_deg)
                obj.sway_deg = obj.swayoverride_deg;
                obj.swayoverride_deg = [];
            else
                t_secs = GetSecs();
                delta = 2 * pi * obj.sway_speed_cpd * (t_secs-obj.lastDrawTime_sec);
                obj.sway_phi = obj.sway_phi + delta;
                obj.sway_deg = obj.sway_magnitude_deg * sin(obj.sway_phi);
                obj.lastDrawTime_sec = t_secs;
            end
            
            % draw visuals
            dstRect = CenterRectOnPointd(obj.visual.rect*obj.scaleFactor, obj.x_px, obj.y_px);
            Screen('DrawTexture', winhandle, obj.visual.texture, [], dstRect, obj.sway_deg);
        end
        
        function [] = stop(obj)
            % Get x/y coordinates.
            %
            % @return   x   #####
            % @return   y   #####
            %
            % @date     11/07/14
            % @author   PRJ
            %

            % stop audio playing
            ivis.audio.IvAudio.getInstance().stop();
            
            % set internal flag
            obj.isStarted = false;
        end
        
        function [] = setScale(obj, scaleFactor)
            % Resize visual, as proportion of starting size
            %
            % @param    scaleFactor   #####
            %
            % @date     27/03/17
            % @author   PRJ
            %
            obj.scaleFactor = scaleFactor;
        end
        
        function [] = setSwaySpeed(obj, sway_speed_cpd)
            % Resize visual, as proportion of starting size
            %
            % @param    scaleFactor   #####
            %
            % @date     27/03/17
            % @author   PRJ
            %
            obj.sway_speed_cpd = sway_speed_cpd;
        end
        
        function [] = setSway(obj, sway_deg)
            % Resize visual, as proportion of starting size
            %
            % @param    sway_deg   #####
            %
            % @date     27/03/17
            % @author   PRJ
            %
            obj.swayoverride_deg = sway_deg;
        end
        
    end

end