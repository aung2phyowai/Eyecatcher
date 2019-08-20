function myCorrectionMatrix = getColorCALIICorrectionMatrix(ColorCALIICDCPort)
% Obtains the individual correction matrix for the ColorCAL II, to be used
% to translate measured readings to calibrated XYZ values

% Use the 'serial' function to assign a handle to the port ColorCAL II is
% connected to. This handle (s1 in the current example) will then be used
% to communicate with the chosen port).
s1 = serial(ColorCALIICDCPort);

% Open the ColorCAL II port so that it is open to be communicated with.
% Communication with the ColorCAL II occurs as though it were a text file.
% Therefore to open it, use fopen.
fopen(s1);

% It can be useful to contain codes within 'try/catch' statements so that
% if the code raises an error and aborts part way, the 'catch' can be used
% to ensure any open ports are closed properly. Aborting the script without
% closing the ports properly may prevent the port from being reopened again
% in future. If this happens, just close and reopen MATLAB.
try
    
    % Cycle through the 3 rows of the correction matrix.
    for j = 1:3
        
        % whichColumn is to indicate the column the current value is to be
        % written to.
        whichColumn = 1;
        
        % Commands are passed to the ColorCAL II as though they were being
        % written to a text file, using fprintf. The commands 'r01', 'r02'
        % and 'r03' will return the 1st, 2nd and 3rd rows of the correction
        % matrix respectively. Note the '13' represents the terminator
        % character. 13 represents a carriage return and should be included
        % at the end of every command to indicate when a command is
        % finished.
        fprintf(s1,['r0' num2str(j) 13]);
        
        % This command returns a blank character at the start of each line
        % by default that can confuse efforts to read the values. Therefore
        % use fscanf once to remove this character.
        fscanf(s1);
        
        % To read the returned data, use fscanf, as though reading from a
        % text file.
        dataLine = fscanf(s1);
        
        % The returned dataLine will be returned as a string of characters
        % in the form of 'OK00, 8053,52040,50642'. Therefore loop through
        % each character until a O is found to be sure of the start
        % position of the data.
        for k = 1:length(dataLine)
            
            % Once an O has been found, assign the start position of the
            % numbers to 5 characters beyond this (i.e. skipping the
            % 'OKOO,').
            if dataLine(k) == 'O'
                myStart = k+5;
                
                % A comma (,) indicates the start of a value. Therefore if
                % this is found, the value is the number formed of the next
                % 5 characters.
            elseif dataLine(k) == ','
                myEnd = k+5;
                
                % Using j to indicate the row position and whichColumn to
                % indicate the column position, convert the 5 characters to
                % a number and assign it to the relevant position.
                myCorrectionMatrix(j, whichColumn) = str2num(dataLine(myStart:myEnd));
                
                % reset myStart to k+6 (the first value of the next number)
                myStart = k+6;
                
                % Add 1 to the whichColumn value so that the next value
                % will be saved to the correct location.
                whichColumn = whichColumn + 1;
                
            end
        end
    end
    
    % If an error occurs and the script aborts early, ensure ports are
    % closed to make it easier to reopen it in the future.
catch ME
    disp('Error');
    
    % Use fclose to close a serial port, the same as though closing a text
    % file.
    fclose(s1);
end

% Values returned by the ColorCAL II are 10000 times larger than their
% actual value. Also, negative values have a further 50000 added to them.
% These transformations need to be reversed to get the actual values.

% The positions of myCorrectionMatrix with values greater than 50000 have
% 50000 subtracted from them and then converted to their equivalent
% negative value.
myCorrectionMatrix(myCorrectionMatrix > 50000) = 0 - (myCorrectionMatrix(myCorrectionMatrix > 50000) - 50000);

% All values are then divided by 10000 to give actual values.
myCorrectionMatrix = myCorrectionMatrix ./ 10000;

% use fclose to close a serial port, the same as though closing a text
% file.
fclose(s1);