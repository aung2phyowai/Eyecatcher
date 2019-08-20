function spec = createDefaultPartInfoSpec(partInfoDir)

    %----------------------------------------------------------------------
    p = inputParser;
    p.addRequired('partInfoDir', @(x)exist(x,'dir'));
    p.FunctionName = 'CREATEDEFAULTPARTINFOSPEC';
    p.parse(partInfoDir);
    %----------------------------------------------------------------------

    spec=[];
    
    %spec.id = []; %included automaticallys
    
    spec.dob.question = 'dob?';
    spec.dob.datatype = 'date';
    
    spec.sex.question = 'sex?';
    spec.sex.datatype = 'VarChar(1)';
    
    spec.initials.question = 'initials?';
    spec.initials.datatype = 'VarChar(10)';
    
    xml_write(fullfile(partInfoDir,'partinfospec.xml'), spec);
    
end