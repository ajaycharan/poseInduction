function [class] = pascalIndexClass(c,dataset)
%PASCALINDEXCLASS Summary of this function goes here
%   Detailed explanation goes here

if(strcmp(dataset,'Ilsvrc'))
    globals;
    load(fullfile(ilsvrcDir,'classes'));
    class = classes{c};
    return;
end


classes = {'aeroplane','bicycle','bird','boat','bottle','bus','car','cat','chair','cow','diningtable','dog','horse','motorbike','person','pottedplant','sheep','sofa','train','tvmonitor'};
if(c<1 || c>length(classes))
    class = 'none';
else
    class = classes{c};
end

end

