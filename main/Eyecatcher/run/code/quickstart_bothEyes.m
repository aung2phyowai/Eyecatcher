
% RUN! [button mode]
clearAbsAll();
clc;
cfg = 'ecl_v0_0_13';
doPlot = false;
pid  = 99;


% 1: Right Eye
sid = 1;
eye = 1; % 0==left, 1==right
manuallySuppressEyetrackerCalib = false;
runTimeParams = struct('eye',eye, 'manuallySuppressEyetrackerCalib',manuallySuppressEyetrackerCalib, 'doPlot',doPlot);
ptr('-run','EyecatcherHome', '-from',cfg, '-pid',pid, '-sid',sid, '-autoStart',true, '-skipLoginChecks',true, 'skipWriteCheck',true, 'runTimeParams',runTimeParams)
% ptr('-run','EyecatcherHome', '-from',cfg, 'skipWriteCheck',true, 'runTimeParams',runTimeParams

% 2: Left Eye
sid = 2;
eye = 0; % 0==left, 1==right 
runTimeParams = struct('eye',eye, 'manuallySuppressEyetrackerCalib',manuallySuppressEyetrackerCalib, 'doPlot',doPlot);
ptr('-run','EyecatcherHome', '-from',cfg, '-pid',pid, '-sid',sid, '-autoStart',true, '-skipLoginChecks',true, 'skipWriteCheck',true, 'runTimeParams',runTimeParams)
