function rmExpFromDb(exp)
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
    
    msg=mysql(sprintf('DELETE FROM %s WHERE %s="%s"','experiments','name',exp));
    
end