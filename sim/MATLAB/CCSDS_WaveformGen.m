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

tmWaveGen_no_filter = ccsdsTMWaveformGenerator("ChannelCoding", "None", ...
                                    "HasASM", 1, ...
                                    "Modulation", "BPSK",...
                                    "PulseShapingFilter","none", ...
                                    "NumBytesInTransferFrame", 16, ...
                                    "HasRandomizer", 0);
tmWaveGen_filter = ccsdsTMWaveformGenerator("ChannelCoding", "None", ...
                                    "HasASM", 1, ...
                                    "Modulation", "BPSK",...
                                    "PulseShapingFilter","root raised cosine", ...
                                    "RolloffFactor", 0.35, ...
                                    "SamplesPerSymbol", 32, ...
                                    "NumBytesInTransferFrame", 16, ...
                                    "HasRandomizer", 0);

fprintf('Number of bits in TF 1: %d\n', tmWaveGen_no_filter.NumInputBits);
symbolRate = 1e6;

data_text = hexToBinArray('48454c4c4f2c4954532d534147452100')';

% Generate a CCSDS waveform
[waveform_no_filter, waveformInfo_no_filter] = tmWaveGen_no_filter(data_text);
[waveform_filter, waveformInfo_filter] = tmWaveGen_filter(data_text);

% Calculate delay introduced by RRC filter
N = 4 / tmWaveGen_filter.SamplesPerSymbol; % replace this with actual length if known
delay = (N - 1) / (2 * symbolRate);
time_filter = 0:1/symbolRate/tmWaveGen_filter.SamplesPerSymbol:(length(waveform_filter)-1)/symbolRate/tmWaveGen_filter.SamplesPerSymbol;
% Shift time vector for filtered waveform
% time_filter = time_filter + delay;

% Plot the CCSDS waveforms
% No filter
time_no_filter = 0:1/symbolRate:(length(waveform_no_filter)-1)/symbolRate;
stairs(time_no_filter, waveform_no_filter);
hold on;
% With filter
plot(time_filter, 30*waveform_filter,'r-');
plot(time_filter+delay, 30*waveform_filter,'b.');

title('CCSDS waveform')
xlabel('Time (s)')
ylabel('Amplitude')

% Plot the CCSDS waveform spectrum
% plotSpectrum(waveform, waveformInfo.SampleRate)