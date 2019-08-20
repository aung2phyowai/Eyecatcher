function ammendExperimentRecord(expName)
%AMMENDEXPERIMENTRECORD shortdescr.
%
% Description
%
% Example: none
%
% See also

    %----------------------------------------------------------------------
    % Parse & validate all input args
    p = inputParser;
    p.addRequired('expName', @ischar);
    p.FunctionName = 'AMMENDEXPERIMENTRECORD';
    p.parse(expName);
    %----------------------------------------------------------------------   
    [name last_update creation_date status notes]=mysql(['SELECT name, last_update, creation_date, status, notes FROM experiments WHERE name = "' expName '";']);
    %----------------------------------------------------------------------

    dim = [15 3]; %layout coordinates (15 rows, 3 columns)

    Title=['Ammend "' expName '" Details'];

    % static text
    Prompt = cell(1,2);
    Prompt{1,1} = ['Experiment: "' expName '"'];
    Formats(1,1).type = 'text';
    Formats(1,1).size = [-1 0];
    for k = 2:dim(2) % span the static text across the entire dialog
       Formats(1,k).type = 'none';
       Formats(1,k).limits = [0 1]; % extend from left
    end

    Prompt(2,:) = {'Last Update:    ', 'lastUpdate'};
    Formats(2,1).type = 'edit';
    Formats(2,1).format = 'text';
    Formats(2,1).size = [-1 0];
    for k = 2:dim(2)-1 % span horizontally
       Formats(2,k).type = 'none';
       Formats(2,k).limits = [0 1]; % extend from left
    end

    Prompt(3,:) = {'Creation Date: ', 'creationDate'};
    Formats(3,1).type = 'edit';
    Formats(3,1).format = 'text';
    Formats(3,1).size = [-1 0];
    for k = 2:dim(2)-1 % span horizontally
       Formats(3,k).type = 'none';
       Formats(3,k).limits = [0 1]; % extend from left
    end

    Prompt(4,:) = {'Status: ','status'};
    Formats(4,1).type = 'list';
    Formats(4,1).style = 'togglebutton';
    Formats(4,1).items = {'PENDING' 'IN PROGRESS' 'COMPLETE' 'ABORTED'};
    Formats(4,1).size = [-1 0];
    for k = 2:dim(2) % span horizontally
       Formats(4,k).type = 'none';
       Formats(4,k).limits = [0 1]; % extend from left
    end

    Prompt(5,:) = {'Notes: ', 'notes'};
    Formats(5,1).type = 'edit';
    Formats(5,1).format = 'text';
    Formats(5,1).limits = [0 5]; % default: show 20 lines
    Formats(5,1).size = [-1 0];
    for k = 2:dim(2) % span horizontally
       Formats(5,k).type = 'none';
       Formats(5,k).limits = [0 1]; % extend from left
    end

    %%%% SETTING DEFAULT STRUCT
    DefAns.lastUpdate = char(last_update);
    DefAns.creationDate = datestr(creation_date,31);
    DefAns.status = find(ismember(Formats(4,1).items,status));  %get index (poor man's hash)
    DefAns.notes = char(notes);

    %%%% SETTING DIALOG OPTIONS
    Options.WindowStyle = 'modal';
    Options.Resize = 'off';
    Options.ApplyButton = 'on';

    %%%% LAUNCH
    [Answer,Cancelled] = inputsdlg(Prompt,Title,Formats,DefAns,Options);
    
    if (~Cancelled) %n.b. this is called even if cancelled when Apply is clicked
        %Save answers
        myStatus=Formats(4,1).items{Answer.status};  %get item (poor man's hash)
        msg=mysql(['UPDATE experiments SET last_update="' Answer.lastUpdate '", creation_date="' Answer.creationDate '", status="' myStatus '", notes="' Answer.notes '" WHERE name = "' expName '";']);
    end
end