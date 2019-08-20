% RUN! [button mode]
clearAbsAll();
clc;
cfg = 'ecl_v0_0_13';
i = 1;
eye = 0; % 0==left, 1==right 
pid = 99;
manuallySuppressEyetrackerCalib = false;
runTimeParams = struct('eye',eye(i), 'manuallySuppressEyetrackerCalib',manuallySuppressEyetrackerCalib);
% ptr('-run','EyecatcherHome', '-from',cfg, '-pid',pid, '-sid',i, '-autoStart',true, '-skipLoginChecks',true, 'skipWriteCheck',true, 'runTimeParams',runTimeParams)
ptr('-run','EyecatcherHome', '-from',cfg, 'skipWriteCheck',true, 'runTimeParams',runTimeParams)