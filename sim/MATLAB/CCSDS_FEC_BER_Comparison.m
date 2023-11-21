% Comparison of CCSDS TM FEC Techniques in terms of BER
% Based on the CCSDSTMBitErrorRateExample.mlx of the satcom MATLAB Package
%% Simulation parameters
seeConstellation = false;         % Flag to toggle the visualization of constellation
channelCodingAll = ["rs","concatenated","none","convolutional"]; % Channel coding scheme, turbo and LDPC not supported...
transferFrameLength = 128;      % In bytes corresponding to 223*5
modScheme = "BPSK";              % Modulation scheme
alpha = 0.35;                    % Root raised cosine filter roll-off factor
sps = 8;                         % Samples per symbol
% Signal generation frequencies and impairment
fSym = 2e6; % Symbol rate or Baud rate in Hz
cfo = 2e5;  % In Hz
% Energy per bit to noise ratio:
EbN0 = 1:0.5:10; % To see a proper BER result, run the simulation for 3.2:0.2:5
% Initialize berConvCode variable for all fec schemes and for all EbN0 values
berConvCode = zeros(length(channelCodingAll),length(EbN0));
% Simulation parameters
maxNumErrors = 1e2;  % Simulation stops after maxNumErrors bit errors
maxNumBits = 1e8;    % Simulation stops after processing maxNumBits
                     % Set maxNumBits = 1e8 for a smoother BER curve
maxFramesLost = 1e2; % Simulation stops after maxFramesLost frames are lost
%% Set up TM Waveforms using ccsdsTMWaveformGenerator Object
convCodeIdx = 0; % Initialize the counter before the loop
for channelCoding = channelCodingAll % Loop over all channel coding schemes
    convCodeIdx = convCodeIdx + 1; % Increment the counter on each iteration
    tmWaveGen = ccsdsTMWaveformGenerator("ChannelCoding",channelCoding, ...
        "NumBytesInTransferFrame",transferFrameLength, ...
        "Modulation",modScheme, ...
        "RolloffFactor",alpha, ...
        "SamplesPerSymbol",sps);
    disp(tmWaveGen)
    %% Set up BER calculation parameters
    rate = tmWaveGen.info.ActualCodeRate;
    M = tmWaveGen.info.NumBitsPerSymbol;
    numBitsInTF = tmWaveGen.NumInputBits;
    snr = EbN0 + 10*log10(rate) + ...
        10*log10(M) - 10*log10(sps);      % As signal power is scaled to one while introducing noise, 
                                        % SNR value should be reduced by a factor of SPS
    numSNR = length(snr);
    ber = zeros(numSNR,1);                % Initialize the BER parameter
    bercalc = comm.ErrorRate; 
    %% Create raised cosine filter, fine and coarse frequency compensation for receiver
    % Raised cosine filter
    b = rcosdesign(alpha,tmWaveGen.FilterSpanInSymbols,sps);
    % |H(f)| = 1  for |f| < fN(1-alpha) - Annex 1 in Section 2.4.17A in [2]
    Gain =  sum(b);
    rxFilterDecimationFactor = sps/2;
    rxfilter = comm.RaisedCosineReceiveFilter( ...
        "DecimationFactor",rxFilterDecimationFactor, ...
        "InputSamplesPerSymbol",sps, ...
        "RolloffFactor",alpha, ...
        "Gain",Gain);
    % Frequency offset
    phaseOffset = pi/8;
    fqyoffsetobj = comm.PhaseFrequencyOffset( ...
        "FrequencyOffset",cfo, ...
        "PhaseOffset",phaseOffset, ...
        "SampleRate",sps*fSym);
    coarseFreqSync = comm.CoarseFrequencyCompensator( ...
        "Modulation",modScheme, ...
        "FrequencyResolution",100, ...
        "SampleRate",sps*fSym);
    fineFreqSync = comm.CarrierSynchronizer("DampingFactor",1/sqrt(2), ...
        "NormalizedLoopBandwidth",0.0007, ...
        "SamplesPerSymbol",1, ...
        "Modulation",modScheme);
    % Fractional delay
    varDelay = dsp.VariableFractionalDelay("InterpolationMethod","Farrow");
    fixedDelayVal = 10.2;
    Kp = 1/(pi*(1-((alpha^2)/4)))*cos(pi*alpha/2);
    symsyncobj = comm.SymbolSynchronizer( ...
        "DampingFactor",1/sqrt(2), ...
        "DetectorGain",Kp, ...
        "TimingErrorDetector","Gardner (non-data-aided)", ...
        "Modulation","PAM/PSK/QAM", ...
        "NormalizedLoopBandwidth",0.0001, ...
        "SamplesPerSymbol",sps/rxFilterDecimationFactor);
    %% Decode the signal
    demodobj = HelperCCSDSTMDemodulator("Modulation",modScheme,"ChannelCoding",channelCoding);
    decoderobj = HelperCCSDSTMDecoder("ChannelCoding",channelCoding, ...
        "NumBytesInTransferFrame",transferFrameLength, ...
        "Modulation",modScheme);
    %% Perform actual calculation
    numBitsForBER = 8; % For detecting which frame is synchronized
    numMessagesInBlock = 2^numBitsForBER;
    for isnr = 1:numSNR
        rng default;                         % Reset to get repeatable results
        reset(bercalc);
        berinfo = bercalc(int8(1), int8(1)); % Initialize berinfo before BER is calculated
        tfidx = 1;
        numFramesLost = 0;
        prevdectfidx = 0;
        inputBuffer = zeros(numBitsInTF, 256,"int8");
        while((berinfo(2) < maxNumErrors) && ...
                (berinfo(3) < maxNumBits) && ...
                (numFramesLost < maxFramesLost)&& ...
                (berinfo(1)>0))
            seed = randi([0 2^32-1],1,1);    % Generate seed for repeatable simulation

            % Transmitter side processing
            bits = int8(randi([0 1],numBitsInTF-numBitsForBER,1));
            % The first 8 bits correspond to the TF index modulo 256. When
            % synchronization modules are included, there can be a few frames
            % where synchronization is lost temporarily and then locks again.
            % In such cases, to calculate the BER, these 8 bits aid in
            % identifying which TF is decoded. If an error in these 8 bits
            % exists, then this error is detected by looking at the difference
            % between consecutive decoded bits. If an error is detected, then
            % that frame is considered lost. Even though the data link layer is
            % out of scope of this example, the data link layer has a similar
            % mechanism. In this example, only for calculating the BER, this
            % mechanism is adopted. The mechanism that is adopted in this
            % example is not as specified in the data link layer of the CCSDS
            % standard. And this mechanism is not specified in the physical
            % layer of the CCSDS standard.
            msg = [de2bi(mod(tfidx-1,numMessagesInBlock),numBitsForBER,"left-msb").';bits];
            inputBuffer(:,mod(tfidx-1,numMessagesInBlock)+1) = msg;
            tx = tmWaveGen(msg);

            % Introduce RF impairments
            cfoInroduced = fqyoffsetobj(tx);                % Introduce CFO
            delayed = varDelay(cfoInroduced,fixedDelayVal); % Introduce timing offset
            rx = awgn(delayed, snr(isnr),'measured',seed);  % Add AWGN

            % Receiver-side processing
            coarseSynced = coarseFreqSync(rx);     % Apply coarse frequency synchronization
            filtered = rxfilter(coarseSynced);     % Filter received samples through RRC filter
            TimeSynced = symsyncobj(filtered);     % Apply symbol timing synchronization
            fineSynced = fineFreqSync(TimeSynced); % Track frequency and phase
    

            demodData = demodobj(fineSynced); % Demodulate
            decoded = decoderobj(demodData);  % Perform phase ambiguity resolution,
                                            % frame synchronization, and channel decoding

            % Calculate BER and adjust all buffers accordingly
            dectfidx = bi2de(double(decoded(1:8).'), ...
                "left-msb")+1;                % See the value of first 8 bits
            if tfidx > 30 % Consider to calculate BER only after 30 TFs are processed
                % As the value of first 8 bits is increased by one in each
                % iteration, if the difference between the current decoded
                % decimal value of first 8 bits is not equal to the previously
                % decoded one, then it indicates a frame loss.
                if dectfidx - prevdectfidx ~= 1
                    numFramesLost = numFramesLost + 1;
                    disp(['Frame lost at tfidx: ' num2str(tfidx) ...
                        '. Total frames lost: ' num2str(numFramesLost)]);
                else
                    berinfo = bercalc(inputBuffer(:,dectfidx),decoded);
                    if nnz(inputBuffer(:,dectfidx)-decoded)
                        disp(['Errors occurred at tfidx: ' num2str(tfidx) ...
                            '. Num errors: ' num2str(nnz(inputBuffer(:,dectfidx) - decoded))])
                    end
                end
            end
            prevdectfidx = dectfidx;
            
            % Update tfidx
            tfidx = tfidx + 1;
        end
        fprintf("\n");
        currentBer = berinfo(1);
        ber(isnr) = currentBer;
        disp(['Eb/N0: ' num2str(EbN0(isnr)) '. BER: ' num2str(currentBer) ...
            '. Num frames lost: ' num2str(numFramesLost)]);
        % Save BER results for this convolutional code
        berConvCode(isnr,convCodeIdx) = currentBer;
        % Reset objects
        reset(tmWaveGen);
        reset(fqyoffsetobj);
        reset(varDelay);
        reset(coarseFreqSync);
        reset(rxfilter);
        reset(symsyncobj);
        reset(fineFreqSync);
        reset(demodobj);
        reset(decoderobj);
    end
end
%% Plot BER result for all fec schemes
figure
for convCodeIdx = 1:length(channelCodingAll)
    semilogy(EbN0,berConvCode(:, convCodeIdx));
    hold on
end
grid on;
xlabel('E_b/N_0 (dB)');
ylabel('BER');
title('BER plot');
legend(channelCodingAll);