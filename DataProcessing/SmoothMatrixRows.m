function Y = SmoothMatrixRows(X,SmoothingWindow)
%This function is faster than repeating "smooth" row by row as long as
%SmoothingWindow is short enough.
SmoothingWindow = 2*ceil(SmoothingWindow/2)-1;
HalfWindow = floor(SmoothingWindow/2);
A = 1; B = 1/SmoothingWindow*ones(1,SmoothingWindow); 
Y = NaN*ones(size(X));
Y1 = filter(B,A,X,[],2);
Y(:,(HalfWindow+1):(end-HalfWindow))=Y1(:,SmoothingWindow:end);

for column=1:HalfWindow
     FilterLength = 2*column-1;    
     Y(:,column) =  mean(X(:,1:FilterLength),2);
end
for column=1:HalfWindow
     FilterLength = 2*column-1;    
     Y(:,end-column+1) = mean(X(:,(end-FilterLength+1):end),2);
end

