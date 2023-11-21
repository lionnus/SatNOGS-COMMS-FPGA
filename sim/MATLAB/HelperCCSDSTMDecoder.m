classdef HelperCCSDSTMDecoder < comm.internal.Helper & satcom.internal.ccsds.tmBase
    % HelperCCSDSTMDecoder CCSDS telemetry Decoder
    %
    %   Note: This is a helper and its API and/or functionality may change
    %   in subsequent releases.
    %
    %   HDEC = HelperCCSDSTMDecoder creates a CCSDS telemetry decoder
    %   object, HDEC. The object is designed to decode the demodulated
    %   telemetry symbols that is based on CCSDS TM synchronization and
    %   channel coding standard. The object supports decoding of RS,
    %   convolutional, and concatenated. The object also supports no
    %   channel coding scheme. The object also does the frame
    %   synchronization along with phase ambiguity resolution.
    %
    %   Step method syntax:
    %
    %   Y = step(HDEC,X) decodes the demodulated symbols X and returns the
    %   decoded bits, Y. Except for RS codes, all other decoding schemes
    %   expect soft input. Length of Y is an integer multiple of transfer
    %   frame length for the specified link. If input X doesn't contain
    %   sufficient bits such that Y doesn't make up a transfer frame, then
    %   Y is a zero vector of transfer frame length. This situation
    %   typically occurs while the simulation chain is in initial stages
    %   where there will be delays incurred while doing demodulation and
    %   decoding. For this reason, the size of X can change even after the
    %   object is locked.
    %
    %   Limitations of the current system object:
    %   1. Does not support ConvolutionalCodeRate to be '3/4', '5/6 and
    %      '7/8'
    %   2. Phase ambiguity resolution of only BPSK and QPSK are
    %      supported currently. 
    %   3. Does not support turbo and LDPC decoding
    %   4. Does not support PCM-format of 'NRZ-M' for convolutional and
    %      concatenated codes
    %
    %   System objects may be called directly like a function instead of
    %   using the step method. For example, y = step(obj, x) and y = obj(x)
    %   are equivalent.
    % 
    %   HelperCCSDSTMDecoder properties:
    %
    %   ChannelCoding               - Error control channel coding scheme
    %   NumBytesInTransferFrame     - Number of bytes in one transfer frame
    %   ConvolutionalCodeRate       - Code rate of convolutional code
    %   ViterbiTraceBackDepth       - Viterbi traceback depth
    %   ViterbiTrellis              - Trellis structure of Viterbi decoder
    %   ViterbiWordLength           - Quantization word length for Viterbi
    %                                 decoder
    %   HasRandomizer               - Option for randomizing the data
    %   HasASM                      - Option for inserting attached sync
    %                                 marker (ASM)
    %   RSMessageLength             - Number of bytes in one Reed-Solomon
    %                                 (RS) message block
    %   RSInterleavingDepth         - Interleaving depth of the RS code
    %   IsRSMessageShortened        - Option to shorten RS code
    %   RSShortenedMessageLength    - Number of bytes in RS shortened
    %                                 message block
    %   Modulation                  - Modulation scheme
    %   PCMFormat                   - Pulse code modulation (PCM) format
    %   DisableFrameSynchronization - Option to disable frame
    %                                 synchronization
    %   DisablePhaseAmbiguityResolution - Option to disable phase ambiguity
    %                                     resolution
    
    %   Copyright 2020-2021 The MathWorks, Inc.

    % Public, non-tunable properties
    properties(Nontunable)
        ViterbiTraceBackDepth = 60
        ViterbiTrellis = poly2trellis(7, [171 133])
        ViterbiWordLength = 8
        DisableFrameSynchronization = false
        DisablePhaseAmbiguityResolution = false
    end

    % Pre-computed constants
    properties(Access = private)
        pDec
        pFirstTimeStepCalling = true % To detect if step method is being for the first time. This is helpful in convolutional codes where delay is there for the first time it is called
        pInputBuffer
        pOutputBuffer
        pDifferentialDecoderBit
        pRotatedASM
        pFullInputBufferLength
        pFrameLength
        pASMOffsetLength
    end

    methods
        % Constructor
        function obj = HelperCCSDSTMDecoder(varargin)
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:})
        end
    end

    methods(Access = protected)
        %% Common functions
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
            setupImpl@satcom.internal.ccsds.tmBase(obj);
            obj.pInputBuffer = [];
            obj.pOutputBuffer = [];
            asm = obj.pASM;
            obj.pFullInputBufferLength = obj.pPRNSequenceLength + length(asm)*obj.HasASM;
            if obj.IsRSMessageShortened == 0
                % It is possible that "RSShortenedMessageLength" is
                % set to non standard value even after disabling
                % shortening.
                obj.RSShortenedMessageLength = obj.RSMessageLength;
            end
            if any(strcmp(obj.ChannelCoding, {'convolutional', 'concatenated'}))
                obj.pFirstTimeStepCalling = true;
                obj.pDec = comm.ViterbiDecoder("TracebackDepth",obj.ViterbiTraceBackDepth,...
                    "TerminationMethod","Continuous",...
                    "TrellisStructure",obj.ViterbiTrellis,...
                    "InputFormat","Soft",...
                    "OutputDataType","double",...
                    "SoftInputWordLength",obj.ViterbiWordLength,...
                    "PuncturePatternSource","Property");
                obj.pDifferentialDecoderBit = 0; % In practice, the initial value of this bit doesn't matter as initial few frames needs to be discarded for the synchronization algorithms to converge. So, by the time full frames are being taken, proper value in this property will be initialized
                % Calculate buffer length
                switch(obj.ConvolutionalCodeRate)
                    case '1/2'
                        % These values are generated by separately
                        % passing ASM bits through the 1/2 rate
                        % convolutional encoder that is given in CCSDS
                        % standard and taking the last 52 bits
                        asm = [1;0;0;0;0;0;0;1;1;1;0;0;1;0;0;1;0;1;1;1;0;0;0;1;1;0;1;...
                            0;1;0;1;0;0;1;1;1;0;0;1;1;1;1;0;1;0;0;1;1;1;1;1;0];
                        obj.pDec.PuncturePattern = [1;1];
                        obj.pASMOffsetLength = 12;
                        obj.pFullInputBufferLength = 2*(obj.pPRNSequenceLength + 32); % 64 is the length of full ASM which is convolutionally encoded and is a constant in this particular case
                    case '2/3'
                        % Following values are generated by separately
                        % passing ASM bits through the 2/3
                        % convolutional encoder and taking only 38 bits
                        asm = [1;1;0;1;0;1;0;1;1;1;0;0;0;0;0;1;0;...
                            1;1;1;1;1;1;0;0;0;0;1;0;1;0;0;0;1;0;1;0;1];
                        obj.pDec.PuncturePattern = [1;1;0;1];
                        obj.pASMOffsetLength = 10;
                        obj.pFullInputBufferLength = 3*(obj.pPRNSequenceLength + 32)/2; % Note that obj.pPRNSequenceLength is always an even number. So, division by 2 is always an integer value
                        
                end
            end
            
            if obj.DisablePhaseAmbiguityResolution
                modscheme = "other"; % So that following switch case executes code in otherwise case.
            else
                modscheme = obj.Modulation;
            end
            
            switch(modscheme)
                case "BPSK"
                    obj.pRotatedASM = zeros(length(asm), 2);
                    obj.pRotatedASM(:, 1) = 2*asm(:)-1; % Map to +1, -1
                    obj.pRotatedASM(:, 2) = 1 - 2*asm(:); % Map to -1, +1
                    obj.pNumBitsPerSymbol = 1;
                case {"QPSK", "OQPSK"}
                    RotationMap = [0, 1, 2, 3; ... % Mapping for phase rotation of 0
                        2, 0, 3, 1; ... % Mapping for phase rotation of pi/2
                        3, 2, 1, 0; ... % Mapping for phase rotation of pi
                        1, 3, 0, 2;... % Mapping for phase rotation of 3*pi/2
                        ];
                    m = 2;
                    obj.pNumBitsPerSymbol = 2;
                    ASMSymbols = comm.internal.utilities.bi2deLeftMSB(double(reshape(asm,m,[]).'),2);
                    obj.pRotatedASM = zeros(length(asm), 2^m);
                    for iRot = 1:4
                        temp = comm.internal.utilities.de2biBase2LeftMSB(RotationMap(iRot, ASMSymbols+1).', m).';
                        obj.pRotatedASM(:, iRot) = 2*temp(:)-1; % Map to +1, -1
                    end
                otherwise % Don't do phase ambiguity resolution
                    obj.pRotatedASM = 2*asm(:)-1;
                    obj.pNumBitsPerSymbol = 1;
            end
            if any(strcmp(obj.ChannelCoding, {'concatenated', 'convolutional'}))
                obj.pFrameLength = length(asm) + obj.pPRNSequenceLength*obj.pInverseCodeRate;
            else
                obj.pFrameLength = length(asm) + obj.pPRNSequenceLength;
            end
        end

        function y = stepImpl(obj,llr)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            if isempty(llr)
                y = zeros(0, 1, 'int8');
                return;
            end
            
            if obj.HasASM
                asmlen = length(obj.pASM);
                % Frame synchronization
                [frames, syncLostFlag] = frameSynchronize(obj, llr);
            else
                asmlen = 0;
                [frames,obj.pInputBuffer] = buffer([obj.pInputBuffer;llr], obj.pFullInputBufferLength); % When ASM is not there, then it is assumed that frame sync is done through other mechanisms
                syncLostFlag = false;
            end
            if any(strcmp(obj.ChannelCoding,{'convolutional','concatenated'}))
                u = frames;
            else
                % [tu,obj.pInputBuffer] = buffer([obj.pInputBuffer;frames],obj.pPRNSequenceLength+asmlen);
                % n = size(tu,2);
                n = size(frames,2);
                u = frames(asmlen+1:end,:);
            end
            
            if syncLostFlag
                y = zeros(obj.pTFLen*8, 1, 'int8');
                % valid = false;
            else
                if ~isempty(u)
                    switch(obj.ChannelCoding)
                        case "none"
                            if n % For non zero value of n
                                if obj.HasRandomizer
                                    tempy = bitxor(int8(u>0),obj.pPRNSequence);
                                    y = tempy(:);
                                else
                                    y = int8(u(:)>0);
                                end
                                % valid = true;
                            else
                                y = zeros(obj.pTFLen*8, 1, 'int8');
                                % valid = false;
                            end
                        case "RS"
                            if n % For non zero value of n
                                if obj.HasRandomizer
                                    derandom = logical(bitxor(int8(u>0),obj.pPRNSequence));
                                else
                                    derandom = logical(u>0);
                                end
                                tfl = obj.pTFLen*8;
                                y = zeros(n*tfl, 1, 'int8');
                                for iWord = 1:n
                                    y((iWord-1)*tfl+1:iWord*tfl) = ccsdsRSDecode(derandom(:,iWord),obj.RSMessageLength,obj.RSInterleavingDepth,obj.RSShortenedMessageLength);
                                end
                                % valid = true;
                            else
                                y = zeros(obj.pTFLen*8, 1, 'int8');
                                % valid = false;
                            end
                        case "convolutional"
                            if strcmp(obj.ConvolutionalCodeRate,"1/2")
                                u(2:2:end) = -1*u(2:2:end);
                            end
                            quantized = uencode(u,obj.ViterbiWordLength,max(abs(u(:))),'unsigned');
                            % [vitin,obj.pInputBuffer] = buffer([obj.pInputBuffer;quantized], log2(obj.pDec.TrellisStructure.numOutputSymbols));
                            decoded = obj.pDec(quantized(:));
                            if obj.pFirstTimeStepCalling
                                tdecoded = decoded(obj.ViterbiTraceBackDepth+1:end);
                                obj.pFirstTimeStepCalling = false;
                            else
                                tdecoded = decoded;
                            end
                            [ty,obj.pOutputBuffer] = buffer([obj.pOutputBuffer;tdecoded],obj.pPRNSequenceLength+asmlen);
                            n = size(ty,2);
                            if n
                                tempy = ty(asmlen+1:end, :);
                                if obj.HasRandomizer
                                    derandom = bitxor(int8(tempy),obj.pPRNSequence);
                                    y = derandom(:);
                                else
                                    y = int8(tempy(:));
                                end
                                % valid = true;
                            else
                                y = zeros(obj.pTFLen*8, 1, 'int8');
                                % valid = false;
                            end
                        case "concatenated"
                            if strcmp(obj.ConvolutionalCodeRate,"1/2")
                                u(2:2:end) = -1*u(2:2:end);
                            end
                            quantized = uencode(u,obj.ViterbiWordLength,max(abs(u(:))),'unsigned');
                            % [vitin,obj.pInputBuffer] = buffer([obj.pInputBuffer;quantized], log2(obj.pDec.TrellisStructure.numOutputSymbols));
                            decoded = obj.pDec(quantized(:));
                            if obj.pFirstTimeStepCalling
                                tdecoded = decoded(obj.ViterbiTraceBackDepth+1:end);
                                obj.pFirstTimeStepCalling = false;
                            else
                                tdecoded = decoded;
                            end
                            [ty,obj.pOutputBuffer] = buffer([obj.pOutputBuffer;tdecoded],obj.pPRNSequenceLength+asmlen);
                            n = size(ty,2);
                            if n
                                viterbiDecoded = logical(ty(asmlen+1:end, :)); % By this time, frame synchronization is complete. Hence, ASM can be discarded
                                if obj.HasRandomizer
                                    derandom = logical(bitxor(int8(viterbiDecoded),obj.pPRNSequence));
                                else
                                    derandom = viterbiDecoded;
                                end
                                tfl = obj.pTFLen*8;
                                y = zeros(n*tfl, 1, 'int8');
                                for iWord = 1:n
                                    y((iWord-1)*tfl+1:iWord*tfl) = ccsdsRSDecode(derandom(:,iWord),obj.RSMessageLength,obj.RSInterleavingDepth,obj.RSShortenedMessageLength);
                                end
                                % valid = true;
                            else
                                y = zeros(obj.pTFLen*8, 1, 'int8');
                                % valid = false;
                            end
                    end
                else
                    y = zeros(0, 1, 'int8');
                end
            end
        end
        
        function [v, syncFailed, pos, PhaseIndex] = frameSynchronize(obj,u)
            % Do frame synchronization and phase ambiguity resolution
            
            [frames, obj.pInputBuffer] = buffer([obj.pInputBuffer;u], obj.pFullInputBufferLength);
            n = size(frames, 2);
            v = zeros(obj.pFullInputBufferLength, 1); % Pre-initialization
            for iFrame = 1:n % For non-zero value of n
                numPhases = size(obj.pRotatedASM, 2);
                maxCorrValues = zeros(numPhases, 1);
                peakpos = zeros(numPhases, 1);
                for iPhase = 1:numPhases
                    si = obj.pRotatedASM(:, iPhase); % Take the ASM corresponding to that particular rotation of phase ambiguity.
                    [peakpos(iPhase), maxCorrValues(iPhase)] = FrameCorrelate(obj, frames(:,iFrame), si); % This is as per section
                end
                [~,PhaseIndex] = max(maxCorrValues);
                pos = peakpos(PhaseIndex);
                if any(strcmp(obj.ChannelCoding, {'convolutional','concatenated'}))
                    if pos-obj.pASMOffsetLength>0
                        % For 1/2 rate convolutional codes,
                        % obj.pASMOffsetLength value is 12 and for 2/3 rate
                        % convolutional codes, obj.pASMOffsetLength value
                        % is 10. This is set from the setupImpl method.
                        pos = pos - obj.pASMOffsetLength;
                    end
                end
                
                % Resolve phase ambiguity
                if any(strcmp(obj.Modulation,{'QPSK','OQPSK'}))
                    if PhaseIndex == 1
                        derotated = frames(:,iFrame);
                    elseif PhaseIndex == 2
                        reshapredFrame = reshape(frames(:,iFrame),2,[]);
                        temp = [reshapredFrame(2,:); -1*reshapredFrame(1,:)];
                        derotated = temp(:);
                    elseif PhaseIndex == 3
                        derotated = -1*frames(:,iFrame);
                    elseif PhaseIndex == 4
                        reshapredFrame = reshape(frames(:,iFrame),2,[]);
                        temp = [-1*reshapredFrame(2,:); reshapredFrame(1,:)];
                        derotated = temp(:);
                    end
                elseif strcmp(obj.Modulation,"BPSK")
                    if PhaseIndex == 1
                        derotated = frames(:,iFrame);
                    elseif PhaseIndex == 2
                        derotated = -1*frames(:,iFrame);
                    end
                else % Do not do phase ambiguity resolution
                    derotated = frames(:,iFrame);
                end
                
                if pos == 1
                    syncFailed = false;
                    v(:,iFrame) = derotated;
                else
                    tempInputBuffer = obj.pInputBuffer;
                    resetImpl(obj);
                    syncFailed = true;
                    % Adjust the next frame accordingly
                    tempFrames = [reshape(frames(:,iFrame:end),[],1);tempInputBuffer];
                    [newFrames, obj.pInputBuffer] = buffer(tempFrames(pos:end), obj.pFullInputBufferLength);
                    frames = [zeros(obj.pFullInputBufferLength, iFrame), newFrames];
                    % obj.pInputBuffer = [reshape(frames(pos:end,iFrame+1:end),[],1);obj.pInputBuffer]; % In the input buffer, symbols which are not rotated should be placed so that these can be combined with the next input and do phase ambiguity estimation properly
                    v = zeros(obj.pFullInputBufferLength, 0);
                end
            end
            
            % Take care of additional frames that might getting added when
            % sync is lost
            if size(frames,2)~=n
                obj.pInputBuffer = [reshape(frames(:,iFrame+1:end),[],1);obj.pInputBuffer];
            end
            
            if n == 0
                syncFailed = true;
                v = zeros(obj.pFullInputBufferLength, 0);
            end
        end
        
        function [PeakPos, maxcorr] = FrameCorrelate(obj, demodData, syncMarker)
            % Correlation for frame synchronization method
            numASMBits = length(syncMarker);
            fOfSiYi = ones(numASMBits, 1);
            F = obj.pFrameLength;
            SMu = zeros(F-numASMBits, 1);
            for iBit = 1:F-numASMBits
                numBitsInYi = length(demodData(iBit:end));
                if numBitsInYi >= numASMBits
                    yi = demodData(iBit:iBit+numASMBits-1);
                else
                    yi = [demodData(iBit:iBit+numBitsInYi-1); zeros(numASMBits-numBitsInYi,1)];
                end
                for iCorrelation = 1:numASMBits
                    if sign(syncMarker(iCorrelation)) ~= sign(yi(iCorrelation))
                        fOfSiYi(iCorrelation) = -1*abs(yi(iCorrelation));
                    else
                        fOfSiYi(iCorrelation) = 0;
                    end
                end
                SMu(iBit) = sum(fOfSiYi); % See equations in page 9-12 in CCSDS 130.1-G-2
                fOfSiYi = ones(numASMBits, 1);
            end
            [maxcorr,PeakPos] = max(SMu); % See equations in page 9-12 in CCSDS 130.1-G-2
            
        end
        
        function resetImpl(obj)
            % Initialize / reset discrete-state properties
            reset(obj.pDec);
            obj.pFirstTimeStepCalling = true;
            obj.pInputBuffer = [];
            obj.pOutputBuffer = [];
            obj.pDifferentialDecoderBit = 0;
        end

        function releaseImpl(obj)
            % Release resources, such as file handles
            if ~isempty(obj.pDec)
                release(obj.pDec);
            end
        end

        %% Backup/restore functions
        function s = saveObjectImpl(obj)
            % Set properties in structure s to values in object obj

            % Set public properties and states
            s = saveObjectImpl@satcom.internal.ccsds.tmBase(obj);
            s.ViterbiTraceBackDepth = obj.ViterbiTraceBackDepth;
            s.ViterbiTrellis = obj.ViterbiTrellis;
            s.ViterbiWordLength = obj.ViterbiTrellis;
            if isLocked(obj)
                if ~isempty(obj.pDec) % For the case of ChannelCoding being "none" or "RS", pDec is not defined. Hence, this should not be saved then
                    s.pDec = matlab.System.saveObject(obj.pDec);
                end
                s.pFirstTimeStepCalling = obj.pFirstTimeStepCalling;
                s.pInputBuffer = obj.pInputBuffer;
                s.pOutputBuffer = obj.pOutputBuffer;
                s.pDifferentialDecoderBit = obj.pDifferentialDecoderBit;
            end
        end

        function loadObjectImpl(obj,s,wasLocked)
            % Set properties in object obj to values in structure s

            if wasLocked
                if isfield(s,'pDec') % For the case of ChannelCoding being "none" or "RS", pDec is not defined. Hence, this should not be saved then
                    obj.pDec = matlab.System.loadObject(s.pDec);
                end
                obj.pFirstTimeStepCalling = s.pFirstTimeStepCalling;
                obj.pInputBuffer = s.pInputBuffer;
                obj.pOutputBuffer = s.pOutputBuffer;
                obj.pDifferentialDecoderBit = s.pDifferentialDecoderBit;
            end
            obj.ViterbiTraceBackDepth = s.ViterbiTraceBackDepth;
            obj.ViterbiTrellis = s.ViterbiTrellis;
            obj.ViterbiWordLength = s.ViterbiTrellis;

            % Set public properties and states
            loadObjectImpl@satcom.internal.ccsds.tmBase(obj,s,wasLocked);
        end

        %% Advanced functions
        function flag = isInputSizeMutableImpl(~,~)
            % Return false if input size cannot change
            % between calls to the System object
            flag = true;
        end

        function flag = isInactivePropertyImpl(obj,prop)
            % Return false if property is visible based on object 
            % configuration, for the command line and System block dialog
            flag = true;
            isFACM = false; % Currently FACM waveform is not supported
            smtfFlag = isFACM || (strcmp(obj.ChannelCoding,'LDPC') && obj.IsLDPCOnSMTF);
            if strcmp(prop,'ChannelCoding')
                flag = isFACM;
            elseif strcmp(prop,'NumBytesInTransferFrame')
                flag = any(strcmp(obj.ChannelCoding,{'RS','concatenated','turbo'}));
            elseif any(strcmp(prop,{'ConvolutionalCodeRate', 'ViterbiTraceBackDepth','ViterbiTrellis','ViterbiWordLength'}))
                flag = ~any(strcmp(obj.ChannelCoding,{'convolutional','concatenated'})) || isFACM;
            elseif strcmp(prop,'HasRandomizer')
                flag = smtfFlag;
            elseif strcmp(prop,'HasASM')
                flag = smtfFlag;
            elseif any(strcmp(prop,{'RSMessageLength','RSInterleavingDepth','IsRSMessageShortened'}))
                flag = ~any(strcmp(obj.ChannelCoding,{'RS','concatenated'})) || isFACM;
            elseif strcmp(prop,'RSShortenedMessageLength')
                flag = ~any(strcmp(obj.ChannelCoding,{'RS','concatenated'}));
                if ~flag && obj.IsRSMessageShortened
                    flag = false;
                else
                    flag = true;
                end
                flag = flag  || isFACM;
            elseif strcmp(prop,'Modulation')
                flag = isFACM;
            elseif strcmp(prop,'PCMFormat')
                flag = ~any(strcmp(obj.Modulation,{'PCM/PSK/PM','BPSK','QPSK','8PSK','OQPSK'})) || isFACM;
            elseif any(strcmp(prop, {'DisableFrameSynchronization','DisablePhaseAmbiguityResolution'}))
                flag = false; % Always visible
            end
        end
    end

    methods(Access = protected, Static)
        function group = getPropertyGroupsImpl
            % Define property section(s) for System block dialog
            genprops = {'ChannelCoding',...
                'HasRandomizer',...
                'HasASM',...
                'DisableFrameSynchronization',...
                'DisablePhaseAmbiguityResolution',...
                'NumBytesInTransferFrame',...
                'ConvolutionalCodeRate',...
                'ViterbiTraceBackDepth',...
                'ViterbiTrellis',...
                'ViterbiWordLength',...
                'RSMessageLength',...
                'RSInterleavingDepth',...
                'IsRSMessageShortened',...
                'RSShortenedMessageLength',...
                'Modulation',...
                'PCMFormat'};
            group = matlab.system.display.SectionGroup('PropertyList', genprops);
        end
    end
end
