function TaskName = WhatIsTaskName(SessionType,date)
%% AllTasks
AllTasks{1}={'MultipleTargets' 'CuedMultipleTargets' 'EarlyReleaseCuedMultipleTargets' 'NoDiscrim'};
AllTasks{2}={'ErrorMultipleTargets' 'CuedErrorMultipleTargets' 'Discrim'};
AllTasks{3}={'DelayCuedErrorMultipleTargets' 'Memory'};
AllTasks{4}={'EarlyReleaseCuedErrorMultipleTargets' 'ERNoDiscrim'};
AllTasks{5}={'EarlyReleaseDiscrim' 'ERDiscrim'};
AllTasks{6}={'EarlyReleaseDelayCuedErrorMultipleTargets' 'ERMemory'};
if nargin<1
    TaskName=AllTasks;
    for i=1:numel(AllTasks)
        disp(AllTasks{i});
    end
end

if nargin>=1
    IsThisTask=[];
    for i=1:numel(AllTasks)
        IsThisTask(i)=length(find(strcmp(AllTasks{i},SessionType{1})))>0;
    end
    if ~isempty(find(IsThisTask))
        TaskName=AllTasks{find(IsThisTask)}(end);
    else
        TaskName=SessionType;
    end
    if strcmp(TaskName,'ERMemory') & str2num(date)<=140212
        TaskName={'CRMemory'};
    end
end
