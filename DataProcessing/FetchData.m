
function FetchData(AnimalName,varargin)
% Providing the AnimalName will fetch data from (and save to) the default 
% path <Z:\People\Person\MatlabJoystickData\>
% If you need to fetch, analyze kinematics, and save data of animal JD035 from all
% training sessions at 'E:\People\Jeff\JoystickData', use
% FetchData('JD035','DataFolder','Z:\People\Jeff\JoystickData')
% If you need to process only the latest session, use
% FetchDataDG('JD035','latest','DataFolder','Z:\People\Jeff\JoystickData')
% If you need to process days 5-7, use
% FetchDataDG('JD035','days',[5:7],'DataFolder','Z:\People\Jeff\JoystickData')
% If you do not want to specify 'DataFolder' every time, define your
% default data folder in the script below.
%
% 131002JED: This function pulls all of the data for a specific animal and
% concatenates it into two files:  JD000_bhv.mat, and JD000_joy.mat
% These files represent the dispatcher behavioral data and joystick data
% respectively.  They are automatically saved into my people folder on the
% server under their own designated animal name. 
% 
% 131021EH: the folder where raw data and crunched data are saved can
% be specified by using MyPath. After each session is fetched and crunched
% once, any post processing such as computing kinematics can be done using crunched data.
%

%% if no animal number is provided prompt it
if nargin<1 | isempty(AnimalName)
    AnimalName = input('Animal Number:','s');
    MyPath = ['Z:\People\' GetPeople(AnimalName) '\MatlabJoystickData\'];
end
if nnz(strcmp(varargin,'DataFolder'))
    PathStrIndex = find(strcmp(varargin,'DataFolder'))+1;    
    MyPath = varargin{PathStrIndex};
else
    MyPath = ['Z:\People\' GetPeople(AnimalName) '\MatlabJoystickData\'];
end

%% begin line
disp([AnimalName ' at ' MyPath])

Dispatcher_Folder = [MyPath 'Dispatcher/'  AnimalName '/'];
Joystick_Folder = [MyPath 'Joystick/' AnimalName '/'];
	
if numel(dir([Dispatcher_Folder '*.mat'])) ~= numel(dir([Joystick_Folder '*.mat']))% in case behavior or joystick files are missing for some days
    if nnz(strcmp(varargin,'BMI'))
        NumOfFiles = numel(dir([Dispatcher_Folder '*.mat']));
    else
        disp('The Number of Dispatcher and Joystick Files DO NOT match!');
        return
    end
else
    NumOfFiles = numel(dir([Dispatcher_Folder '*.mat'])); % in case behavior or joystick files are missing for some days
end

joystick_files = dir([Joystick_Folder '*.mat']);
bhv_files = dir([Dispatcher_Folder '*.mat']);
date_list=[];
for i=1:size(joystick_files)
    fname = joystick_files(i).name;
    date_list(i) = str2num(fname(1:6));
end
unique_days = unique(date_list);
NumOfDays = numel(unique_days);

if nnz(strcmp(varargin,'All'))| nnz(strcmp(varargin,'all')) % if only the latest session needs to be processed
    days = [1:NumOfDays];
elseif nnz(strcmp(varargin,'days')) % specify the days to process using this option
    DaysIndex = find(strcmp(varargin,'days'))+1;
    days = varargin{DaysIndex};
else % if days are not specified, process all days
    CrunchFile_Folder = [MyPath 'Combined/' AnimalName '/'];
    NumOfCombinedData = numel(dir([CrunchFile_Folder '*Combined*.mat']));
    days = [NumOfCombinedData+1:NumOfDays];
end
display(['Crunching ' num2str(days) 'th of ' num2str(NumOfDays) ' days']);

for day = days
    if nnz(strcmp(varargin,'BMI'))
        FetchBhvDG(AnimalName,day,MyPath);
        CrunchData(AnimalName,day,MyPath,'BMI');
    else
        file_indices = find(date_list==unique_days(day));
        
        TimeStamps=[];Targets=[];LowPassJoyXY=[];Licking=[];LowPassJoyX=[];LowPassJoyY=[];
        for i=1:numel(file_indices)
            ssn = file_indices(i);
            FetchJoyDG(AnimalName,ssn,MyPath);
            FetchBhvDG(AnimalName,ssn,MyPath);
            
            Joyfilename = [MyPath 'Combined/' AnimalName '/' AnimalName '-ssn' num2str(ssn) '-Joy.mat'];
            Bhvfilename = [MyPath 'Combined/' AnimalName '/' AnimalName '-ssn' num2str(ssn) '-Bhv.mat'];
            
            Tempfilename = [MyPath 'Temp/' AnimalName '-' 'temp' num2str(ssn)];
            if ~exist([MyPath 'Temp/']), mkdir(MyPath,'Temp'); end;
            CrunchData(Joyfilename,Bhvfilename,Tempfilename);
            data = load(Tempfilename);
            TimeStamps = [TimeStamps ; data.TimeStamps];
            Targets = [Targets; data.Targets];
            LowPassJoyXY = [LowPassJoyXY; data.LowPassJoyXY];
            Licking = [Licking;data.Licking];
            LowPassJoyX = [LowPassJoyX; data.LowPassJoyX];
            LowPassJoyY = [LowPassJoyY; data.LowPassJoyY];
            
            if i==numel(file_indices)
                MasterAlignInfo = data.MasterAlignInfo;
                TimeStampsColumnInfo = data.TimeStampsColumnInfo;
                TargetsColumnInfo = data.TargetsColumnInfo;
                SessionType = data.SessionType;
                SessionDate = data.SessionDate;
                Protocol = data.Protocol;
                
                Combinedfilename = [MyPath 'Combined/' AnimalName '/' AnimalName '-day' num2str(day) '-Combined-' num2str(unique_days(day)) '.mat'];
                if exist(Combinedfilename)
                    save(Combinedfilename,'TimeStamps','Targets','LowPassJoyX','LowPassJoyY','LowPassJoyXY','MasterAlignInfo','TimeStampsColumnInfo','TargetsColumnInfo','SessionType','SessionDate','Licking','Protocol','-append');
                else
                    save(Combinedfilename,'TimeStamps','Targets','LowPassJoyX','LowPassJoyY','LowPassJoyXY','MasterAlignInfo','TimeStampsColumnInfo','TargetsColumnInfo','SessionType','SessionDate','Licking','Protocol');
                end
            end
            delete(Joyfilename);
            delete(Bhvfilename);
        end        
        ComputeKinematicsV2(Combinedfilename);
        disp(' ');
        for i=1:numel(file_indices)
            ssn = file_indices(i);
            Tempfilename = [MyPath 'Temp/' AnimalName '-' 'temp' num2str(ssn) '.mat'];
            delete(Tempfilename);
        end
    end
end



