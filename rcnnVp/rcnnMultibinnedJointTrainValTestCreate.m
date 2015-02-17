function [] = rcnnMultibinnedJointTrainValTestCreate(binSizes)
%RCNNTRAINVALTESTCREATE Summary of this function goes here
%   Detailed explanation goes here

%% WINDOW FILE FORMAT
% repeated :
%   img_path(abs)
%   reg2sp file path
%   sp file path
%   num_pose_param
%   channels
%   height
%   width
%   num_windows
%   classIndex overlap x1 y1 x2 y2 regionIndex poseParam0 .. poseParam(numPoseParam)

%% Initialization
globals;
params = getParams();

%% Train/Val/Test filenames generate
fnames = getFileNamesFromDirectory(fullfile(cachedir,'rcnnData'),'types',{'.mat'});
N = length(fnames);
for i=1:N
    fnames{i} = fnames{i}(1:end-4);
end

load(fullfile(cachedir,'jointTrainValTestSets.mat'));
fnamesSets = {};
fnamesSets{1} = fnamesTrain;
fnamesSets{2} = fnamesVal;
fnamesSets{3} = fnamesTest;
nBins = numel(binSizes);

intervals = {};
for b=binSizes
    intervals{end+1} = [0 (360/(b*2)):(360/b):360-(360/(b*2))];
end

%% Generating test files
%sets = {'Train','Val','Test'};
sets = {'Train','Val'};

for s=1:length(sets)
    set = sets{s};
    disp(['Generating data for ' set]);
    txtFile = fullfile(cachedir,'rcnnFinetuneMultibinnedJoint',[set '.txt']);
    fid = fopen(txtFile,'w+');
    fnames = fnamesSets{s};
    count = 0;
    for j=1:length(fnames)
    %for j=1:1
        id = fnames{j};
        if(exist(fullfile(cachedir,'rcnnData',[id '.mat']),'file'))
            candFile = fullfile(cachedir,'rcnnData',[id '.mat']);
            dataset = 'pascal';
        elseif (exist(fullfile(cachedir,'rcnnDataImagenet',[id '.mat']),'file'))
            candFile = fullfile(cachedir,'rcnnDataImagenet',[id '.mat']);
            dataset = 'imagenet';
        else
            continue;
        end
        cands = load(candFile);
        if(isempty(cands.overlap))
            continue;
        end
        numcands = round(sum(cands.overlap >= params.candidateThresh));
        if(numcands ==0)
            continue;
        end
        count=count+1;
        %%%%%%%%%%%% Insert anakin paths here
        if(strcmp(dataset,'imagenet'))
            imgFile = ['/data1/shubhtuls/cachedir/imagenet/images/' id '.jpg'];
            imSize = cands.imSize;
        else
            imgFile = ['/data1/shubhtuls/cachedir/VOCdevkit/VOC2012/JPEGImages/' id '.jpg'];
            tmp = load(fullfile(pascalCandsDir,id));imsize = size(tmp.sp);
        end

        %fprintf(fid,'# %d\n%s\n%s\n%s\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n',count-1,imgFile,reg2spFile,spFile,3,10,10,20,3,imsize(1),imsize(2),numcands);
        fprintf(fid,'# %d\n%s\n%d\n%d\n%d\n%d\n',count-1,imgFile,3,imsize(1),imsize(2),numcands);
        %if(max(cands.euler(:,1))>=pi/2 || max(cands.euler(:,2)>=pi/2 ))
        %    disp('Oops');
        %end
        for n=1:size(cands.overlap,1)
            azimuth = cands.euler(n,3);
            fprintf(fid,'%d %f %d %d %d %d',cands.classIndex(n),cands.overlap(n),...
                cands.bbox(n,1),cands.bbox(n,2),cands.bbox(n,3),cands.bbox(n,4));
            for b=1:numel(binSizes)
                ind = findInterval(azimuth*180/pi,intervals{b});
                fprintf(fid, ' %d', ind-1);
            end
            if(numel(binSizes < 6))
                for b=1:(6-numel(binSizes))
                    fprintf(fid, ' %d', 0);
                end
            end
            fprintf(fid,'\n');
        end
    end
end

end

function ind = findInterval(azimuth, a)
for i = 1:numel(a)
    if azimuth < a(i)
        break;
    end
end
ind = i - 1;
if azimuth > a(end)
    ind = 1;
end
end