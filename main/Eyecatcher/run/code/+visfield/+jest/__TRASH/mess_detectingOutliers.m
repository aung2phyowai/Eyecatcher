
x = [
        0   NaN   NaN   NaN     1     1   NaN   NaN   NaN     1
   NaN     0   NaN     1   NaN   NaN     1   NaN     1   NaN
   NaN   NaN     1   NaN     1     1   NaN     1   NaN   NaN
   NaN     0   NaN     1   NaN   NaN     1   NaN     1   NaN
     0   NaN     1   NaN   NaN   NaN   NaN     1   NaN     1
     1   NaN     1   NaN   NaN   NaN   NaN     1   NaN     1
   NaN     1   NaN     1   NaN   NaN     1   NaN     1   NaN
   NaN   NaN     1   NaN     1     1   NaN     1   NaN   NaN
   NaN     1   NaN     1   NaN   NaN     1   NaN     1   NaN
     1   NaN   NaN   NaN     1     1   NaN   NaN   NaN     1
     ]
 
 
 
idx = padarray(0, [1 1], 1); % ALT: = [1 1 1; 1 0 1; 1 1 1];

nSurroundingOn = (conv2(single(x==1), idx, 'same') .* (x==0)) >= 1




randsample(find(~isnan(x)),1)