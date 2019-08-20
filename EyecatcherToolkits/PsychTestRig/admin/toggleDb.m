function [] = toggleDb()

    %get/set
    oldVal = getPrefVal('useDb');
    newVal = ~oldVal;
    setPrefVal('useDb',newVal);
    
    % report
    txt = {'DISABLED','ENABLED'};
    fprintf('Database switched from %s to %s\n',txt{oldVal+1},txt{newVal+1});
end