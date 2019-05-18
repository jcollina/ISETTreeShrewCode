function sampledData = sampleThresholdBinarySearch(data,varargin)



p = inputParser;
p.addParameter('stepsBeforePlotting', 3, @isnumeric)
p.addParameter('minInputPoints', 5, @isnumeric)
p.addParameter('numOutputPoints', 5, @isnumeric)
p.addParameter('numOtherPoints', 5, @isnumeric)
p.addParameter('acceptedAccRange', [74.5 , 75.5],@isnumeric)
p.addParameter('contrastRange', [.001 , .03],@isnumeric)

p.parse(varargin{:});
stepsBeforePlotting = p.Results.stepsBeforePlotting;
minInputPoints = p.Results.minInputPoints;
numOutputPoints = p.Results.numOutputPoints;
numOtherPoints = p.Results.numOtherPoints;
contrastRange = p.Results.contrastRange;
acceptedAccRange = p.Results.acceptedAccRange;

%**********
theMosaic = data.expInfo.theMosaic;
theOI = data.expInfo.theOI;
presentationDisplay = data.expInfo.presentationDisplay;
stimParams = data.expInfo.stimParams;

nTrialsNum = data.expInfo.nTrialsNum;
nFolds = 10;%data.expInfo.nFolds;

sizeDegs = round(theMosaic.fov);

% All we need now is the results of the binary search
data = data.binaryResults;

j = 1;
while 1
    a = data.contrasts{1,j};
    thresholdContrastsTemp = unique(round(a(stepsBeforePlotting : length(a)),4));
    if accRange(1) < data.finalAccuracy(j) && accRange(2) > data.finalAccuracy(j)
        if length(thresholdContrastsTemp) > minInputPoints
            thresholdContrasts = thresholdContrastsTemp;
            break;
        end
    end
    j = j+1;
    if j > length(data.contrasts)
        error('Sadly, none of the binary searches in this dataset fulfill your requirements.')
    end
end

% Create parameter structure for a low spatial frequency Gabor stimulus
stimParams.spatialFrequencyCyclesPerDeg = data.frequencyRange(j);

minC = min(thresholdContrasts);
maxC = max(thresholdContrasts);

thresholdSamples = minC:(maxC-minC)/numOutputPoints:maxC;

sampleContrastRange = min(contrastRange):range(contrastRange)/numOtherPoints:max(contrastRange);

contrasts = sort([sampleContrastRange,thresholdSamples]);

%% Using SVM to calculate accuracy for each contrast

% Size of testing set, based on 10-fold cross-evaluation


% Generate null scene (contrast = 0)
stimParams.contrast = 0.0;

nullScene = generateGaborScene(...
    'stimParams', stimParams,...
    'presentationDisplay', presentationDisplay);

accuracies = zeros(1,length(contrasts));
acc_SE = zeros(1,length(contrasts));
% Cycle through contrasts, using the SVM to calculate accuracy for each.

T = tic;

count = 1;
N = length(contrasts);

D = parallel.pool.DataQueue;

w = waitbar(0, 'Progress');
afterEach(D, @nUpdateWaitbar);

parfor i = 1:length(contrasts)
    
    % Set the contrast level for this iteration
    stimParamsTemp = stimParams;
    stimParamsTemp.contrast = contrasts(i);
    
    % Generate a Gabor patch with that contrastm
    testScene = generateGaborScene(...
        'stimParams', stimParamsTemp,...
        'presentationDisplay', presentationDisplay,...
        'minimumPixelsPerHalfPeriod', 5);
    
    % Determine how well the specified optics can discriminate between that
    % patch and a null stimulus
    acc = getSVMAcc(theMosaic, theOI, testScene, nullScene, 'nTrialsNum',nTrialsNum,'nFolds',nFolds);
    accuracies(i) = mean(acc);
    accuracySE(i) = std(acc)/sqrt(length(acc));
    
    send(D,i)
end

delete(gcp)
close(w)


sampledData.time = toc(T)/60;
sampledData.frequency = stimParams.spatialFrequencyCyclesPerDeg;
sampledData.contrasts = contrasts;
sampledData.accuracies = accuracies;
sampledData.accuracySE = accuracySE;
sampledData.acceptedAccRange = acceptedAccRange;

%% Functions

    function nUpdateWaitbar(~)
        waitbar(count/N, w);
        count = count + 1;
    end

end