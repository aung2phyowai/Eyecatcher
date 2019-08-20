function ColorCALIIZeroCalibrate(ColorCALIICDCPort)
% Calibrate zero-level, by which to adjust subsequent measurements by.
% ColorCAL II should be covered during this period so that no light can be
% detected.

    % Use the 'serial' function to assign a handle to the port ColorCAL II is
    % connected to. This handle (s1 in the current example) will then be used
    % to communicate with the chosen port).
    s1 = serial(ColorCALIICDCPort);

    % Open the ColorCAL II port so that it is open to be communicated with.
    % Communication with the ColorCAL II occurs as though it were a text file.
    % Therefore to open it, use fopen.
    fopen(s1);

    % Current status of the calibration success. This will be changed to 1 when
    % calibration is successful.
    calibrateSuccess = 0;

    % Continue trying until a calibration is successful.
    while calibrateSuccess == 0;

        % It can be useful to contain codes within 'try/catch' statements so that
        % if the code raises an error and aborts part way, the 'catch' can be used
        % to ensure any open ports are closed properly. Aborting the script without
        % closing the ports properly may prevent the port from being reopened again
        % in future. If this happens, just close and reopen MATLAB.
        try
            % Commands are passed to the ColorCAL II as though they were being
            % written to a text file, using fprintf. The command UZC will read
            % current light levels and store them in a zero correction array. All
            % subsequent light readings have this value subtracted from them before
            % being returned to the host. Note the '13' represents the terminator
            % character. 13 represents a carriage return and should be included at
            % the end of every command to indicate when a command is finished.
            fprintf(s1, ['UZC' 13]);

            % This command returns a blank character at the start of each line by
            % default that can confuse efforts to read the values. Therefore use
            % fscanf once to remove this character.
            fscanf(s1);

            % To read the returned data, use fscanf, as though reading from a text
            % file.
            dataLine = fscanf(s1);

            % The expected returned messag if successful is 'OKOO' or if an error,
            % 'ER11'. In case of any additional blank characters either side of
            % these messages, search through each character until either an O or an
            % E is found so that the start of the relevant message can be
            % determined.
            for k = 1:length(dataLine)

                % Once either an O or an E is found, the start of the relevant
                % information is the current character positiong while the end is 3
                % characters further (as each possible message is 4 characters in
                % total).
                if dataLine(k) == 'O' || dataLine(k) == 'E'
                    myStart = k;
                    myEnd = k+3;
                end
            end

            % the returned message is the characters between the start and end
            % positions.
            myMessage = dataLine(myStart:myEnd);

            % if the message is 'OK00', then report a successful calibration.
            if myMessage == 'OK00'
                disp('Zero-calibration successful');

                % calibration is successful. Changing calibrateSuccess to 1 will
                % break the while loop and allow the script to continue.
                calibrateSuccess = 1;

                % If an error message is returned, report an error, perhaps because
                % of too much residual light. Wait for a key press and then try
                % again. This while loop will continue until a success is returned.
            else
                disp('ERROR during zero-calibration. Perhaps too much light.')
                disp('Ensure sensor is covered and press any key to try again');
                pause
            end

            % If an error occurs and the script aborts early, ensure ports are
            % closed to make it easier to reopen it in the future.
        catch ME
            disp('Error');

            % use fclose to close a serial port, the same as though closing a text
            % file.
            fclose(s1);
        end

    end

    % use fclose to close a serial port, the same as though closing a text
    % file.
    fclose(s1);

end