% Revision History
%
% CrunchData(Joyfilename,Bhvfilename,TempfileName,varargin)
% 131126JED - 1) Added 'slash' contingency to allow computing on unix and
% windows machines. 2) Added a date field to the combined file which saves
% the date of the session as a string (variable name, 'SessionDate').
% 131213EJH = 1) Changed the initialization of TimeStamps and Targets
% matices to correctly reflect the number of columns. 2) Added conditional
% statements to become compatible with BMI data. 3) Save mat file version 7.3 or later. 

function CrunchData(Joyfilename,Bhvfilename,TempfileName,varargin) 

load(Joyfilename,'joy_data');
load(Bhvfilename,'bhv_data');

%% Save Date of Session (as string)
SessionDate = bhv_data.date;


SessionType = bhv_data.session_type(1);
Protocol = bhv_data.protocol_name;
NumOfTrials = bhv_data.num_trials_all;


%% Construct TimeStamps (NumOfTrials X NumOfBehavioralEvents)
% Each row represents a single trial. Each column represents the time when a behvaioral event occurs.
% The column number of each behavioral event is defined below. This can be
% modified, or expanded as needed.
TimeStampsColumnInfo={'TrialNumber','BitSent', 'ITIBegin', 'ITIEnd', 'CueOn', 'CueOff','GoCue','ResponseOff' 'RewardOn', 'RewardOff', 'TrialEnd','MoveOn','SpeedRising','VelPeak','TargetEnter','MoveOff'};
for i=1:size(TimeStampsColumnInfo,2)
    eval([TimeStampsColumnInfo{i} '=' num2str(i) ';']);
end
TimeStamps = NaN*ones(NumOfTrials,numel(TimeStampsColumnInfo));
TimeStamps(:,[TrialNumber]) = [1:NumOfTrials]';
TimeStamps(:,[BitSent]) = bhv_data.bitcode(:,1);
TimeStamps(:,[ITIBegin ITIEnd])=bhv_data.iti;
TimeStamps(:,[CueOn CueOff])=bhv_data.cue;
if isfield(bhv_data,'response')
    TimeStamps(:,[GoCue])=bhv_data.response(:,1);
    TimeStamps(:,[ResponseOff])=bhv_data.response(:,2);
end
TimeStamps(:,[RewardOn RewardOff]) = bhv_data.reward;
TimeStamps(:,[TrialEnd]) = bhv_data.end;

%% Construct Licking (NumOfTrials X TimeLength)
% Each row contains ones at the times when licking occurs, and zeros
% otherwise. Every trial is aligned so that the first index corresponds to
% the time that a trial begins.
MasterAlignInfo.AlignBehavior = CueOn;
MasterAlignInfo.PreAlignTime = 8; % in sec. The 15001th elements are the positions at cue onset.PreAlignTime;
MasterAlignInfo.PostAlignTime = 17;

AlignBehavior = MasterAlignInfo.AlignBehavior;
PreAlignTime = MasterAlignInfo.PreAlignTime;
PostAlignTime = MasterAlignInfo.PostAlignTime;
TraceLength = (PreAlignTime+PostAlignTime)*1000+1;
Licking = zeros(NumOfTrials,TraceLength);
for TrNum=1:NumOfTrials
    PokeIndex= floor((bhv_data.lick{TrNum}-TimeStamps(TrNum,CueOn)+PreAlignTime)*1000)+1;
    Licking(TrNum,PokeIndex(find(PokeIndex>0)))=1;
end
Licking(:,TraceLength+1:end)=[];
%% Costruct Targets
% Each row represents the single trial spatial and temporal target
% information.
if ~nnz(strcmp(varargin,'BMI'))
    TargetsColumnInfo={'TargetIndex', 'BaseX' 'BaseY' 'TargetDistance', 'TargetTheta1','TargetTheta2','ResponseTimeWindow','SuccessCode'};
    for i=1:size(TargetsColumnInfo,2)
        eval([TargetsColumnInfo{i} '=' num2str(i) ';']);
    end
    Targets = NaN*ones(NumOfTrials,numel(TargetsColumnInfo));
    Targets(:,TargetIndex) = bhv_data.target(1:NumOfTrials,1);
    Targets(:,[BaseX]) = joy_data.base(1);
    Targets(:,[BaseY]) = joy_data.base(2);
    Targets(:,TargetDistance) = joy_data.target.distance;
    Targets(:,[TargetTheta1 TargetTheta2]) = joy_data.target.theta.limits(mod(Targets(1:NumOfTrials,TargetIndex)-1,2)+1,:);
    Targets(:,ResponseTimeWindow) = bhv_data.response_time(1:NumOfTrials);
    Targets(:,SuccessCode) = bhv_data.reward_logical(1:NumOfTrials); % if success =1, fail = 0;
  
    %% Lowpass filter joystick position x and y
    [num,den] = besself(10,2*pi*100);  % 10th order Bessel analog low pass filter coefficients, with the cutoff at 100 Hz
    [B,A] = bilinear (num, den, 1000); % Analog to Digital mapping, 12 sample group delay.
    FilterDelay = 12;
    
    joy_x = filter(B,A,joy_data.x,[],1);
    LowPassJoyX = joy_x(FilterDelay+1:end);
    
    joy_y = filter(B,A,joy_data.y,[],1);
    LowPassJoyY = joy_y(FilterDelay+1:end);
    %% Construct JoyXY (NumOfTrials X TimeLength X 2)
    % Each row represents the x or y vector, aligned to cue onset.
    % Position at cue onset is at the index of (PreAlignTime*1000+1).
    % LowPassJoyXY(:,:,1) is for the x data, and LowPassJoyXY(:,:,2) is for the y data.
    % Here, LowPassJoyXY is currently in volts, but will be transformed into radian using scaling factors.
    LowPassJoyXY = NaN*ones(NumOfTrials,TraceLength,2);
    for TrNum=1:NumOfTrials
        BitArriveTime = joy_data.bitcode(find(joy_data.bitcode(:,1)==TrNum),2);
        if ~isempty(BitArriveTime)
            if length(BitArriveTime)>1
                disp(['Warning: more than one trials for bitcode ' num2str(TrNum)]);
                BitArriveTime = BitArriveTime(1);
            end
            TrialBeginTime = BitArriveTime + TimeStamps(TrNum,AlignBehavior)-PreAlignTime-TimeStamps(TrNum,BitSent);
            IndexInterval = floor(TrialBeginTime*1000)+[1:TraceLength];
            EndIndexOfData = length(LowPassJoyX);
            if IndexInterval(1)<1
                LowPassJoyXY(TrNum, (end-IndexInterval(end)+1):end,1) = LowPassJoyX(1:IndexInterval(end));
                LowPassJoyXY(TrNum, (end-IndexInterval(end)+1):end,2) = LowPassJoyY(1:IndexInterval(end));
            elseif IndexInterval(end)<=EndIndexOfData
                LowPassJoyXY(TrNum,:,1) = LowPassJoyX(IndexInterval);
                LowPassJoyXY(TrNum,:,2) = LowPassJoyY(IndexInterval);
            else
                LowPassJoyXY(TrNum, 1:(EndIndexOfData-IndexInterval(1)+1),1) = LowPassJoyX(IndexInterval(1):EndIndexOfData);
                LowPassJoyXY(TrNum, 1:(EndIndexOfData-IndexInterval(1)+1),2) = LowPassJoyY(IndexInterval(1):EndIndexOfData);
            end
        else
            disp(['Warning: bitcode for' num2str(TrNum) ' is missing']);
        end
    end    
    
    %% Throw away the first trial, trials without bitcode information, or ignored trials in the end of session
    % Task engagement is determined by whether joystick during response period
    % left the initial hold zone.
    TaskEngaged = zeros(NumOfTrials,1);
    AlignBhv = MasterAlignInfo.AlignBehavior;
    IndexOffset = MasterAlignInfo.PreAlignTime*1000+1;
    InitialHoldZoneWindow = 0.03;
    for trial=1:NumOfTrials
        CueOnIndex = floor((TimeStamps(trial,CueOn)-TimeStamps(trial,AlignBhv))*1000)+IndexOffset;
        ResponseOffIndex = floor((TimeStamps(trial,ResponseOff)-TimeStamps(trial,AlignBhv))*1000)+IndexOffset; % This will be when the movement entered the correct target or endof response period
        ResponsePeriod = [CueOnIndex:1:min(ResponseOffIndex, size(LowPassJoyXY,2))]; % Period from GoCue to ResponseOff sec
        if ~isempty(ResponsePeriod)
            JoyXYInResponsePeriod = LowPassJoyXY(trial,ResponsePeriod,:);
            TranslationFromBase = squeeze(LowPassJoyXY(trial,ResponsePeriod,:)) - repmat(Targets(trial,[BaseX BaseY]),[length(ResponsePeriod),1]);
            [Orientation DistanceFromBase]= cart2pol(TranslationFromBase(:,1),TranslationFromBase(:,2));
            TaskEngaged(trial) = nnz(DistanceFromBase > InitialHoldZoneWindow)>0; % Left the initial zone after GoCue?
        else
            TaskEngaged(trial)=1;% Early response trials missing GoCue are considered to be engaged
        end
    end
    FirstTaskEngagedTrial = find(TaskEngaged(2:end),1,'first')+1;
    LastTaskEngagedTrial = find(TaskEngaged,1,'last');
    TaskEngagedTrials = [FirstTaskEngagedTrial:LastTaskEngagedTrial];
    TaskEngagedTrials = intersect(TaskEngagedTrials, find(~isnan(TimeStamps(:,BitSent)) & ~isempty(TimeStamps(:,BitSent))));
    
    TimeStamps = TimeStamps(TaskEngagedTrials,:);
    Targets = Targets(TaskEngagedTrials,:);
    Licking = Licking(TaskEngagedTrials,:);
    LowPassJoyXY = LowPassJoyXY(TaskEngagedTrials,:,:);
end

%% Save the combined data as a single file.

if ~nnz(strcmp(varargin,'BMI'))
        save(TempfileName,'TimeStamps','Targets','LowPassJoyX','LowPassJoyY','LowPassJoyXY','MasterAlignInfo','TimeStampsColumnInfo','TargetsColumnInfo','SessionType','SessionDate','Licking','Protocol');
else
        save(TempfileName,'TimeStamps','TimeStampsColumnInfo','SessionType','SessionDate','Licking');
end


