classdef HelperCCSDSTMDemodulator < comm.internal.Helper & satcom.internal.ccsds.tmBase
    % HelperCCSDSTMDemodulator Demodulate the received complex symbols of
    % CCSDS telemetry
    %
    %   Note: This is a helper and its API and/or functionality may change
    %   in subsequent releases.
    %
    %   HDEMOD = HelperCCSDSTMDemodulator creates a CCSDS telemetry
    %   demodulator object, HDEMOD. The object is designed to demodulate
    %   the complex baseband telemetry signal that is compliant to CCSDS
    %   standard. The object supports demodulation of BPSK and QPSK
    %   signals. It is assumed that filtering is done before the signal is
    %   given to the HDEMOD object.
    %
    %   Step method syntax:
    %
    %   Y = step(HDEMOD,X) demodulates the complex baseband signal X and
    %   returns the demodulated symbols, Y. The object always gives out
    %   soft bits in the form of log likelihood ratios.
    %
    %   Limitations of the current System object:
    %   1. Currently demodulation of BPSK and QPSK are only supported
    %
    %   System objects may be called directly like a function instead of
    %   using the step method. For example, y = step(obj, x) and y = obj(x)
    %   are equivalent.
    %
    %   HelperCCSDSTMDemodulator properties:
    %
    %   Modulation                  - Modulation scheme
    %   PCMFormat                   - Pulse code modulation (PCM) format
    %   ChannelCoding               - Error control channel coding scheme
    
    %   Copyright 2020-2022 The MathWorks, Inc.
    
    % Public, non-tunable properties
    properties(Nontunable, Access = private)
        pDemod
    end
    
    properties(Access = private)
        pDreg % To store previous symbol for differential decoder
    end
    
    methods
        % Constructor
        function obj = HelperCCSDSTMDemodulator(varargin)
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:})
        end
    end
    
    methods(Access = protected)
        %% Common functions
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
            setupImpl@satcom.internal.ccsds.tmBase(obj);
            obj.pDreg = 1;
            if any(strcmp(obj.Modulation, {'QPSK','OQPSK'}))
                obj.pDemod = comm.PSKDemodulator('PhaseOffset',pi/4,'ModulationOrder',4,'BitOutput',true,...
                    'DecisionMethod',"Approximate log-likelihood ratio",'SymbolMapping','Custom',...
                    'CustomSymbolMapping',[0;2;3;1]);
            end
        end
        
        function y = stepImpl(obj,u)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            
            if isempty(u)
                y = complex(zeros(0, 1));
                return;
            end
            
            switch(obj.Modulation)
                case 'BPSK'
                    y = double(real(u));
                    if strcmp(obj.PCMFormat,'NRZ-M')
                        if ~any(strcmp(obj.ChannelCoding,{'convolutional','concatenated'}))
                            y(2:end) = y(2:end).*sign(y(1:end-1));
                            y(1) = y(1)*obj.pDreg;
                            obj.pDreg = sign(y(end));
                        end
                    end
                    % y = -1*y;
                case {'QPSK', '8PSK', 'OQPSK'}
                    % Observe that while doing symbol synchronization using
                    % comm.SymbolSynchronizer, offset in OQPSK is taken
                    % care of and sampling also happens properly. To make
                    % this happen, Modulation property of
                    % comm.SymbolSynchronizer object should be set to
                    % "OQPSK" when OQPSK is used. Only thing is there will
                    % be some delay which will be taken care by frame
                    % synchronizer.
%                     y = reshape([real(u(:)), imag(u(:))].', [], 1);
                    y = obj.pDemod(u);
                    if strcmp(obj.PCMFormat,'NRZ-M')
                        if ~any(strcmp(obj.ChannelCoding,{'convolutional','concatenated'}))
                            y(2:end) = y(2:end).*sign(y(1:end-1));
                            y(1) = y(1)*obj.pDreg;
                            obj.pDreg = sign(y(end));
                        end
                    end
                    y = -1*y;
            end
        end
        
        function resetImpl(obj)
            % Initialize / reset discrete-state properties
            obj.pDreg = 1;
        end
        
        %% Backup/restore functions
        function s = saveObjectImpl(obj)
            % Set properties in structure s to values in object obj
            
            % Set public properties and states
            s = saveObjectImpl@matlab.System(obj);
            
            % Set private and protected properties
            %s.myproperty = obj.myproperty;
        end
        
        function loadObjectImpl(obj,s,wasLocked)
            % Set properties in object obj to values in structure s
            
            % Set private and protected properties
            % obj.myproperty = s.myproperty;
            
            % Set public properties and states
            loadObjectImpl@matlab.System(obj,s,wasLocked);
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
            isFACM = false; % Currently FACM is not supported
            if strcmp(prop,'ChannelCoding')
                flag = false;
            elseif strcmp(prop,'Modulation')
                flag = isFACM;
            elseif strcmp(prop,'PCMFormat')
                flag = ~any(strcmp(obj.Modulation,{'PCM/PSK/PM','BPSK','QPSK','8PSK','OQPSK'})) || isFACM;
            end
        end
    end
    
    methods(Access = protected, Static)
        function group = getPropertyGroupsImpl
            % Define property section(s) for System block dialog
            genprops = {'Modulation', 'PCMFormat', 'ChannelCoding'};
            generalGroup = matlab.system.display.SectionGroup('PropertyList', genprops);
            group = generalGroup; % matlab.system.display.Section(mfilename("class"));
            
        end
    end
end
