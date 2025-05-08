mainDir             = 'X:\';
redoAnalysis        = true;
allDirs0            = dir(mainDir);
% [rootDir, ~, ~]     = fileparts(mainDir);

allDirs0            = allDirs0([allDirs0.isdir] & ~startsWith({allDirs0.name}, '.'));
allDirs1            = {};
pattern             = '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$';
day                 = datestr(now, 'yyyymmdd_HHMM');
% include multiple recordings
for i = 1:numel(allDirs0)
    firstDirPath = fullfile(mainDir, allDirs0(i).name);
    secondLevelDirs = dir(firstDirPath);
    secondLevelDirs = secondLevelDirs([secondLevelDirs.isdir] & ~startsWith({secondLevelDirs.name}, '.'));
    
    for j = 1:numel(secondLevelDirs)
        folderName          = secondLevelDirs(j).name;
        secondDirPath       = fullfile(firstDirPath, folderName);
         if ~isempty(regexp(folderName, pattern, 'once')) % Match against the pattern
            allDirs1{end+1, 1} = secondDirPath;
         end
    end
end

for d1r = 1:length(allDirs1)

    recDir              = fullfile(allDirs1{d1r});
    OEmetafile          = findOebinFile(recDir);                           % Recursivly look for oebin within subfolder
    [oebinDir, ~, ~]    = fileparts(OEmetafile);
    
    ListLeve2           = dir(fullfile(recDir,'preprocessed'));
    indxPreproc         = all([contains({ListLeve2.name},'kilosort4'); [ListLeve2.isdir]],1);
    subdir1             = fullfile(ListLeve2(indxPreproc).folder, ListLeve2(indxPreproc).name); % grab preprocessed folder
    ephysKSPath         = subdir1;
    contentDir          = dir(subdir1);
    if ~redoAnalysis && any(contains({contentDir.name},'qMetrics_BC.mat')) % if the dir contains already BC output then skip it
        continue
    end
    % ephysKSPath         = dir(subdir1);
    % indxKSdir           = all([contains({ephysKSPath.name},'kilosort'); [ephysKSPath.isdir]],1); % grab kilosort folder
    % ephysKSPath         = fullfile(ephysKSPath(indxKSdir).folder, ephysKSPath(indxKSdir).name);
    % oebinDir            = 'D:\Dustin_NP\20231205_4458_FP_lowIso_DL\2023-12-05_14-21-01\Record Node 101\experiment1\recording1';
    % ephysKSPath         = 'D:\Dustin_NP\20231205_4458_FP_lowIso_DL\2023-12-05_14-21-01\Record Node 101\experiment1\recording1\continuous\Neuropix-PXI-100.ProbeA-AP';
    ephysRawFile        = dir(fullfile(ListLeve2(1).folder,'*.raw')); % path to your raw .bin or .dat data
    ephysMetaDir        = dir(fullfile(oebinDir,'*.oebin')); % path to your .meta or .oebin meta file
    savePath            = fullfile(ephysKSPath, [day, '_qMetrics']); % where you want to save the quality metrics
    recName             = strsplit(oebinDir,'\');
    recName             = recName{end-4};
    if ~exist(savePath,'dir')
        mkdir(savePath)
    end
    fileID_OE           = fopen(OEmetafile, 'r');
    metadata            = fread(fileID_OE, '*char')';
    fclose(fileID_OE);
    metadata            = jsondecode(metadata); % Decode the JSON content
    metaNames           = fieldnames(metadata)';
    indxContinous       = contains(metaNames,'continuous');
    metaNames2          = fieldnames(metadata.(metaNames{indxContinous}));
    indxMeta2           = contains(metaNames2,'folder_name','IgnoreCase',true);
    allStreams          = {metadata.(metaNames{indxContinous}).(metaNames2{indxMeta2})};
    indxAP              = contains(allStreams,'-AP');
    if any(indxAP)
        Fs = metadata.(metaNames{indxContinous})(indxAP).sample_rate; % NP 1.0
    else
        Fs = metadata.(metaNames{indxContinous})(1).sample_rate; % NP 2.0
    end

    % 
    % if matches(metadata.GUIVersion,'0.6.6') || matches(metadata.GUIVersion,'0.6.7')
    try
        gain_to_uV          = metadata.continuous(1).channels.bit_volts;
    catch
        gain_to_uV          = metadata.continuous(1).channels{1,1}.bit_volts;
    end
    ephysRawFile        = fullfile(ephysRawFile.folder, ephysRawFile.name);
    
    kilosortVersion     = 4;
    [spikeTimes_samples, spikeClusters, templateWaveforms, templateAmplitudes, pcFeatures, ...
        pcFeatureIdx, channelPositions] = bc.load.loadEphysData(ephysKSPath, savePath);
    param = bc.qm.qualityParamValues(ephysMetaDir, ephysRawFile, ephysKSPath, gain_to_uV, kilosortVersion);
    % change some defaults
    param.nChannels     = length(metadata.continuous(1).channels);
    param.nSyncChannels = 1;
    param.minPresenceRatio = 0.05;
    param.maxRPVviolations = 0.15;
    param.minNumSpikes      = round((max(spikeTimes_samples)/Fs)*0.05); % keep >0.05Hz spiking units as good
    % param.minAmplitude      = floor(prctile(templateAmplitudes,0.1,'all'));
    param.minAmplitude      = 5; % the amplitude of the template is ~= than the one calc by BC...??

    % unitType==0 noise units % unitType==1 good units % unitType==2 MUA units % unitType==3 non-somatic units

    [qMetric, unitType, f0,f1,f2,f3,f4] = bc.qm.runAllQualityMetrics(param, spikeTimes_samples, spikeClusters, ...
        templateWaveforms, templateAmplitudes, pcFeatures, pcFeatureIdx, channelPositions, savePath);
    print(f0, fullfile(savePath,[recName, '_', regexprep(f0.Name, '\s', '_'), '.jpeg']),'-djpeg', '-r600')
    print(f1, fullfile(savePath,[recName, '_', regexprep(f1.Name, '\s', '_'), '.jpeg']),'-djpeg', '-r600')
    print(f2, fullfile(savePath,[recName, '_', regexprep(f2.Name, '\s', '_'), '.jpeg']),'-djpeg', '-r600')
    print(f3, fullfile(savePath,[recName, '_', regexprep(f3.Name, '\s', '_'), '.jpeg']),'-djpeg', '-r600')
    print(f4, fullfile(savePath,[recName, '_', regexprep(f4.Name, '\s', '_'), '.jpeg']),'-djpeg', '-r600')
    filenameBC1         = fullfile(savePath,[recName, '_qMetrics_BC.mat']);
    save(filenameBC1,'param','qMetric','unitType')
    % Save params as JSON 
    jsonString          = jsonencode(param);
    outputJsonName      = fullfile(savePath,[recName, '_params_BC.json']);    
    fileID              = fopen(outputJsonName, 'w');
    fwrite(fileID, jsonString, 'char');
    fclose(fileID);

    %% inspect?

    % loadRawTraces = 1; % default: don't load in raw data (this makes the GUI significantly faster)
    % bc.load.loadMetricsForGUI;
    % 
    % unitQualityGuiHandle = bc.viz.unitQualityGUI_synced(memMapData, ephysData, qMetric, forGUI, rawWaveforms, ...
    %     param, probeLocation, unitType, loadRawTraces);

    %%

    goodUnits       = unitType == 1;
    muaUnits        = unitType == 2;
    noiseUnits      = unitType == 0;
    nonSomaticUnits = unitType == 3;
    
    qmet_SUA        = qMetric(goodUnits,:);
    qmet_MUA        = qMetric(muaUnits,:);
    qmet_noise      = qMetric(noiseUnits,:);
    qmet_nonSoma    = qMetric(nonSomaticUnits,:);

    all_good_units_number_of_spikes = qMetric.nSpikes(goodUnits); % example: get all good units number of spikes

    filenameBC1         = fullfile(savePath,[recName, '_qMetrics_BC.mat']);
    save(filenameBC1,'param','qMetric','unitType','qmet_SUA','qmet_MUA','qmet_noise','qmet_nonSoma')

    % copy all tsv files with quality metrics into the BC folder

    tsvFiles = dir(fullfile(ephysKSPath, '*.tsv'));

    for k = 1:length(tsvFiles)
        tmpTsvFile = fullfile(tsvFiles(k).folder, tsvFiles(k).name);
        destinationPath = fullfile(savePath, tsvFiles(k).name);
        copyfile(tmpTsvFile, destinationPath);
    end

end


function filePath = findOebinFile(startFolder)
    % Function to find the first file ending with .oebin in a tree of subfolders.
    % Input:
    %   startFolder - the root directory to start the search.
    % Output:
    %   filePath - the full path to the first .oebin file found, or empty if none found.

    if nargin < 1
        startFolder = pwd; % Default to current folder
    end
    
    % Look for .oebin files in the current folder
    files = dir(fullfile(startFolder, '*.oebin'));
    if ~isempty(files)
        % Return the full path of the first .oebin file found
        filePath = fullfile(startFolder, files(1).name);
        return;
    end
    
    % Recursively search subfolders
    subfolders = dir(startFolder);
    for k = 1:length(subfolders)
        if subfolders(k).isdir && ~startsWith(subfolders(k).name, '.')
            % Skip '.' and '..' and hidden folders
            subfolderPath = fullfile(startFolder, subfolders(k).name);
            filePath = findOebinFile(subfolderPath); % Recursive call
            if ~isempty(filePath)
                return; % Stop searching once a file is found
            end
        end
    end
    
    % If no file is found
    filePath = '';
end