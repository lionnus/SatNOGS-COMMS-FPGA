%% Generate Sample CCSDS Waveform
%   WaveformSource              - CCSDS telemetry waveform source
%   NumBytesInTransferFrame     - Number of bytes in one transfer frame
%   HasRandomizer               - Option for randomizing the data
%   HasASM                      - Option for inserting attached sync
%                                 marker (ASM)
%   PCMFormat                   - Pulse code modulation (PCM) format
%   ChannelCoding               - Error control channel coding scheme
%   ConvolutionalCodeRate       - Code rate of convolutional code 
%   Modulation                  - Modulation scheme
%   PulseShapingFilter          - Pulse shaping filter
%   RolloffFactor               - Rolloff factor for transmit filtering
%   SymbolRate                  - Symbol rate (coded symbols/s)
%   SamplesPerSymbol            - Samples per symbol
%   ScramblingCodeNumber        - Scrambling code number
clc; close all; clear all;

tmWaveGen_no_filter = ccsdsTMWaveformGenerator("ChannelCoding", "convolutional", ...
                                    "ConvolutionalCodeRate","1/2", ...
                                    "HasASM", 1, ...
                                    "Modulation", "BPSK",...
                                    "PulseShapingFilter","none", ...
                                    "NumBytesInTransferFrame", 16, ...
                                    "HasRandomizer", 0);
tmWaveGen_filter = ccsdsTMWaveformGenerator("ChannelCoding", "convolutional", ...
                                    "ConvolutionalCodeRate","1/2", ...
                                    "Modulation", "BPSK",...
                                    "PulseShapingFilter","root raised cosine", ...
                                    "RolloffFactor", 0.35, ...
                                    "SamplesPerSymbol", 32, ...
                                    "NumBytesInTransferFrame", 16, ...
                                    "HasRandomizer", 0);

fprintf('Number of bits in TF 1: %d\n', tmWaveGen_no_filter.NumInputBits);
symbolRate = 1.5625e6;

data_text = hexToBinArray('48454c4c4f2c4954532d534147452100')';

% Generate a CCSDS waveform
[waveform_no_filter, waveformInfo_no_filter] = tmWaveGen_no_filter(data_text);
[waveform_filter, waveformInfo_filter] = tmWaveGen_filter(data_text);

% Calculate delay introduced by RRC filter
N = 4 / tmWaveGen_filter.SamplesPerSymbol; % replace this with actual length if known
delay = (N - 1) / (2 * symbolRate);
delay = 2.9e-6; % empirical
time_filter = 0:1/symbolRate/tmWaveGen_filter.SamplesPerSymbol:(length(waveform_filter)-1)/symbolRate/tmWaveGen_filter.SamplesPerSymbol;
time_no_filter = 0:1/symbolRate:(length(waveform_no_filter)-1)/symbolRate;
% Shift time vector for filtered waveform
% time_filter = time_filter + delay;

%% Load Oscilloscope Data and Synchronization

% Oscilloscope data file path
oscFilePath = '/home/lionnus/OneDrive/Ubuntu/ARIS/Results/Measurements_FPGA_output/scope_errorco_2.csv'; 

% Load oscilloscope data as a table
oscData = readtable(oscFilePath);

% Remove first row (which contains 'second' and 'Volt' labels)
oscData(1:2,:) = [];

% Convert table to array for numeric operations
oscDataArray = table2array(oscData);

% Extract time and voltage (channels 1 and 2)
oscTime = oscDataArray(:, 1);
data_valid_o = oscDataArray(:, 2);
data = oscDataArray(:, 3);

% Synchronization shift
syncShift = 6.5e-7; % replace with your desired shift value

% Shift oscilloscope time
oscTimeShifted = oscTime + syncShift;

%% Plot Waveforms and Oscilloscope Data

figure;

% CCSDS waveforms
% No filter
subplot(3,1,1);
stairs(time_no_filter, real(waveform_no_filter),'Color',[0 46/255 92/255],'LineWidth',1.5);
hold on;
% With filter
plot(time_filter-delay, 30*real(waveform_filter),'b-');
xlim([ 0 (64/symbolRate+1/(2*symbolRate))]);
title('MATLAB Simulation')
xlabel('Time (s)')
ylabel('Amplitude')
legend('MATLAB', 'MATLAB with filter')

% Oscilloscope data (channel 1 and 2)
subplot(3,1,2);
plot(oscTimeShifted, data, 'g-','Color',[0 46/255 92/255],'LineWidth',1.5);
hold on;
plot(oscTimeShifted, data_valid_o, 'c-','Color',[218/255 232/255 252/255],'LineWidth',1.5);
xlim([ 0 (64/symbolRate+1/(2*symbolRate))]);
title('Oscilloscope data')
xlabel('Time (s)')
ylabel('Amplitude')
legend('FPGA Output Encoded', 'FPGA valid_o')


% Bit output
subplot(3,1,3);
bit_output = [0	1	0	1	0	1	1	0	0	0	0	0	1	0	0	0	0	0	0	1	1	1	0	0	1	0	0	1	0	1	1	1	0	0	0	1	1	0	1	0	1	0	1	0	0	1	1	1	0	0	1	1	1	1	0	1	0	0	1	1	1	1	1	0	0	1	1	1	1	0	0	1	0	0	0	0	1	1	0	1	0	1	1	1	0	0	1	0	1	0	1	0	1	0	1	0	0	0	0	1	0	1	0	1	0	0	1	1	0	1	1	0	1	0	1	1	0	1	0	1	0	1	0	0	0	1	1	0	1	0	1	1	0	1	0	1	0	1	0	0	1	0	1	1	1	1	0	0	1	1	0	1	1	1	0	0	0	0	0	0	0	1	1	1	0	1	0	1	0	1	1	1	1	1	1	0	1	1	0	0	1	1	0	1	0	1	1	0	0	1	0	1	1	1	0	1	1	0	1	0	0	0	1	0	0	0	1	1	0	1	1	0	0	1	1	0	1	1	0	0	0	0	1	1	1	1	0	0	1	0	1	0	0	1	0	1	0	0	1	1	0	1	0	1	0	0	1	1	0	0	1	0	0	0	0	1	1	1	0	1	0	0	1	0	1	1	0	1	0	1	0	0	1	1	1	0	0	1	0	0	0	0	0	1	1	0	1	0	0	0	1	0	0	0	0	0	1	1	0	1	0	1	1	1	0	0	1	0	1	0	0	1	0	0	1	0	0	1	0	1];
bit_output_time = 0:1/symbolRate:(length(bit_output)-1)/symbolRate;
xlim([ 0 (64/symbolRate+1/(2*symbolRate))]);
for i = 1:length(bit_output(1:64))
    text(bit_output_time(i)+1/(2*symbolRate), 0, num2str(bit_output(i)));
end
ylim([-0.1 0.1])
axis off;
title('Bit output')
%% Save plot

% Set figure size
fig = gcf;
fig.PaperUnits = 'centimeters';
fig.PaperPosition = [0 0 20 12]; % Adjust width and height as needed

% Save the plot as a color EPS file
print('CCSDS_Matlab_vs_FPGA.eps', '-depsc', '-r300', '-cmyk');

% Restore default settings
set(fig, 'PaperPositionMode', 'auto');