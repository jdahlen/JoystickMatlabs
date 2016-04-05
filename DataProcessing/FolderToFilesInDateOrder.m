
%creates filenames from all files within a given folder

function complete_names = FolderToFilesInDateOrder(folder_path)

dir_names = dir(folder_path);

num_files = 1;
date_list= [];
for ii = 1:length(dir_names);
 
    if ~dir_names(ii).isdir
        
        file_names{num_files} = fullfile(folder_path,dir_names(ii).name);
        date_list(num_files) = dir_names(ii).datenum;
        num_files = num_files+1;
        
    end
    
end
[DatesInOrder, Indices]=sort(date_list);
complete_names = file_names(Indices);
    