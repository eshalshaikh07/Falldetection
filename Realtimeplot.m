% Set up the serial port object using serialport (use correct port name and baud rate)
serialPort = serialport('COM7', 115200);  % Replace 'COM7' with your actual port

% Initialize figure with two subplots
figure;

% Subplot 1: Pitch data
subplot(2, 1, 1);
hold on;
xlabel('Time (s)', 'FontSize', 12);
ylabel('Pitch Angle (°)', 'FontSize', 12);
title('Pitch Monitoring', 'FontSize', 14, 'FontWeight', 'bold');
grid minor;

% Highlight acceptable range for pitch
acceptableRangePitch = fill([0, 50, 50, 0], [-5, -5, 5, 5], [0.9, 0.9, 0.9], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.3);

baselinePlotPitch = plot(NaN, NaN, 'r-', 'LineWidth', 2);  % Red line for baseline pitch
realTimePlotPitch = plot(NaN, NaN, 'b-', 'LineWidth', 1);  % Blue line for real-time pitch data

% Subplot 2: Roll data
subplot(2, 1, 2);
hold on;
xlabel('Time (s)', 'FontSize', 12);
ylabel('Roll Angle (°)', 'FontSize', 12);
title('Roll Monitoring', 'FontSize', 14, 'FontWeight', 'bold');
grid minor;

% Highlight acceptable range for roll
acceptableRangeRoll = fill([0, 50, 50, 0], [-5, -5, 5, 5], [0.9, 0.9, 0.9], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.3);

baselinePlotRoll = plot(NaN, NaN, 'g-', 'LineWidth', 2);   % Green line for baseline roll
realTimePlotRoll = plot(NaN, NaN, 'm-', 'LineWidth', 1);   % Magenta line for real-time roll data

% Initialize arrays for time, pitch, and roll data
timeData = [];
pitchData = [];
rollData = [];

% Initialize baseline values (to be received)
baselinePitch = NaN;
baselineRoll = NaN;

% Set the deviation threshold for incorrect posture
deviationThreshold = 15;  % Degrees, adjust for larger deviations

% Flag to check if baseline has been initialized
baselineInitialized = false;

% Loop for real-time data processing
while true
    % Check if data is available on the serial port
    if serialPort.NumBytesAvailable > 0
        data = readline(serialPort);  % Read a line from the serial port
        disp(['Received: ', data]);
        
        % Parse baseline data (only the first time it is received)
        if contains(data, 'MATLAB_BASELINE') && ~baselineInitialized
            tokens = regexp(data, 'MATLAB_BASELINE Timestamp=(\d+) Pitch=(-?\d+\.\d+) Roll=(-?\d+\.\d+)', 'tokens');
            if ~isempty(tokens)
                baselinePitch = str2double(tokens{1}{2});
                baselineRoll = str2double(tokens{1}{3});
                disp(['Baseline - Pitch: ', num2str(baselinePitch), ', Roll: ', num2str(baselineRoll)]);
                
                % Set the baselineInitialized flag to true after initialization
                baselineInitialized = true;
            end
        end
        
        % Parse real-time data
        if contains(data, 'MATLAB_DATA') && baselineInitialized
            tokens = regexp(data, 'MATLAB_DATA Timestamp=(\d+) Pitch=(-?\d+\.\d+) Roll=(-?\d+\.\d+)(?: AccelX=(-?\d+\.\d+) AccelY=(-?\d+\.\d+) AccelZ=(-?\d+\.\d+))?(?: GyroX=(-?\d+\.\d+) GyroY=(-?\d+\.\d+) GyroZ=(-?\d+\.\d+))?', 'tokens');
            if ~isempty(tokens)
                timestamp = str2double(tokens{1}{1}) / 1000;  % Convert to seconds
                pitch = str2double(tokens{1}{2});
                roll = str2double(tokens{1}{3});
                
                % Append data for plotting
                timeData = [timeData, timestamp];
                pitchData = [pitchData, pitch];
                rollData = [rollData, roll];
                
                % Check if accelerometer data is available
                if length(tokens{1}) >= 6
                    accelX = str2double(tokens{1}{4});
                    accelY = str2double(tokens{1}{5});
                    accelZ = str2double(tokens{1}{6});
                    
                    % Log raw accelerometer data
                    disp(['Raw Accel: ', num2str(accelX), ', ', num2str(accelY), ', ', num2str(accelZ)]);
                    
                    % Compute the total acceleration magnitude
                    acceleration = sqrt(accelX^2 + accelY^2 + accelZ^2);  % Total acceleration
                    
                    % Detect a sudden peak in acceleration (e.g., fall impact)
                    if acceleration > 15  % Set threshold for detecting fall (adjust as needed)
                        disp('Fall detected!');
                    end
                end
                
                % Check if gyroscope data is available
                if length(tokens{1}) >= 9
                    gyroX = str2double(tokens{1}{7});
                    gyroY = str2double(tokens{1}{8});
                    gyroZ = str2double(tokens{1}{9});
                    
                    % Log raw gyroscope data
                    disp(['Raw Gyro: ', num2str(gyroX), ', ', num2str(gyroY), ', ', num2str(gyroZ)]);
                end
                
                % Apply noise reduction using moving average (optional for smoother graphs)
                if length(pitchData) > 5
                    pitchData = movmean(pitchData, 5);  % Smoothing pitch data
                end
                if length(rollData) > 5
                    rollData = movmean(rollData, 5);  % Smoothing roll data
                end
                
                % Calculate deviations from baseline
                pitchDeviation = abs(pitch - baselinePitch);
                rollDeviation = abs(roll - baselineRoll);
                
                % Update the plots for pitch
                subplot(2, 1, 1);  % Activate the first subplot (Pitch)
                set(realTimePlotPitch, 'XData', timeData, 'YData', pitchData);  % Update pitch data plot
                set(baselinePlotPitch, 'XData', [timeData(1), timeData(end)], ...
                    'YData', [baselinePitch, baselinePitch]); % Keep baseline pitch constant
                
                % Update the plots for roll
                subplot(2, 1, 2);  % Activate the second subplot (Roll)
                set(realTimePlotRoll, 'XData', timeData, 'YData', rollData);    % Update roll data plot
                set(baselinePlotRoll, 'XData', [timeData(1), timeData(end)], ...
                    'YData', [baselineRoll, baselineRoll]); % Keep baseline roll constant
                
                % Highlight deviations for pitch
                if pitchDeviation > deviationThreshold
                    set(realTimePlotPitch, 'Color', 'b');  % Change color to red for large deviation
                else
                    set(realTimePlotPitch, 'Color', 'b');  % Revert to blue when not deviating
                end
                
                % Highlight deviations for roll
                if rollDeviation > deviationThreshold
                    set(realTimePlotRoll, 'Color', 'r');   % Change color to red for large deviation
                else
                    set(realTimePlotRoll, 'Color', 'm');   % Revert to magenta when not deviating
                end
                
                % Dynamically adjust axis limits after drop impact
                subplot(2, 1, 1);  % Pitch subplot
                ylim([min(pitchData) - 10, max(pitchData) + 10]);  % Adjust Y-axis dynamically
                
                subplot(2, 1, 2);  % Roll subplot
                ylim([min(rollData) - 10, max(rollData) + 10]);  % Adjust Y-axis dynamically
                
                % Adjust axis limits dynamically for better focus
                subplot(2, 1, 1);  % Pitch subplot
                xlim([max(0, timeData(end) - 20), timeData(end)]);  % Show last 20 seconds
                ylim([baselinePitch - 15, baselinePitch + 15]);
                
                subplot(2, 1, 2);  % Roll subplot
                xlim([max(0, timeData(end) - 20), timeData(end)]);  % Show last 20 seconds
                ylim([baselineRoll - 15, baselineRoll + 15]);
                
                drawnow;
            end
        end
    end
end

% Close the serial port once done
clear serialPort;
