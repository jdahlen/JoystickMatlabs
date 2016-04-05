% Revision History
% 
% 131126JED - Added 'slash' contingency to allow computing on unix and
% windows machines.
% 131213EJH = 1) Save mat file version 7.3 or later. 


function ComputeKinematicsV2(filename)

% slash = '/';
% 
% disp(['Computing Kinematics ' animal_name '-day' num2str(day) ' Data']);
% filelist = dir([MyPath 'Combined/' animal_name slash animal_name '-day' num2str(day) '-Combined*']);
% filename = [MyPath 'Combined/' animal_name slash filelist(1).name];
load(filename,'LowPassJoyXY','SessionType','SessionDate','TargetsColumnInfo','Targets','MasterAlignInfo','TimeStamps','TimeStampsColumnInfo'); 
%% Reveal the column index for each event or task information in TimeStamps and Targets
% This routine allows to access behavioral event markers or target properties
% using their name without memorizing their corresponding column indices.
for i=1:size(TimeStampsColumnInfo,2)
    eval([TimeStampsColumnInfo{i} '=' num2str(i) ';']);
end
for i=1:size(TargetsColumnInfo,2)
    eval([TargetsColumnInfo{i} '=' num2str(i) ';']);
end

%% Compute the speed of joystick movements
% Simple difference based speed calcuation and smoothing.
SmoothingWindow = 11; % in Smoothing over 11 ms
SpeedJoyXY = sqrt(sum(diff(LowPassJoyXY,1,2).^2,3))/0.001; 
SpeedJoyXY = SmoothMatrixRows(SpeedJoyXY,SmoothingWindow); % Smooth the angular speed

%% Movement onset detection
% Detect the movement onset since GoCue using the speed information and compute the reaction time.
CueTimes = TimeStamps(:,CueOn);
CueOnIndices = floor((CueTimes-TimeStamps(:,MasterAlignInfo.AlignBehavior)+MasterAlignInfo.PreAlignTime)*1000)+1;
GoCueTimes = TimeStamps(:,GoCue);
GoCueIndices = floor((GoCueTimes-TimeStamps(:,MasterAlignInfo.AlignBehavior)+MasterAlignInfo.PreAlignTime)*1000)+1;
ResponseOffIndices = floor((TimeStamps(:,ResponseOff)-TimeStamps(:,MasterAlignInfo.AlignBehavior)+MasterAlignInfo.PreAlignTime)*1000)+1;

TaskName=WhatIsTaskName(SessionType,SessionDate);
if isempty(strfind(TaskName{1},'ER')) & isempty(strfind(TaskName{1},'Multi'))
    MagnetReleaseIndices = GoCueIndices;
    MagnetReleaseTimes = GoCueTimes;
else
    MagnetReleaseIndices = CueOnIndices;
    MagnetReleaseTimes = CueTimes;
end

Bases = Targets(1,[BaseX BaseY]);

[MovementOnset, SpeedRisingTime] = DetectMovementOnset(LowPassJoyXY,SpeedJoyXY, MagnetReleaseIndices,MagnetReleaseTimes,Bases); % Movement onset detection changed 140602 so that it detects onset since CueOn

TimeStamps(:,MoveOn) = MovementOnset;
TimeStamps(:,SpeedRising) = SpeedRisingTime;
Kinematics.ReactionTime = TimeStamps(:,MoveOn)-TimeStamps(:,GoCue);
% Kinematics.ReactionTime2 = TimeStamps(:,SpeedRising)-TimeStamps(:,GoCue);
% Kinematics.RT2Cue = TimeStamps(:,CueOff)-TimeStamps(:,CueOn)+ ~isnan(Kinematics.ReactionTime).*Kinematics.ReactionTime;

%% Movement classification
% Determine the time a movement enters the target zone and classify the
% type of movement
UniqueTargets = unique(Targets(:,[TargetDistance TargetTheta1 TargetTheta2]),'rows');
if size(UniqueTargets,1)==2
    UniqueTargets(1,2) = pi/2-(UniqueTargets(1,3)-pi/2);
    UniqueTargets(2,3) = pi + (pi-UniqueTargets(2,2));
end
CenterAngles = mean(UniqueTargets(:,2:3),2);
TargetIDs = mod(Targets(:,TargetIndex)-1,2)+1;
RewardInfo = Targets(:,SuccessCode);
StraightVectors = [cos(CenterAngles(TargetIDs)) sin(CenterAngles(TargetIDs))];


[MovementClass, JeffMovementClass, TargetEnterTime] = ClassifyMovements(LowPassJoyXY,SpeedJoyXY,MagnetReleaseIndices,MagnetReleaseTimes,ResponseOffIndices,UniqueTargets, Bases, TargetIDs,RewardInfo);

TimeStamps(:,TargetEnter) = TargetEnterTime ;
Kinematics.MovementClass = MovementClass;
Kinematics.JeffMovementClass = JeffMovementClass;
Kinematics.Performance = ones(size(JeffMovementClass)).*(JeffMovementClass==1 | JeffMovementClass==2);
Kinematics.Engaged = ones(size(JeffMovementClass)).*(JeffMovementClass<=5 | JeffMovementClass>=7);
Kinematics.HoldPerformance = ones(size(JeffMovementClass)).*(JeffMovementClass<=5);
Kinematics.TargetAcquireTime = TimeStamps(:,TargetEnter)-TimeStamps(:,GoCue);
Kinematics.MovementTime = Kinematics.TargetAcquireTime-Kinematics.ReactionTime;

%% Peakvelocity, angular error, and pathlength calculation
% DESCRIPTIVE TEXT
MoveOnTimes = TimeStamps(:,MoveOn);
MoveOnIndices = floor((MoveOnTimes-TimeStamps(:,MasterAlignInfo.AlignBehavior)+MasterAlignInfo.PreAlignTime)*1000)+1;
SpeedRisingIndices =  floor((TimeStamps(:,SpeedRising)-TimeStamps(:,MasterAlignInfo.AlignBehavior)+MasterAlignInfo.PreAlignTime)*1000)+1;
TargetEnterIndices = floor((TimeStamps(:,TargetEnter)-TimeStamps(:,MasterAlignInfo.AlignBehavior)+MasterAlignInfo.PreAlignTime)*1000)+1;

[PeakVelocity, PeakVelocityTime, AngularError, PathLength] = ComputePeakVelocity(LowPassJoyXY,SpeedJoyXY,MoveOnIndices,TargetEnterIndices,SpeedRisingIndices,MoveOnTimes,StraightVectors);

TimeStamps(:,VelPeak) = PeakVelocityTime;
Kinematics.PeakVelocity = PeakVelocity;
Kinematics.AngularError = AngularError;
Kinematics.PathLength = PathLength;

%% Save computed kinematics data
% DESCRIPTIVE TEXT
save(filename,'SpeedJoyXY','TimeStamps','Kinematics','-append','-v7.3');


%% Function detecting movement onset
% DESCRIPTIVE TEXT
function [MovementOnset, SpeedRisingTime] = DetectMovementOnset(LowPassJoyXY,SpeedJoyXY,CueOnIndices,CueTimes,Base)
NumOfTrials = size(LowPassJoyXY,1);
MovementOnset = NaN*ones(NumOfTrials,1);
SpeedRisingTime = NaN*ones(NumOfTrials,1);
SpeedThreshold = 0.5;% rad/sec
MinimumMoveOnDuration = 20; % Movement speed should exceed SpeedThreshold continuously for at least 20 ms
MinimumDisplacement = 0.02; % rad
InitialHoldZoneWindow = 0.03;
for trial=1:NumOfTrials
    CueIndex = CueOnIndices(trial);    
    if ~isnan(CueIndex)
        
        DistanceFromBase = sqrt(squeeze(LowPassJoyXY(trial,CueIndex:end,1)-Base(1)).^2+squeeze(LowPassJoyXY(trial,CueIndex:end,2)-Base(2)).^2);

        Moving = cumsum(SpeedJoyXY(trial,CueIndex:end)>SpeedThreshold,2);
        MovOnsetIndex = find((Moving((MinimumMoveOnDuration+1):end)-Moving(1:(end-MinimumMoveOnDuration)))>=(MinimumMoveOnDuration-1)...
            & DistanceFromBase(1:(end-MinimumMoveOnDuration-1))>InitialHoldZoneWindow,1,'first');
        if ~isempty(MovOnsetIndex)
            MovementOnset(trial) = (MovOnsetIndex-1)/1000 + CueTimes(trial);
            DistanceFromOnset = sqrt((LowPassJoyXY(trial,CueIndex+MovOnsetIndex-1:end,1)-LowPassJoyXY(trial,CueIndex+MovOnsetIndex-1,1)).^2+...
                (LowPassJoyXY(trial,CueIndex+MovOnsetIndex-1:end,2)-LowPassJoyXY(trial,CueIndex+MovOnsetIndex-1,2)).^2);
            SpeedRisingPoint = find(DistanceFromOnset>MinimumDisplacement,1,'first');
            if ~isempty(SpeedRisingPoint)
                SpeedRisingTime(trial) = MovementOnset(trial) + (SpeedRisingPoint-1)/1000;
%                 MovementOnset(trial) = SpeedRisingTime(trial)-0.01; %140601
            end
        end
    end
end


%%Function computing peak velocity, angular error, and path length
function [PeakVelocity, PeakVelocityTime, AngularError, PathLength, PD] = ComputePeakVelocity(LowPassJoyXY,SpeedJoyXY,MoveOnIndices,TargetEnterIndices,SpeedRisingIndices,MoveOnTimes,StraightVectors)
NumOfTrials = size(LowPassJoyXY,1);
PeakVelocity = NaN*ones(NumOfTrials,1);
PeakVelocityTime = NaN*ones(NumOfTrials,1);
AngularError = NaN*ones(NumOfTrials,1);
PathLength = NaN*ones(NumOfTrials,1);

for trial=1:NumOfTrials
    MoveOnIndex = MoveOnIndices(trial);
    TargetEnterIndex = TargetEnterIndices(trial);
    if ~isnan(TargetEnterIndex) & ~isnan(MoveOnIndex) & TargetEnterIndex > MoveOnIndex
        MovementPeriod = [MoveOnIndex:TargetEnterIndex];
        JoyXYInMovementPeriod = squeeze(LowPassJoyXY(trial,MovementPeriod,:));
        [PeakVel PeakIndex] = max(SpeedJoyXY(trial,MovementPeriod));
        PeakVelocity(trial) = PeakVel;
        PeakVelocityTime(trial) = (PeakIndex-1)/1000 + MoveOnTimes(trial);
        PathLength(trial) = sum(SpeedJoyXY(trial,MovementPeriod),2)*0.001;
                
        SmoothJoyXYInMovementPeriod=[];
        for column=1:2
            SmoothJoyXYInMovementPeriod(:,column) = smooth(JoyXYInMovementPeriod(:,column),100);
        end
        SmoothVel = -diff(SmoothJoyXYInMovementPeriod)/0.001;
        SmoothSpeed = sqrt(SmoothVel(:,1).^2+SmoothVel(:,2).^2);
        SmoothSpeed = SmoothSpeed.*(SmoothSpeed>0.0005/0.001);
        PathLength(trial) = sum(SmoothSpeed)*0.001;

        PositionAtMoveOnset = JoyXYInMovementPeriod(1,:);
        StraightLineToEndpoint = JoyXYInMovementPeriod(end,:)-PositionAtMoveOnset;
        StraightLineToEndpoint = StraightVectors(trial,:);
        SpeedRisingIndex = SpeedRisingIndices(trial);
        
        if SpeedRisingIndex-MoveOnIndex >0 & SpeedRisingIndex-MoveOnIndex <=size(JoyXYInMovementPeriod,1)
            LineToSpeedRising = JoyXYInMovementPeriod(SpeedRisingIndex-MoveOnIndex,:)-PositionAtMoveOnset;
        else
            LineToSpeedRising =[];
        end
        
        if ~isempty(LineToSpeedRising)
            if norm(LineToSpeedRising)>0 & norm(StraightLineToEndpoint)>0
                AngularError(trial) = acos((StraightLineToEndpoint*LineToSpeedRising')/norm(StraightLineToEndpoint)/norm(LineToSpeedRising))...
                    *180/pi;
            end
        end
    end
end
    

%% Classify movements based on their path characteristic & Draw movement paths
function [MovementClass, JeffMovementClass, TargetEnterTime] = ClassifyMovements(LowPassJoyXY,SpeedJoyXY,MagnetReleaseIndices,MagnetReleaseTimes,ResponseOffIndices,UniqueTargets, Bases, TargetIDs, RewardInfo);
% Six factors are considered whetherthe movement:
% 1) was within the initial hold zone at the time of GoCue,
% 2) left the initial zone,
% 3) entered the correct target zone,
% 4) stayed in the correct target zone,
% 5) entered the wrong target zone after the correct target zone,
% 6) entered a wrong target zone before entering the correct target zone.
%
% Each factor was encoded using the binary code such that movement
% class is a six bit number with factor 1 being the highest bit. e.g.)
% 32 (1 0 0 0 0 0) within the initial hold zone, but did not leave the initial hold zone
% 48 (1 1 0 0 0 0) within the initial zone, moved but did not enter any target zone
% 49 (1 1 0 0 0 1) within the initial zone, entered a wrong target
% 56 (1 1 1 0 0 0) within the inizial zone, straightly entered the target,and exited
% 58 (1 1 1 0 1 0) within the inizial zone, straightly entered the target,the exited and entered a wrong target
% 60 (1 1 1 1 0 0) within the initial zone, straightly entered and stayed in the correct target zone
%
% [0 16 17 24 25 26 27 28 29] are the same as the above except the movement
% started outside the initial hold zone.
% If a trial was rewarded, add 100 to this code.
NumOfTrials = size(LowPassJoyXY,1);
MovementClass = zeros(NumOfTrials,1);
JeffMovementClass = zeros(NumOfTrials,1);
TargetEnterTime = NaN*ones(NumOfTrials,1);

InitialHoldZoneWindow = 0.03;
for trial=1:NumOfTrials
    MovClassBit = zeros(6,1);
    MagnetReleaseIndex = MagnetReleaseIndices(trial);
    
    if MagnetReleaseIndex>1000 & MagnetReleaseIndex<size(LowPassJoyXY,2)
        
        InitialHoldPeriod = MagnetReleaseIndex +[-999:0];
        
        DistanceFromBaseInHoldPeriod = sqrt(sum((squeeze(LowPassJoyXY(trial,InitialHoldPeriod,:)) - repmat(Bases,length(InitialHoldPeriod),1)).^2,2));
        
        ResponseOffIndex = ResponseOffIndices(trial);
        if ~isnan(ResponseOffIndex)
            ResponsePeriod = [MagnetReleaseIndex:1:min(ResponseOffIndex + 1*1000, size(LowPassJoyXY,2))]; % Period from GoCue to (ResponseOff+1) sec
        else
            ResponsePeriod = MagnetReleaseIndex+[0:1:4*1000];
        end
        JoyXYInResponsePeriod = LowPassJoyXY(trial,ResponsePeriod,:);
        TranslationFromBase = squeeze(LowPassJoyXY(trial,ResponsePeriod,:)) - repmat(Bases,[length(ResponsePeriod),1]);
        [Orientation DistanceFromBase]= cart2pol(TranslationFromBase(:,1),TranslationFromBase(:,2));
        Orientation = mod(Orientation,2*pi); % Force orientaion to be between 0 and 2*pi
        
        InTargetZones = zeros(size(Orientation,1),size(UniqueTargets,1)); % InTargetZones indicate whether movement is within each target zone at each time
        for target=1:size(UniqueTargets,1)
            InTargetZones(:,target) = DistanceFromBase>=UniqueTargets(target,1) & Orientation>=UniqueTargets(target,2) & Orientation<=UniqueTargets(target,3);
        end
        InCorrectTarget = InTargetZones(:,TargetIDs(trial)); % Indicates whether movement at each timepoint is inside the correct target
        InOtherTargets = sum(InTargetZones(:,setdiff(1:size(UniqueTargets,1),TargetIDs(trial))),2); % Indicates whehter movement is inside wrong targets
        TargetEnterIndex = min([find(InCorrectTarget,1,'first'), find(InOtherTargets,1,'first')]);
        
        MovClassBit(1) = 1- nnz(DistanceFromBaseInHoldPeriod > InitialHoldZoneWindow)>0; % Within the initial hold zone during 1s before GoCue?
        MovClassBit(1) = 1; % Within the initial hold zone at least once before GoCue?
        MovClassBit(2) = nnz(DistanceFromBase > InitialHoldZoneWindow)>0; % Left the initial zone after GoCue?
        if isempty(TargetEnterIndex)
            MovClassBit(6) = 0;
        elseif TargetEnterIndex == find(InOtherTargets,1,'first')
            TargetEnterTime (trial) = TargetEnterIndex/1000+MagnetReleaseTimes(trial);
            MovClassBit(6) = 1;
        else
            TargetEnterTime (trial) = TargetEnterIndex/1000+MagnetReleaseTimes(trial);
            MovClassBit(3) = 1; % Entered the correct target zone
            MovClassBit(4) = nnz(~InCorrectTarget((TargetEnterIndex+1):end))==0;  % Stayed in the target zone for 3 sec
            MovClassBit(5) = nnz(InOtherTargets((TargetEnterIndex+1):end))>0; % Entered wrong target zones within 3 sec since entering the correct target zone
            MovClassBit(6) = 0;
        end
        % Entered wrong target zones before entering the correct target zone
        MovClassBit(7) = RewardInfo(trial);
        MovementClass(trial) = [2^5 2^4 2^3 2^2 2^1 2^0 100]*MovClassBit; % Transform the binaary code to an decimal number
        if isnan(ResponseOffIndex)
            MovementClass(trial) = MovementClass(trial) + 200;
        end
    end
end

% SpeedSamples = SpeedJoyXY(:,ResponsePeriod);
% disp(['95, 99, 99.5% speed:' num2str(quantile(SpeedSamples(:),.95)) ' ' num2str(quantile(SpeedSamples(:),.99)) ' ' num2str(quantile(SpeedSamples(:),.995))]);

%% Compute the movement class based on Jeff's categorization
% 1: Entered the correct target first and got rewarded
% 2: Entered the correct target first but did not get rewarded
% 3: Entered wrong targets first, then the correct target, and got rewarded
% 4: Entered wrong targets first, and did not get rewarded
% 5: Started within the initial hold zone, but did not reach any targets
% 6: Did not leave the initial window.
% 11,12,13,14,15,16 are the same as 1-6, but prematurely moved trials

MoveClassMap = zeros(362,1);
MoveClassMap([32 1:31 100:131]+1) = 6;
MoveClassMap([48 148]+1) = 5;
MoveClassMap([49]+1) = 4;
MoveClassMap([149]+1) = 3;
MoveClassMap([56 58 60]+1) = 2;
MoveClassMap([156 158 160]+1) = 1;

MoveClassMap([32 0:31 100:131]+201) = 16;
MoveClassMap([48 148]+201) = 15;
MoveClassMap([49]+201) = 14;
MoveClassMap([149]+201) = 13;
MoveClassMap([56 58 60]+201) = 12;
MoveClassMap([156 158 160]+201) = 11;

JeffMovementClass = MoveClassMap(MovementClass+1);

