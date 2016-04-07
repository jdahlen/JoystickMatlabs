% Revision History
%
% 131126JED - Added 'slash' contingency to allow computing on unix and
% windows machines.
% 131213EJH - Added conditional statements for missing field for BMI
% dispatcher and replaced zeros with NaNs for missing data values.

function FetchBhvDG(animal_num,session,MyPath)

% This function pulls the behavioral data from the dispatcher saved file.
% EH131003: This is the same as the original FetchBhvDG written by JD but save
% each session data separately so that concatenation across days can be
% done later as necessary.
warning off;

ftf_name = [MyPath 'Dispatcher/' animal_num];

bhv_filename = FolderToFilesInDateOrder(ftf_name);
if isempty(strfind(bhv_filename{session}, '_ASV'))
    disp(['Fetching ' animal_num '-session' num2str(session) ' Dispatcher Data:' bhv_filename{session}(end-10:end-5)]);
    
else
    disp(['Fetching ' animal_num '-session' num2str(session) ' Dispatcher Data:' bhv_filename{session}(end-17:end-12)]);
end


bhv = load(bhv_filename{session},'-MAT');
parsed_events = bhv.saved_history.ProtocolsSection_parsed_events;
data.experimenter = bhv.saved.SavingSection_experimenter;
%% bhv details
if isfield(bhv,'fname')
    data.fname = bhv.fname;
    data.animal = data.fname(end-13:end-8);
    data.date = data.fname(end-6:end-1);
else
    disp(['Filename is missing in the dispatcher file!']);
    data.fname = bhv_filename{session}(1:end-4);
    data.animal = data.fname(end-13:end-8);
    data.date = data.fname(end-6:end-1);
end

data.session_type = bhv.saved_history.SessionTypeSection_SessionType(2:end);
data.protocol_name = bhv.owner;
if isfield(bhv,'led_placement');
    data.led_placement = bhv.led_placement;
else
    data.led_placement = [];
end

if isfield(bhv.saved_history,'StimChoiceSection_TargetNum')
    data.target_num = bhv.saved_history.StimChoiceSection_TargetNum;
end

%% times section
data.iti_time = cell2mat(bhv.saved_history.TimesSection_iti_max);
%data.iti_time = data.iti_time(2:end); %EH: removing the first trial can be done later
data.iti_time = data.iti_time;

if isfield(bhv.saved_history,'TimesSection_error_iti')
    data.error_iti_time = cell2mat(bhv.saved_history.TimesSection_error_iti);
    data.error_iti_time = data.error_iti_time;
end

if isfield(bhv.saved_history,'TimesSection_response_time')
    data.response_time = cell2mat(bhv.saved_history.TimesSection_response_time);
    data.response_time = data.response_time;
end

data.cue_time = cell2mat(bhv.saved_history.TimesSection_cue_time);
data.cue_time = data.cue_time;

data.water_time = cell2mat(bhv.saved_history.TimesSection_water_time);
data.water_time = data.water_time;


%% dispatcher event times

%trial start
data.start = cellfun(@(x) x.states.state_0(1,2), parsed_events,'UniformOutput',0);
empty_ind = cellfun(@isempty, data.start);
data.start(empty_ind) = {NaN};
data.start = cell2mat(data.start);

%trial bitcode
data.bitcode = cellfun(@(x) x.states.bitcode, parsed_events,'UniformOutput',0);
empty_ind = cellfun(@isempty, data.bitcode);
data.bitcode(empty_ind) = {[NaN NaN]};
data.bitcode = cell2mat(data.bitcode);


%trial cue

data.cue = cellfun(@(x) x.states.cue, parsed_events,'UniformOutput',0);
empty_ind = cellfun(@isempty, data.cue);
data.cue(empty_ind) = {[NaN NaN]};
data.cue = cell2mat(data.cue);

if isfield(parsed_events{1}.states,'response')
    data.response = cellfun(@(x) x.states.response, parsed_events,'UniformOutput',0);
    empty_ind = cellfun(@isempty, data.response);
    data.response(empty_ind) = {[NaN NaN]};
    data.response = cell2mat(data.response);
end

%trial reward
data.reward = cellfun(@(x) x.states.reward, parsed_events,'UniformOutput',0);
data.reward_logical = [cellfun(@(x) ~isempty(x), data.reward)];
empty_ind = cellfun(@isempty, data.reward);
data.reward(empty_ind) = {[NaN NaN]};
data.reward = cell2mat(data.reward);




%     %trial reward (if reward)
%     data(session).reward = cellfun(@(x) x.states.reward, parsed_events(2:end),'UniformOutput',0);
%     %stop for a second and get a set of rewared trials indices
%     %create trial reward index - pre clip (_all)
%     data(session).reward_logical = [cellfun(@(x) ~isempty(x), data(session).reward)];
%     %continue with regular calculation
%     empty_ind = cellfun(@isempty, data(session).reward);
%     data(session).reward(empty_ind) = {[0 0]};
%     data(session).reward = cell2mat(data(session).reward);


%PUNISH STATE IS NOT IN ALL TRIALS, HAVE TO SELECT AND THEN CHECK IF ITS
%EMPTY I GUESS
data.error = cellfun(@(x) x.states.punish, parsed_events,'UniformOutput',0);
empty_ind = cellfun(@isempty, data.error);
data.error(empty_ind) = {[NaN NaN]};
data.error = cell2mat(data.error);
%     end


%trial iti
data.iti = cellfun(@(x) x.states.iti, parsed_events,'UniformOutput',0);
empty_ind = cellfun(@isempty, data.iti);
data.iti(empty_ind) = {[NaN NaN]};
data.iti = cell2mat(data.iti);

%trial end
data.end = cellfun(@(x) x.states.state_0(2,1), parsed_events,'UniformOutput',0);
empty_ind = cellfun(@isempty, data.end);
data.end(empty_ind) = {NaN};
data.end = cell2mat(data.end);


%% dispatcher input signals from joystick

% NOTE ON SETUP: C = lickport, L = error, R = reward

%reward input (rising edge)
data.reward_input = cellfun(@(x) x.pokes.R(:,1), parsed_events, 'UniformOutput',0);
empty_ind = cellfun(@isempty, data.reward_input);
data.reward_input(empty_ind) = {NaN};
data.reward_input = cell2mat(data.reward_input);

%error input (rising edge)
data.error_input = cellfun(@(x) x.pokes.L(:,1), parsed_events,'UniformOutput',0);
empty_ind = cellfun(@isempty, data.error_input);
data.error_input(empty_ind) = {NaN};
data.error_input = cell2mat(data.error_input);

%lick input (beam break only), leave as cell, has funny shape
data.lick = cellfun(@(x) x.pokes.C(:,1), parsed_events,'UniformOutput',0);


%record original number of trials, before clipping
%both clipped+adjusted should = orig
data.num_trials_all = length(parsed_events);

%record target locations
if isfield(bhv.saved_history,'StimChoiceSection_AppliedStim')
    data.target = cell2mat(bhv.saved_history.StimChoiceSection_AppliedStim);
    data.target = data.target;
    
    if length(data.target) ~= length(data.cue)
        data.target = data.target(1:end-1);
    end
end

bhv_data=data;
%% bhv_data are saved in "Combined" folder to be combined with joy_data later
if ~isdir([MyPath 'Combined/' animal_num '/']), mkdir([MyPath 'Combined/', animal_num]); end
filename = [MyPath 'Combined/' animal_num '/' animal_num '-ssn' num2str(session) '-Bhv'];
save(filename,'bhv_data');
%%


% cd(old_cd);

warning on;

