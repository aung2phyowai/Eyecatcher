function partDataDir = login_ensurePartDataDir(expID,partID,skipLoginChecks)

    %----------------------------------------------------------------------
    p = inputParser;
    p.addRequired('expID', @ischar);
    p.addRequired('partID', @isPositiveInt);
    p.addRequired('skipLoginChecks', @islogical);
    p.FunctionName = 'STARTNEWDATASESSION';
    p.parse(expID,partID,skipLoginChecks); % Parse & validate all input args
    %----------------------------------------------------------------------

    %checks that the data subdir exists, if not create it
    partDataDir=fullfile(getPrefVal('homeDir'), expID, 'data', num2str(partID));
    if ~exist(partDataDir,'dir')
        if skipLoginChecks
            mkdir(partDataDir);
            return;
        else
            if getLogicalInput(sprintf('\n   create participant %i data subdirectory? (y/n):  ',partID));
                mkdir(partDataDir); 
            else
                error('login_ensurePartDataDir:Abort', 'No output dir. Aborting');
            end
        end
    end
    
end


    
