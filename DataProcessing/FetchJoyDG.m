function FetchJoyDG(animal_num,session,MyPath)
% Revision History
%
% 131003EH - This is the same as the original FetchJoyDG written by JD but save
% each session data separately so that concatenation across days can be
% done later as necessary.
%
% 131126JED - Added 'slash' contingency to allow computing on unix and
% windows machines.
% 
% 160405JED - added ReadBitCode(); RisingBinary(); FallingBinary();
% functions.

warning off;

ftf_name = [MyPath 'Joystick/' animal_num '/'];
SlashIndices = strfind(ftf_name,'/');
joy_filename = FolderToFilesInDateOrder(ftf_name);

disp(['Fetching ' animal_num '-session' num2str(session) ' Joystick Data:' joy_filename{session}(SlashIndices(end)+(1:6))]);


joy = load(joy_filename{session},'-MAT');

%% This will be removed once the dispatcher saving files are fixed.
if ~isfield(joy.props,'data')
    joy.props.data = joy.props.handles;
%     disp(['Joystick prop field data is replaced with handles']);
end
%% 

if isfield(joy.props.data,'base')
    data.base = joy.props.data.base;  % "base" is missing in props.data since 130925
elseif isfield(joy.props.data,'base_x');
    data.base = [joy.props.data.base_x joy.props.data.base_y];
else
    disp(['Joystick data base information missing: base set to zero']);
    data.base = [3.13 1.9789];
end

%get number of targets
if isfield(joy.props.data,'target_num')
data.target.num = joy.props.data.target_num;
elseif isfield(joy.props.data,'target_selection')
    data.target.num = numel(joy.props.data.target_selection);
end

if isfield(joy.props.data,'target_dist')
    data.target.distance = joy.props.data.target_dist;
else
    data.target.distance = joy.props.data.target_distance;
end

data.target.tolerance = joy.props.data.target_tolerance;
data.target.theta.principle = joy.props.data.theta_principle;
data.target.theta.limits = joy.props.data.theta_limits;
if ~isempty(cell2mat(strfind(fields(joy.props.data),'patch_x')))
    data.target.display.x = joy.props.data.patch_x; % patach_x/y are missing
    data.target.display.y = joy.props.data.patch_y; % in props.data
end
data.x = joy.x;
data.y = joy.y;

data.d = sqrt((joy.x-data.base(1)).^2+(joy.y-data.base(2)).^2);
data.bitcode_raw = joy.bitcode;
data.v_on_raw = joy.vstimon;
data.v_off_raw = joy.vstimoff;

data.bitcode = ReadBitCode(data.bitcode_raw);
data.v_on = RisingBinary(data.v_on_raw,2.5);
data.v_off = FallingBinary(data.v_on_raw,2.5);

joy_data=data;

%% joy_data are saved in "Combined" folder to be combined with bev_data later
if ~isdir([MyPath 'Combined/' animal_num '/']), mkdir([MyPath 'Combined/', animal_num]); end
filename = [MyPath 'Combined/' animal_num '/' animal_num '-ssn' num2str(session) '-Joy'];
save(filename,'joy_data');
%% 
warning on;

end


function TrialNumList = ReadBitCode(bitcode_trace)

trace = bitcode_trace;
samplerate = 1;%khz
ThresholdValue = 2;
BinaryThreshold = trace>ThresholdValue;
ShiftBinaryThreshold = [NaN; BinaryThreshold(1:end-1)];
BitCodeSignal = find(BinaryThreshold==1 & ShiftBinaryThreshold==0)/samplerate;

%pick the start signal
StartList = [];
TrialNumber = [];
bit = [0:11];
bit = fliplr(bit);
bit = 2.^bit;
for ii=1:length(BitCodeSignal)
    candidate = BitCodeSignal(ii);
    if isempty([find(BitCodeSignal>candidate-200 & BitCodeSignal<candidate)])
        StartList = [StartList; BitCodeSignal(ii)];
        bitcode = zeros(1,12);
        %BitCode 5ms
%         for i=1:12
%             if ~isempty(find(10*i-4+BitCodeSignal(ii)<BitCodeSignal & BitCodeSignal<10*i+6+BitCodeSignal(ii)))
%                 bitcode(i)=1;
%             end
%         end
        for i=1:12
            if ~isempty(find(10*i-2+BitCodeSignal(ii)<BitCodeSignal & BitCodeSignal<10*i+8+BitCodeSignal(ii)))
                bitcode(i)=1;
            end
        end

        TrialNumber = [TrialNumber; sum(bit.*bitcode)];
    end
end;

TrialNumList = [TrialNumber StartList/1000];

end

function [traceout] = RisingBinary(tracein,threshold)
BinaryThreshold = tracein>threshold;
ShiftBinaryThreshold = [NaN; BinaryThreshold(1:end-1)];
traceout = find(BinaryThreshold==1 & ShiftBinaryThreshold==0);
end

function [traceout] = FallingBinary(tracein,threshold)
BinaryThreshold = tracein>threshold;
ShiftBinaryThreshold = [BinaryThreshold(2:end); NaN];
traceout = find(BinaryThreshold==1 & ShiftBinaryThreshold==0);
end