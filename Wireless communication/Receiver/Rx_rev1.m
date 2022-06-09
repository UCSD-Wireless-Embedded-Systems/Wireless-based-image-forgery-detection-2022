clc;
close all;
clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
deviceNameSDR = 'Pluto'; % Set SDR Device
sdrReceiver = sdrrx(deviceNameSDR);

sdrReceiver.BasebandSampleRate = 30000000;
sdrReceiver.CenterFrequency = 2.432e9;
sdrReceiver.GainSource = 'Manual';
sdrReceiver.Gain = 10;
sdrReceiver.OutputDataType = 'double';

nonHTcfg = wlanNonHTConfig;
chanBW = nonHTcfg.ChannelBandwidth;
bitsPerOctet = 8;
numMSDUs = 81;


% Setup handle for image plot
if ~exist('imFig', 'var') || ~ishandle(imFig)
    imFig = figure;
    imFig.NumberTitle = 'off';
    imFig.Name = 'Image Plot';
    imFig.Visible = 'off';
else
    clf(imFig); % Clear figure
    imFig.Visible = 'off';
end

% Setup Spectrum viewer
spectrumScope = dsp.SpectrumAnalyzer( ...
    'SpectrumType', 'Power density', ...
    'SpectralAverages', 10, ...
    'YLimits', [-130 -50], ...
    'Title', 'Received Baseband WLAN Signal Spectrum', ...
    'YLabel', 'Power spectral density', ...
    'Position', [69 376 800 450]);

% Setup the constellation diagram viewer for equalized WLAN symbols
constellation = comm.ConstellationDiagram(...
    'Title', 'Equalized WLAN Symbols', ...
    'ShowReferenceConstellation', false, ...
    'Position', [878 376 460 460]);



% Resampling
fs = wlanSampleRate(nonHTcfg); % Transmit sample rate in MHz
osf = 1.5;                     % Oversampling factor


captureLength = 2*1049760;                                           
spectrumScope.SampleRate = sdrReceiver.BasebandSampleRate;

% Get the required field indices within a PSDU
indLSTF = wlanFieldIndices(nonHTcfg,'L-STF');
indLLTF = wlanFieldIndices(nonHTcfg,'L-LTF');
indLSIG = wlanFieldIndices(nonHTcfg,'L-SIG');
Ns = indLSIG(2)-indLSIG(1)+1; % Number of samples in an OFDM symbol

fprintf('\nStarting a new RF capture.\n')

burstCaptures = capture(sdrReceiver, captureLength, 'Samples');

spectrumScope(burstCaptures);

% Downsample the received signal
rxWaveform = resample(burstCaptures,fs,fs*osf);
rxWaveformLen = size(rxWaveform,1);
searchOffset = 0; % Offset from start of the waveform in samples

lstfLen = double(indLSTF(2)); % Number of samples in L-STF
minPktLen = lstfLen*5;
pktInd = 1;
sr = wlanSampleRate(nonHTcfg); % Sampling rate
fineTimingOffset = [];
packetSeq = [];
displayFlag = 0; % Flag to display the decoded information

% Perform Error Vector Magnitude calculation
evmCalculator = comm.EVM('AveragingDimensions',[1 2 3]);
evmCalculator.MaximumEVMOutputPort = true;

% Receiver processing
while (searchOffset + minPktLen) <= rxWaveformLen
    %Detecting a packet
    pktOffset = wlanPacketDetect(rxWaveform, chanBW, searchOffset, 0.8);

    % Adjusting the offset
    pktOffset = searchOffset+pktOffset;
    if isempty(pktOffset) || (pktOffset+double(indLSIG(2))>rxWaveformLen)
        if pktInd==1
            disp('** No packet has detected **');
        end
        break;
    end

    nonHT = rxWaveform(pktOffset+(indLSTF(1):indLSIG(2)),:);
    coarseFreqOffset = wlanCoarseCFOEstimate(nonHT,chanBW);
    fineTimingOffset = wlanSymbolTimingEstimate(nonHT,chanBW);
    pktOffset = pktOffset+fineTimingOffset;
    if (pktOffset<0) || ((pktOffset+minPktLen)>rxWaveformLen)
        searchOffset = pktOffset+1.5*lstfLen;
        continue;
    end
    fprintf('\nPacket-%d detected at index %d\n',pktInd,pktOffset+1);
    nonHT = rxWaveform(pktOffset+(1:7*Ns),:);
    lltf = nonHT(indLLTF(1):indLLTF(2),:);           
    fineFreqOffset = wlanFineCFOEstimate(lltf,chanBW);
    cfoCorrection = coarseFreqOffset+fineFreqOffset; 

    % Channel estimation 
    lltf = nonHT(indLLTF(1):indLLTF(2),:);
    demodLLTF = wlanLLTFDemodulate(lltf,chanBW);
    chanEstLLTF = wlanLLTFChannelEstimate(demodLLTF,chanBW);

    % Noise estimation
    noiseVarNonHT = helperNoiseEstimate(demodLLTF);

    format = wlanFormatDetect(nonHT(indLLTF(2)+(1:3*Ns),:), ...
        chanEstLLTF,noiseVarNonHT,chanBW);
    disp(['  ' format ' format detected']);
    if ~strcmp(format,'Non-HT')
        fprintf('  A format other than Non-HT has been detected\n');
        searchOffset = pktOffset+1.5*lstfLen;
        continue;
    end

    [recLSIGBits,failCheck] = wlanLSIGRecover( ...
           nonHT(indLSIG(1):indLSIG(2),:), ...
           chanEstLLTF,noiseVarNonHT,chanBW);

    if failCheck
        fprintf('  L-SIG check fail \n');
        searchOffset = pktOffset+1.5*lstfLen;
        continue;
    else
        fprintf('  L-SIG check pass \n');
    end

    [lsigMCS,lsigLen,rxSamples] = helperInterpretLSIG(recLSIGBits,sr);

    if (rxSamples+pktOffset)>length(rxWaveform)
        disp('** Not enough samples to decode packet **');
        break;
    end

    rxNonHTcfg = wlanNonHTConfig;
    rxNonHTcfg.MCS = lsigMCS;
    rxNonHTcfg.PSDULength = lsigLen;
    indNonHTData = wlanFieldIndices(rxNonHTcfg,'NonHT-Data');
    [rxPSDU,eqSym] = wlanNonHTDataRecover(rxWaveform(pktOffset+...
           (indNonHTData(1):indNonHTData(2)),:), ...
           chanEstLLTF,noiseVarNonHT,rxNonHTcfg);

    constellation(reshape(eqSym,[],1)); % Current constellation
    pause(0); % Allow constellation to repaint
    release(constellation); % Release previous constellation plot

    refSym = wlanClosestReferenceSymbol(eqSym,rxNonHTcfg);
    [evm.RMS,evm.Peak] = evmCalculator(refSym,eqSym);
    [cfgMACRx, msduList{pktInd}, status] = wlanMPDUDecode(rxPSDU, rxNonHTcfg); %#ok<*SAGROW>

    if strcmp(status, 'Success')
        disp('  MAC FCS check pass');
        packetSeq(pktInd) = cfgMACRx.SequenceNumber;
        rxBit{pktInd} = reshape(de2bi(hex2dec(cell2mat(msduList{pktInd})), 8)', [], 1);
    else % Decoding failed
        if strcmp(status, 'FCSFailed')
            disp('  MAC FCS check fail');
        else
            disp('  MAC FCS check pass');
        end
        macHeaderBitsLength = 24*bitsPerOctet;
        fcsBitsLength = 4*bitsPerOctet;
        msduList{pktInd} = rxPSDU(macHeaderBitsLength+1 : end-fcsBitsLength);
        sequenceNumStartIndex = 23*bitsPerOctet+1;
        sequenceNumEndIndex = 25*bitsPerOctet - 4;
        packetSeq(pktInd) = bi2de(rxPSDU(sequenceNumStartIndex:sequenceNumEndIndex)');
        rxBit{pktInd} = double(msduList{pktInd});
    end

    if displayFlag
        fprintf('The estimated CFO is: %5.1f Hz\n\n',cfoCorrection); %#ok<UNRCH>

        disp('  Decoded L-SIG contents: ');
        fprintf('                            MCS: %d\n',lsigMCS);
        fprintf('                         Length: %d\n',lsigLen);
        fprintf('    Number of samples per packet: %d\n\n',rxSamples);

        fprintf('  EVM:\n');
        fprintf('    EVM peak: %0.3f%%  EVM RMS: %0.3f%%\n\n', ...
        evm.Peak,evm.RMS);

        fprintf('  Decoded MAC Sequence Control field contents:\n');
        fprintf('    Sequence number:%d\n',packetSeq(pktInd));
    end

    % Update search index
    searchOffset = pktOffset+double(indNonHTData(2));


    pktInd = pktInd+1;
    % Finish processing when a duplicate packet is detected. The
    % recovered data includes bits from duplicate frame
    if length(unique(packetSeq))<length(packetSeq)
        break
    end
end

imsize = [288,216,3];
if ~(isempty(fineTimingOffset)||isempty(pktOffset))&& ...
        (numMSDUs==(numel(packetSeq)-1))
    % Remove the duplicate captured MAC fragment
    rxBitMatrix = cell2mat(rxBit);
    rxData = rxBitMatrix(1:end,1:numel(packetSeq)-1);

    startSeq = find(packetSeq==0);
    rxData = circshift(rxData,[0 -(startSeq(1)-1)]);% Order MAC fragments
    fprintf('\nConstructing image from received data.\n');
    decdata = bi2de(reshape(rxData(1:186624*bitsPerOctet), 8, [])');   %length(txImage)=186624
    receivedImage = uint8(reshape(decdata,imsize));
    if exist('imFig', 'var') && ishandle(imFig) % If Tx figure is open
        figure(imFig); %subplot(212);
    else
        figure; %subplot(212);
    end
    imshow(receivedImage);
    imwrite(receivedImage,'outputImagerx.jpeg','Quality',100);
    title(sprintf('Received Image'));
end

%Uncomment lines from 242 to 249 to transmit and receive an image from computer 2 and Raspberry Pi
%system('python client.py');
%system('python server.py');


%fileTx1 = 'server_image1.jpg';            % Image file name
%fData1 = imread(fileTx1);
%imshow(fData1);
%title('sift Image');
