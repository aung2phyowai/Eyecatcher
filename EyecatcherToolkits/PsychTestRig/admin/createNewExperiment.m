function createNewExperiment(varargin)
%CREATENEWEXPERIMENT shortdescr.
%
% Description
%
% Example: none
%
% See also
% 
% @Author: Pete R Jones
% @Date: 22/01/10#

% To do: sort out fileseps ??????

    %----------------------------------------------------------------------
    % Parse & validate all input args
    p = inputParser;
    p.addOptional('expName', '', @ischar);
    p.FunctionName = 'CREATENEWEXPERIMENT';
    p.parse(varargin{:});
    expID = p.Results.expName;
    %----------------------------------------------------------------------

    %check that we are good to go
    ensurePsychTestRigSetup();
    
    
    if isValidExpID(expID,false) %check that experiment doesn't already exist
        local_throwError(['The experiment "' expID '" alreayd exists!']);
    end
    
    %establish experiment name
    if isempty(expID)
        expID=local_getExperimentName();
    end
    
    %create
    disp(' ')
    disp(['creating ' expID '...'])
    
    % create files
    expHomeDir=local_createDefaultFiles(expID);
    
    % create db entry
    if getPrefVal('useDb')
        try
            local_createDatabaseEntry(expID);
        catch
            local_undoDirs(expID); %clean up 
            myErr = lasterr;            %TODO: replace with local_throwError
            myErr = ['\n/*****PsychTestRig: Experiment Creation failed.*****/\n' myErr]; 
            error(myErr,'x') 
        end
    end
    cloutput('...success!\n')
end


%%%%%%%%%%%%%%%%%%%%%%%
%%% LOCAL FUNCTIONS %%%
%%%%%%%%%%%%%%%%%%%%%%%
function expID=local_getExperimentName()
    while (1)
        x = getStringInput('Please enter the ID name of the new experiment: ');
        if (local_isValid(x) && ~local_alreadyExists(x))
             expID=x;
             break
        end
    end
end
function isValid=local_isValid(x)
    if (size(regexp(x,'.{1,32}'),2)~=1) %too big
        cloutput('\nID invalid: too many characters (1-32).')
        isValid=0;
    elseif (isempty(regexp(x,'^[a-zA-Z0-9_\#\-\$]*$','ONCE'))) %invalid chars
        cloutput('\nID invalid: the id can only contain a-z 0-9 - _ # $.')
        isValid=0;
    else
        isValid=1;
    end
end
function alreadyExists=local_alreadyExists(x)
    if (exist([getPrefVal('homeDir'),filesep,x],'dir'))
        cloutput('ID already exists.\n')
        alreadyExists=1;
    else
        alreadyExists=0;
    end
end

function expHomeDir=local_createDefaultFiles(expID)

    homeDir=getPrefVal('homeDir');
    expHomeDir=[homeDir filesep expID];
    
    try
        disp(['   creating file structure @ ' expHomeDir '...'])

        disp('   |   creating directories..')

        disp('      |   home..')
        mkdir(expHomeDir)

        disp('      |   top level..')
        mkdir(expHomeDir,'analysis');
        mkdir(expHomeDir,'data');
        mkdir(expHomeDir,'dissemination');
        mkdir(expHomeDir,'docs');
        mkdir(expHomeDir,'figures');
        mkdir(expHomeDir,'proposal');
        mkdir(expHomeDir,'recruitment');
        mkdir(expHomeDir,'run');
        mkdir(expHomeDir,'writeup');

        disp('      |   sub-directories..')
        mkdir(expHomeDir,['run' filesep 'calibrations']);
        mkdir(expHomeDir,['run' filesep 'code']);
        mkdir(expHomeDir,['run' filesep 'configs']);
        mkdir(expHomeDir,['run' filesep 'resources']);
        mkdir(expHomeDir,['run' filesep 'resources' filesep 'audio']);
        mkdir(expHomeDir,['run' filesep 'resources' filesep 'images']);

        disp('   |   creating files..')
        %mkfile([expHomeDir filesep 'configs' filesep 'basic_config.config.txt']);
        %copyfile(which('dummy_config.expConfig.xml'),[expHomeDir filesep 'run' filesep 'configs'])
        tmp = ver('psychtestrig');
        config=[];
        config.ptrVersion = tmp.Version;
        config.script = 'dummy_experiment.m';
        %config.randSeed = 1;
        config.params.basicParams.a = 1;
        config.params.stimParams.a = 'dfdf';
        config.params.stimParams.b = 2;
        config.params.adaptParams.x = 1;
        xml_write(fullfile(expHomeDir,'run','configs','dummy_config.expConfig.xml'), config);

        copyfile(which('dummy_experiment.m'),[expHomeDir filesep 'run' filesep 'code'])
        copyfile(which('dummy_README.txt'),expHomeDir)

        %piggy-back to make these files/dirs
        fprintf('      |   ');
        ensurePartInfoFile(expID, true);
    catch ME
        local_undoDirs(expID);
        cloutput('...Failed\n')
        rethrow(ME);
    end
    cloutput('   done\n')
end

function local_createDatabaseEntry(expID)
        connectToDB();
        
        try
            disp(' ')
            disp('   creating database structure...')
            disp('   |   adding experiment to database..')
            addExperimentToDatabase(expID);
            disp('   |   ammending default details..')
            ammendExperimentRecord(expID);
            cloutput('   done')
        catch ME
            fprintf('\n   ABORTING: removing db record...\n\n')
            rmExpFromDb(expID);
            rethrow(ME);
        end
        
        disconnectFromDB();      
end

function local_undoDirs(expID)
    fprintf('\n   ABORTING: removing dir structure...\n\n')
    homeDir=getPrefVal('homeDir');
    expHomeDir=[homeDir filesep expID];
    rmdir(expHomeDir,'s');
end

function local_throwError(errTxt)
    myErr=	[   
            '/*****PsychTestRig: Experiment Creation failed.\n\n' ...
            '   ' errTxt '\n\n' ...
            '*****/' ...
            ];   
    error('PsychTestRig:createNewExperiment:criticalFailure',myErr)  
end