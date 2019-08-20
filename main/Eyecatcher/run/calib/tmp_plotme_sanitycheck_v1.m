close all
figure();
hold on
txt = {};
for i = 1:size(out_cdm2,1)
    for j = 1:size(out_cdm2,2)
        x = in_CL;
        y = out_cdm2(i,j,:);
        plot(x(:), y(:), '-o');
        txt{i,j} = sprintf('Loc-%i-%i',i,j); %#ok
    end
end
legend(txt{:},'Location','NorthWest')