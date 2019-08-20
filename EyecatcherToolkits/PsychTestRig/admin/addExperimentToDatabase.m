function addExperimentToDatabase(exp)
%ADDEXPERIMENTTODATABASE shortdescr.
%
% Description
%
% Example: none
%
% See also

    %----------------------------------------------------------------------
    % Parse & validate all input args
    p = inputParser;
    p.addRequired('exp', @ischar);
    p.FunctionName = 'ADDEXPERIMENTTODATABASE';
    p.parse(exp);
    %----------------------------------------------------------------------
    
    msg=mysql(['INSERT INTO experiments (name) VALUES ("' exp '")']);
end