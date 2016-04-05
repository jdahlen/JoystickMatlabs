


function person = GetPeople(animal)


initials = {'AH','EH','JD','LM','MM'};
people = {'Andree','EunJung','Jeffrey','Luca','Madan'};
person = [];
for p = 1:length(people)

    if ~isempty(findstr(initials{p},animal))
        person = people{p};
        break
    end
    
end

if isempty(person)
    msg = ['Unknown experimenter from animal ' animal];
    error(msg);
end