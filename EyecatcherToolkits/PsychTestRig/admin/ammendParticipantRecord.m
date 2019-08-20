function errCode=ammendParticipantRecord(partID)
%AMMENDPARTICIPANTRECORD description.
%
% ....
%
% Example: none
%
% See also


    %----------------------------------------------------------------------
    % Parse & validate all input args
    p = inputParser;
    p.addRequired('partID', @(x)x>0 && mod(x,1)==0); %integer
    p.FunctionName = 'AMMENDEXPERIMENTRECORD';
    p.parse(partID);
    %----------------------------------------------------------------------
    [name notes]=mysql(['SELECT name, notes FROM participants WHERE id_num=' partID]);
    %----------------------------------------------------------------------

    dim = [15 3]; %layout coordinates (15 rows, 3 columns)

    Title=['Ammend Participant "' partID '"''s Details'];

    % static text
    i=1;
    Prompt = cell(i,2);
    Prompt{i,1} = ['ID: ' partID];
    Formats(i,1).type = 'text';
    Formats(i,1).size = [-1 0];
    for k = 2:dim(2) % span the static text across the entire dialog
       Formats(i,k).type = 'none';
       Formats(i,k).limits = [0 1]; % extend from left
    end
    
    i=i+1;
    Prompt(i,:) = {'Name: ', 'name'};
    Formats(i,1).type = 'edit';
    Formats(i,1).format = 'text';
    Formats(i,1).size = [-1 0];
    for k = 2:dim(2)-1 % span horizontally
       Formats(i,k).type = 'none';
       Formats(i,k).limits = [0 1]; % extend from left
    end
    
    i=i+1;
    Prompt(i,:) = {'Notes: ', 'notes'};
    Formats(i,1).type = 'edit';
    Formats(i,1).format = 'text';
    Formats(i,1).limits = [0 5]; % default: show 20 lines
    Formats(i,1).size = [-1 0];
    for k = 2:dim(2) % span horizontally
       Formats(i,k).type = 'none';
       Formats(i,k).limits = [0 1]; % extend from left
    end
    
    i=i+1;
    Prompt(i,:) = {'I confirm that these details are correct.' 'confirmation'};
    Formats(i,1).type = 'check';


        
    %%%% SETTING DEFAULT STRUCT
    DefAns.name = char(name);
    DefAns.notes = char(notes);
    DefAns.confirmation = 0;

    %%%% SETTING DIALOG OPTIONS
    Options.WindowStyle = 'modal';
    Options.Resize = 'off';
    Options.ApplyButton = 'off';

    %%%% LAUNCH
    
    
    while (1)
        [Answer,Cancelled] = inputsdlg(Prompt,Title,Formats,DefAns,Options);
        if (Answer.confirmation)
            break
        else
            Prompt(i,:) = {'I confirm that these details are correct. <------- !!!PLEASE TICK!!!' 'confirmation'};
        end
    end
    
    if (~Cancelled) %n.b. this is called even if cancelled when Apply is clicked
        %Save answers
        msg=mysql(['UPDATE participants SET name="' Answer.name '", notes="' Answer.notes '" WHERE id_num=' partID]);
    end
    
end