%% Real-Time Audio Noise Classifier and Adaptive Filter System
% Integrated System (Module 1 + Module 2)
% Authors: Muhammad Qasim (2023488) & Muhammad Hammad (2023420)
% Department of Computer Engineering, GIKI
clc;
clear;
close all;

%% ========================================================================
%  MODULE 1: NOISE IDENTIFICATION
%  ========================================================================
disp('--------------------------------------------------');
disp('       MODULE 1: NOISE IDENTIFICATION SYSTEM      ');
disp('--------------------------------------------------');

% 1. SYSTEM CONFIGURATION
fs = 44100;
duration = 3; % Increased slightly for better analysis
nBits = 16;
nChannels = 1;

% 2. AUDIO ACQUISITION
recObj = audiorecorder(fs, nBits, nChannels);
disp(['>> Recording for ', num2str(duration), ' seconds']);
disp('>> ACTION: Make noise! (Hum, Fan, Speech, or Wind)');
recordblocking(recObj, duration);
disp('>> Recording Complete.');

% --- FIX 1: ROBUST INPUT NORMALIZATION ---
y_raw = getaudiodata(recObj);
y = y_raw - mean(y_raw);       % Remove DC offset

% Normalize Input to 0.9 (Prevent clipping but keep headroom)
max_val = max(abs(y));
if max_val > 0.0001
    input_signal = y / max_val * 0.9;
    disp(['>> Input Normalized. Peak Amplitude: ', num2str(max(abs(input_signal)))]);
else
    input_signal = y;
    disp('>> WARNING: Input is absolute silence.');
end

% 3. FEATURE EXTRACTION


% Frequency Domain Features
N = length(input_signal);
Y_fft = fft(input_signal);
P2 = abs(Y_fft/N);
P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2*P1(2:end-1);
f = fs*(0:(floor(N/2)))/N;

% C. Spectral Centroid
spectral_centroid = sum(f' .* P1) / sum(P1);

% D. Band Power Features
total_power = bandpower(input_signal, fs, [0, fs/2]);
power_hum   = bandpower(input_signal, fs, [45, 65]);     % 50/60Hz
power_low   = bandpower(input_signal, fs, [20, 250]);    % Rumble/Wind
power_mid   = bandpower(input_signal, fs, [300, 3400]);  % Voice Band

% 4. CLASSIFICATION LOGIC
ratio_hum = power_hum / total_power;
ratio_low = power_low / total_power;
ratio_mid = power_mid / total_power;
detected_noise = 'Unknown';

% Debug Prints
fprintf('\n--- CLASSIFIER METRICS ---\n');
fprintf('Ratio Hum:   %.2f\n', ratio_hum);
fprintf('Ratio Low:   %.2f\n', ratio_low);
fprintf('Ratio Mid:   %.2f\n', ratio_mid);
fprintf('Centroid:    %.2f Hz\n', spectral_centroid);
fprintf('--------------------------\n');

if total_power < 0.001
    detected_noise = 'Silence';
elseif ratio_hum > 0.1
    detected_noise = 'Electrical Hum';
elseif ratio_mid > 0.45
    detected_noise = 'Human Chatter';
elseif ratio_low > 0.4
    if spectral_centroid < 300
         detected_noise = 'Wind Noise'; 
    else
         detected_noise = 'Traffic Noise'; 
    end
else 
    detected_noise = 'Fan Noise';
end

fprintf('FINAL DECISION: ** %s **\n', detected_noise);
pause(1);

%% ========================================================================
%  MODULE 2: ADAPTIVE FILTERING (AGGRESSIVE MODE)
%  ========================================================================
disp(' ');
disp('--------------------------------------------------');
disp('   MODULE 2: APPLYING AGGRESSIVE FILTER           ');
disp('--------------------------------------------------');

% Prepare output container
filtered_signal = input_signal;

switch detected_noise
    case 'Silence'
        disp('>> Signal too weak. No filtering needed.');
        
    case 'Electrical Hum'
        % --- FIX 2: CASCADED NOTCH FILTER ---
        % Removes 50Hz Fundamental + 100Hz Harmonic + 150Hz Harmonic
        disp('>> Applying Multi-Stage Notch Filter (50Hz, 100Hz, 150Hz)...');
        
        wo = 50/(fs/2); bw = wo/10;
        [b1, a1] = iirnotch(wo, bw); 
        
        wo2 = 100/(fs/2); bw2 = wo2/10;
        [b2, a2] = iirnotch(wo2, bw2);
        
        wo3 = 150/(fs/2); bw3 = wo3/10;
        [b3, a3] = iirnotch(wo3, bw3);
        
        % Series filtering
        temp1 = filter(b1, a1, input_signal);
        temp2 = filter(b2, a2, temp1);
        filtered_signal = filter(b3, a3, temp2);
        
    case {'Traffic Noise', 'Traffic/Engine'}
        % Aggressive High Pass
        fc = 400; 
        disp(['>> Applied Steep High-Pass Filter (Cutoff: ' num2str(fc) ' Hz).']);
        filtered_signal = highpass(input_signal, fc, fs, 'Steepness', 0.85);
        
    case {'Fan Noise', 'Fan Noise / Broadband'}
        % Bandpass to keep ONLY voice frequencies, reject low rumble and high hiss
        disp('>> Applied Voice-Band Band-Pass (300Hz - 3400Hz).');
        filtered_signal = bandpass(input_signal, [300 3400], fs, 'Steepness', 0.85);
        
    case 'Human Chatter'
        % Enhance Voice: Mild Bandpass
        disp('>> Applied Voice Enhancement Filter.');
        filtered_signal = bandpass(input_signal, [200 4000], fs);
        
    case 'Wind Noise'
        % --- FIX 3: REPLACED LMS WITH BUTTERWORTH HIGH-PASS ---
        % LMS is unstable for short clips. A 6th order Butterworth 
        % at 200Hz is the industry standard for removing wind rumble.
        disp('>> Applied 6th-Order Butterworth High-Pass (Wind Removal).');
        
        fc = 200; % Cutoff Frequency
        [b, a] = butter(6, fc/(fs/2), 'high'); % 6th Order is very steep
        filtered_signal = filter(b, a, input_signal);
        
    otherwise
        disp('>> Fallback: General Noise Reduction.');
        filtered_signal = bandpass(input_signal, [150 4000], fs);
end

%% --- FIX 4: OUTPUT SIGNAL CONDITIONING (AGC) ---
% Filters reduce volume. This restores volume so you can hear the result.
disp('>> Normalizing Output Volume (AGC)');
max_out = max(abs(filtered_signal));
if max_out > 0
    % Boost volume to 0.95 peak
    filtered_signal = filtered_signal * (0.95 / max_out); 
end

%% 3. VISUALIZATION & PLAYBACK
figure('Name', 'Noise Cancellation Results', 'NumberTitle', 'off');

% Time Domain
subplot(2,1,1);
plot((1:length(input_signal))/fs, input_signal, 'Color', [0.8, 0.2, 0.2, 0.6], 'DisplayName', 'Original (Noisy)'); hold on;
plot((1:length(filtered_signal))/fs, filtered_signal, 'Color', [0, 0.4, 0.8, 0.9], 'LineWidth', 1, 'DisplayName', 'Filtered (Clean)');
legend('Location','best'); 
title(['Time Domain Analysis - Detected: ' detected_noise]); 
xlabel('Time (s)'); ylabel('Amplitude'); grid on;
ylim([-1.1 1.1]);

% Frequency Domain
subplot(2,1,2);
[pxx_in, f_in] = periodogram(input_signal, [], [], fs);
[pxx_out, f_out] = periodogram(filtered_signal, [], [], fs);
plot(f_in, 10*log10(pxx_in), 'Color', [0.8, 0.2, 0.2, 0.6], 'DisplayName', 'Original Spectrum'); hold on;
plot(f_out, 10*log10(pxx_out), 'Color', [0, 0.4, 0.8, 0.9], 'LineWidth', 1.5, 'DisplayName', 'Filtered Spectrum');
xlim([0 2000]); xlabel('Frequency (Hz)'); ylabel('Power/Frequency (dB/Hz)'); 
legend('Location','best'); 
title('Spectral Comparison'); grid on;

disp('--------------------------------------------------');
disp('   PLAYING ORIGINAL (Noisy) ...');
sound(input_signal, fs);
pause(duration + 1);

disp('   PLAYING FILTERED (Cleaned) ...');
sound(filtered_signal, fs);
disp('--------------------------------------------------');