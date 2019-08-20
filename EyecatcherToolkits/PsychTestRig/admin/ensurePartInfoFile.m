function [fn, spec] = ensurePartInfoFile(expID,varargin)

    %----------------------------------------------------------------------
    p = inputParser;
    p.addRequired('expID', @ischar);
    p.addOptional('forceCreate', false, @islogical);
    p.FunctionName = 'STARTNEWDATASESSION';
    p.parse(expID,varargin{:}); % Parse & validate all input args
    %----------------------------------------------------------------------
    forceCreate = p.Results.forceCreate;
    %----------------------------------------------------------------------

    
    %checks that the data subdir exists, if not create it
    dataDir=fullfile(getPrefVal('homeDir'), expID, 'data');
    partInfoDir = fullfile(dataDir,'__PARTINFO');
    %partDirs=getDirs(dataDir, true);
    %if (~ismember('__PARTINFO',partDirs))
    if ~exist(partInfoDir,'file')
        if forceCreate || getLogicalInput('data/__PARTINFO subdirectory not found. Create? (y/n):  ');
            mkdir(partInfoDir); 
        else
            error('login_ensurePartInfo:Abort', 'No output dir. Aborting');
        end
    end
    
    %checks that partinfospec.xml exists, if not create it
    fn = fullfile(partInfoDir,'partinfospec.xml');
    if ~exist(fn,'file')
        if forceCreate || getLogicalInput('data/__PARTINFO/partinfospec.xml not found. Create? (y/n):  ');
            spec = createDefaultPartInfoSpec(partInfoDir);
        else
            error('login_ensurePartDataDir:Abort', 'No output file. Aborting');
        end
    else
        spec = xmlRead(fn);
    end

    % Sync part spec with csv file
    fn = fullfile(partInfoDir,'partinfo.csv');
    if ~exist(fn,'file') % checks that partinfo.xls exists, if not create it
        if forceCreate || getLogicalInput('data/__PARTINFO/partinfo.csv not found. Create? (y/n):  ');
            local_genInfoFileFromSpec(fn, spec);
        else
            error('login_ensurePartDataDir:Abort', 'No output file. Aborting');
        end
    else % check the 2 match
        fid = fopen(fn);
        if fid==-1
          error('syncPartSpecWithCsv:errorOpeningFile','File not found or permission denied: "%s"',fn);
        end

        try
            % Extract the headers
            csvFields = regexp(fgetl(fid),',','split')';
            specFields = [{'id'}; fieldnames(spec)]; % must always have an id field
            
            % check for mismatches
            [ok,list1,list2]=disunion(csvFields,specFields);
            if ok
                fclose(fid);
            else
                fprintf('Mismatch between partinfo.csv and partinfospec.xml\n');
                if ~isempty(list1)
                    fprintf(' |- In partinfo.csv but not in partinfospec.xml: %s\n',strjoin1(',',list1{:}));
                end
                if ~isempty(list2)
                    fprintf(' |- In partinfospec.xml but not in partinfo.csv: %s\n',strjoin1(',',list2{:}));
                end
                fprintf('\n');
                
                % delete?
                if ~getLogicalInput('Delete the csv and rewrite with xml spec?\nIf no, will have to manually reconcile the two (y/n): ');
                    error('ensurePartInfoFile:invalid','Ensure that partinfospec.xml matches partinfo.csv before continuing\n(Alternatively, delete partinfo.csv');
                end
                
                % ---------------------------------------------------------
                % regenerate based on xml, make backup first if necessary:
                
                % does file have any content?
                emptyFile = false;
                if fgetl(fid) == -1
                    emptyFile = true;
                end
                
                % close file
                fclose(fid);
                fid = [];
                
                % backup any content
                if ~emptyFile
                    [path,stem,ext] = fileparts(fn);
                    stamp =  datestr(now(),30);
                    newFn = fullfile(path, sprintf('%s_%s%s',stem,stamp,ext));
                    copyfile(fn,newFn);
                    fprintf('Old data backuped up to: %s\n', newFn);
                end
                
                % delete old file
                delete(fn);
                fprintf('partinfo.csv deleted\n');
                
                % create new file
                local_genInfoFileFromSpec(fn, spec);
            end
            
        catch ME
            if ~isempty(fid)
                fclose(fid);
            end
            rethrow(ME);
        end
        
    end
    
    
end

function [] = local_genInfoFileFromSpec(fn, spec)
    fid = fopen(fn,'w+'); % will make if doesn't exist
    try
        fields = fieldnames(spec);
        fprintf(fid,'%s',strjoin1(',','id',fields{:}));
        fwrite(fid, getNewline(), 'char'); % terminate this line
        fclose(fid);
        fprintf('New partinfo.csv file generated from partinfospec.xml\n');
    catch ME
        fclose(fid);
        rethrow(ME);
    end
end