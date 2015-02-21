function [preds] = optimizePredictions(class,useSaved,useMirror,useSoftAssignment)
%OPTIMIZEPREDICTIONS Summary of this function goes here
%   Detailed explanation goes here
globals;
encoding = params.angleEncoding;
goodInds = createEvalSets(class,0); %no train/val/test splits

%% Predictions from CNN
data = load(fullfile(cachedir,'evalSets',class));
[~,~,testLabels,~,~,testFeats] = generateEvalSetData(data);
[testPreds,predUnaries] = poseHypotheses(testFeats,params.nHypotheses,0);
N = size(testPreds{1},1);

%% mirrored preds
predUnaries = vertcat(predUnaries,predUnaries);
testPredsMirror = testPreds;
if(useMirror)
    for i=1:length(testPreds)
        testPredsMirror{i} = vertcat(testPreds{i},mirrorFlipPreds(testPreds{i}));
    end
end
%% set-up optimizattion
formulationDir = fullfile(cachedir,['optimizationInit' params.vpsDataset],params.features);
mkdirOptional(formulationDir);
if(useSaved && exist(fullfile(formulationDir,[class '.mat']),'file'))
    load(fullfile(formulationDir,[class '.mat']))
else
    fg = fspecial('gaussian',[5 5],1);
    load(fullfile(cachedir,['rcnnPredsVps' params.vpsDataset],'vggConv5',class));
    feat = feat(goodInds);
    if(useMirror)
        featMirror = featMirror(goodInds);
        feat = vertcat(feat,featMirror);
    end
    for i=1:length(feat)
        tmp = reshape(sigmoid(feat{i}),[14 14 512]);
        for c = 1:512
            tmp(:,:,c)=tmp(:,:,c)/sum(sum(tmp(:,:,c)));
            %tmp(:,:,c) = conv2(tmp(:,:,c),fg,'same');
        end
        feat{i} = (tmp(:))';
    end
        
    [initPreds,similarFeatInds,similarRotIndLabels] = formulateOptimization(testPredsMirror,feat, encoding, predUnaries,useSoftAssignment);
    save(fullfile(formulationDir,[class '.mat']),'initPreds','similarFeatInds','similarRotIndLabels','feat');
end

for n=1:length(initPreds)
    if(useSoftAssignment)
        initPreds(n).probs = initPreds(n).unary - log(sum(exp(initPreds(n).unary)));
    else
        initPreds(n).probs = -Inf(size(initPreds(n).unary));
        [~,maxInd] = max(initPreds(n).unary);
        initPreds(n).probs(maxInd) = 0;
    end
end

%keyboard;

currentPreds = initPreds;
preds = [];
for n=1:N
    preds(n,:) = testPreds{currentPreds(n).choice}(n,:);
end

%% iterate

for iter = 1:50
    if(iter > 1 && numFlips <= 2)
        continue;
    end
    numFlips = 0;
    disp(iter);
    for n=randperm(length(initPreds))
        [choiceIndex,choiceScores] = updateRotationChoice(n,currentPreds,similarFeatInds);
        if(useSoftAssignment)
            probs = choiceScores - log(sum(exp(choiceScores)));
        else
            probs = -Inf(size(currentPreds(n).probs));
            probs(choiceIndex) = 0;
        end
        currentPreds(n).probs = probs;
%         if(isinf(min(choiceScores)))
%             visFeatNeighbors(data.test,similarFeatInds{n},n);
%             pause();close all;
%         end
%             
        if(choiceIndex ~= currentPreds(n).choice)
            %scores = choiceScores([currentPreds(n).choice choiceIndex]);
            %prediction = [testPreds{currentPreds(n).choice}(n,:);testPreds{choiceIndex}(n,:)];
            %visualizeOptimizationSwitch(prediction,encoding,class,data.test.voc_ids{n},data.test.dataset{n},data.test.bboxes(n,:),data.test.objectInds(n),scores);
            if(choiceScores(choiceIndex) - choiceScores(currentPreds(n).choice) > 1/iter)
                currentPreds(n).choice = choiceIndex;
                if(n<=N)
                    preds(n,:) = testPreds{currentPreds(n).choice}(n,:);
                end
                numFlips = numFlips+1;
            end
        end
    end
    
    [testErrsOpt] = evaluatePredictionError({preds},testLabels,encoding,0);
    testAccuracyOpt = sum(testErrsOpt<=30)/numel(testErrsOpt)
    testMedErrorOpt = median(testErrsOpt)
    disp(numFlips);
end

%% eval
[testErrsOpt] = evaluatePredictionError({preds},testLabels,encoding,0);
testAccuracyOpt = sum(testErrsOpt<=30)/numel(testErrsOpt);
testMedErrorOpt = median(testErrsOpt);

[testErrs,predBest] = evaluatePredictionError(testPreds,testLabels,encoding,0);
testAccuracy = sum(testErrs<=30)/numel(testErrs);
testMedError = median(testErrs);

%% debug
keyboard;

%% visualization - flipped instances
% preds = [];
% for n=1:N
%    preds(n,:) = testPreds{currentPreds(n).choice}(n,:);
%    [choiceIndex,choiceScores] = updateRotationChoice(n,currentPreds,similarFeatInds);
%     if(choiceIndex ~= 1)
%         scores = choiceScores([initPreds(n).choice choiceIndex]);
%         prediction = [testPreds{initPreds(n).choice}(n,:);testPreds{choiceIndex}(n,:)];
%         visualizeOptimizationSwitch(prediction,encoding,class,data.test.voc_ids{n},data.test.dataset{n},data.test.bboxes(n,:),data.test.objectInds(n),scores);
%         figure();
%         visFeatNeighbors(data.test,similarFeatInds{n},n);
%         pause();close all;
%     end
% end

%% visualization - incorrect instances
preds = [];
for n=randperm(N)
   preds(n,:) = testPreds{currentPreds(n).choice}(n,:);
   [choiceIndex,choiceScores] = updateRotationChoice(n,currentPreds,similarFeatInds);
    if(testErrs(n) < testErrsOpt(n))
        for c = 1:length(testPreds)
            if(sum(abs(testPreds{c}(n,:)-predBest(n,:)))==0)
                bestInd = c;
            end
        end
        scores = choiceScores([choiceIndex bestInd]);
        prediction = [preds(n,:);predBest(n,:)];
        visualizeOptimizationSwitch(prediction,encoding,class,data.test.voc_ids{n},data.test.dataset{n},data.test.bboxes(n,:),data.test.objectInds(n),scores);
        figure();
        visFeatNeighbors(data.test,similarFeatInds{n},n);
        pause();close all;
    end
end



end

function preds = mirrorFlipPreds(preds)
    preds(:,1) = - preds(:,1);
    preds(:,3) = 2*pi-preds(:,3);
end