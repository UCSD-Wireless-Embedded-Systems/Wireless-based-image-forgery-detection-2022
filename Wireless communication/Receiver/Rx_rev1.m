clc;
close all;
clear;

% Check that WLAN Toolbox is installed, and that there is a valid
% license
if isempty(ver('wlan')) % Check for WLAN Toolbox install
    error('Please install WLAN Toolbox to run this example.');
elseif ~license('test', 'WLAN_System_Toolbox') % Check that a valid license is present
    error( ...
        'A valid license for WLAN Toolbox is required to run this example.');
end

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
deviceNameSDR = 'Pluto'; % Set SDR Device
sdrReceiver = sdrrx(deviceNameSDR);
% sdrReceiver.RadioID = 'usb:0';

sdrReceiver.BasebandSampleRate = 30000000;
sdrReceiver.CenterFrequency = 2.432e9;
sdrReceiver.GainSource = 'Manual';
sdrReceiver.Gain = 10;
sdrReceiver.OutputDataType = 'double';

nonHTcfg = wlanNonHTConfig;
chanBW = nonHTcfg.ChannelBandwidth;
bitsPerOctet = 8;
numMSDUs = 81;

% Resample the transmit waveform at 30 MHz
fs = wlanSampleRate(nonHTcfg); % Transmit sample rate in MHz
osf = 1.5;                     % Oversampling factor

% Configure the capture length equivalent to twice the length of the
% transmitted signal, this is to ensure that PSDUs are received in order.
% On reception the duplicate MAC fragments are removed.
captureLength = 2*1049760;
spectrumScope.SampleRate = sdrReceiver.BasebandSampleRate;

% Get the required field indices within a PSDU
indLSTF = wlanFieldIndices(nonHTcfg,'L-STF');
indLLTF = wlanFieldIndices(nonHTcfg,'L-LTF');
indLSIG = wlanFieldIndices(nonHTcfg,'L-SIG');
Ns = indLSIG(2)-indLSIG(1)+1; % Number of samples in an OFDM symbol

fprintf('\nStarting a new RF capture.\n')

burstCaptures = capture(sdrReceiver, captureLength, 'Samples');

% Show power spectral density of the received waveform
spectrumScope(burstCaptures);

% Downsample the received signal
rxWaveform = resample(burstCaptures,fs,fs*osf);
rxWaveformLen = size(rxWaveform,1);
searchOffset = 0; % Offset from start of the waveform in samples

% Minimum packet length is 10 OFDM symbols
lstfLen = double(indLSTF(2)); % Number of samples in L-STF
minPktLen = lstfLen*5;
pktInd = 1;
sr = wlanSampleRate(nonHTcfg); % Sampling rate
fineTimingOffset = [];
packetSeq = [];
displayFlag = 0; % Flag to display the decoded information

% Perform EVM calculation
evmCalculator = comm.EVM('AveragingDimensions',[1 2 3]);
evmCalculator.MaximumEVMOutputPort = true;

% Receiver processing
while (searchOffset + minPktLen) <= rxWaveformLen
    % Packet detect
    pktOffset = wlanPacketDetect(rxWaveform, chanBW, searchOffset, 0.8);

    % Adjust packet offset
    pktOffset = searchOffset+pktOffset;
    if isempty(pktOffset) || (pktOffset+double(indLSIG(2))>rxWaveformLen)
        if pktInd==1
            disp('** No packet detected **');
        end
        break;
    end

    % Extract non-HT fields and perform coarse frequency offset correction
    % to allow for reliable symbol timing
    nonHT = rxWaveform(pktOffset+(indLSTF(1):indLSIG(2)),:);
    coarseFreqOffset = wlanCoarseCFOEstimate(nonHT,chanBW);
%     nonHT = frequencyOffset(nonHT,fs,-coarseFreqOffset);

    % Symbol timing synchronization
    fineTimingOffset = wlanSymbolTimingEstimate(nonHT,chanBW);

    % Adjust packet offset
    pktOffset = pktOffset+fineTimingOffset;

    % Timing synchronization complete: Packet detected and synchronized
    % Extract the non-HT preamble field after synchronization and
    % perform frequency correction
    if (pktOffset<0) || ((pktOffset+minPktLen)>rxWaveformLen)
        searchOffset = pktOffset+1.5*lstfLen;
        continue;
    end
    fprintf('\nPacket-%d detected at index %d\n',pktInd,pktOffset+1);

    % Extract first 7 OFDM symbols worth of data for format detection and
    % L-SIG decoding
    nonHT = rxWaveform(pktOffset+(1:7*Ns),:);
%     nonHT = frequencyOffset(nonHT,fs,-coarseFreqOffset);

    % Perform fine frequency offset correction on the synchronized and
    % coarse corrected preamble fields
    lltf = nonHT(indLLTF(1):indLLTF(2),:);           % Extract L-LTF
    fineFreqOffset = wlanFineCFOEstimate(lltf,chanBW);
%     nonHT = frequencyOffset(nonHT,fs,-fineFreqOffset);
    cfoCorrection = coarseFreqOffset+fineFreqOffset; % Total CFO

    % Channel estimation using L-LTF
    lltf = nonHT(indLLTF(1):indLLTF(2),:);
    demodLLTF = wlanLLTFDemodulate(lltf,chanBW);
    chanEstLLTF = wlanLLTFChannelEstimate(demodLLTF,chanBW);

    % Noise estimation
    noiseVarNonHT = helperNoiseEstimate(demodLLTF);

    % Packet format detection using the 3 OFDM symbols immediately
    % following the L-LTF
    format = wlanFormatDetect(nonHT(indLLTF(2)+(1:3*Ns),:), ...
        chanEstLLTF,noiseVarNonHT,chanBW);
    disp(['  ' format ' format detected']);
    if ~strcmp(format,'Non-HT')
        fprintf('  A format other than Non-HT has been detected\n');
        searchOffset = pktOffset+1.5*lstfLen;
        continue;
    end

    % Recover L-SIG field bits
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

    % Retrieve packet parameters based on decoded L-SIG
    [lsigMCS,lsigLen,rxSamples] = helperInterpretLSIG(recLSIGBits,sr);

    if (rxSamples+pktOffset)>length(rxWaveform)
        disp('** Not enough samples to decode packet **');
        break;
    end

    % Apply CFO correction to the entire packet
%     rxWaveform(pktOffset+(1:rxSamples),:) = frequencyOffset(...
%         rxWaveform(pktOffset+(1:rxSamples),:),fs,-cfoCorrection);

    % Create a receive Non-HT config object
    rxNonHTcfg = wlanNonHTConfig;
    rxNonHTcfg.MCS = lsigMCS;
    rxNonHTcfg.PSDULength = lsigLen;

    % Get the data field indices within a PPDU
    indNonHTData = wlanFieldIndices(rxNonHTcfg,'NonHT-Data');

    % Recover PSDU bits using transmitted packet parameters and channel
    % estimates from L-LTF
    [rxPSDU,eqSym] = wlanNonHTDataRecover(rxWaveform(pktOffset+...
           (indNonHTData(1):indNonHTData(2)),:), ...
           chanEstLLTF,noiseVarNonHT,rxNonHTcfg);

    constellation(reshape(eqSym,[],1)); % Current constellation
    pause(0); % Allow constellation to repaint
    release(constellation); % Release previous constellation plot

    refSym = wlanClosestReferenceSymbol(eqSym,rxNonHTcfg);
    [evm.RMS,evm.Peak] = evmCalculator(refSym,eqSym);

    % Decode the MPDU and extract MSDU
    [cfgMACRx, msduList{pktInd}, status] = wlanMPDUDecode(rxPSDU, rxNonHTcfg); %#ok<*SAGROW>

    if strcmp(status, 'Success')
        disp('  MAC FCS check pass');

        % Store sequencing information
        packetSeq(pktInd) = cfgMACRx.SequenceNumber;

        % Convert MSDU to a binary data stream
        rxBit{pktInd} = reshape(de2bi(hex2dec(cell2mat(msduList{pktInd})), 8)', [], 1);

    else % Decoding failed
        if strcmp(status, 'FCSFailed')
            % FCS failed
            disp('  MAC FCS check fail');
        else
            % FCS passed but encountered other decoding failures
            disp('  MAC FCS check pass');
        end

        % Since there are no retransmissions modeled in this example, we'll
        % extract the image data (MSDU) and sequence number from the MPDU,
        % even though FCS check fails.

        % Remove header and FCS. Extract the MSDU.
        macHeaderBitsLength = 24*bitsPerOctet;
        fcsBitsLength = 4*bitsPerOctet;
        msduList{pktInd} = rxPSDU(macHeaderBitsLength+1 : end-fcsBitsLength);

        % Extract and store sequence number
        sequenceNumStartIndex = 23*bitsPerOctet+1;
        sequenceNumEndIndex = 25*bitsPerOctet - 4;
        packetSeq(pktInd) = bi2de(rxPSDU(sequenceNumStartIndex:sequenceNumEndIndex)');

        % MSDU binary data stream
        rxBit{pktInd} = double(msduList{pktInd});
    end

    % Display decoded information
    if displayFlag
        fprintf('  Estimated CFO: %5.1f Hz\n\n',cfoCorrection); %#ok<UNRCH>

        disp('  Decoded L-SIG contents: ');
        fprintf('                            MCS: %d\n',lsigMCS);
        fprintf('                         Length: %d\n',lsigLen);
        fprintf('    Number of samples in packet: %d\n\n',rxSamples);

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

% Release the state of sdrTransmitter and sdrReceiver object
% release(sdrTransmitter);
% release(sdrReceiver);
imsize = [288,216,3];
if ~(isempty(fineTimingOffset)||isempty(pktOffset))&& ...
        (numMSDUs==(numel(packetSeq)-1))
    % Remove the duplicate captured MAC fragment
    rxBitMatrix = cell2mat(rxBit);
    rxData = rxBitMatrix(1:end,1:numel(packetSeq)-1);

    startSeq = find(packetSeq==0);
    rxData = circshift(rxData,[0 -(startSeq(1)-1)]);% Order MAC fragments

    % Perform bit error rate (BER) calculation
%     bitErrorRate = comm.ErrorRate;
%     err = bitErrorRate(double(rxData(:)), ...
%                     txDataBits(1:length(reshape(rxData,[],1))));
%     fprintf('  \nBit Error Rate (BER):\n');
%     fprintf('          Bit Error Rate (BER) = %0.5f.\n',err(1));
%     fprintf('          Number of bit errors = %d.\n', err(2));
%     fprintf('    Number of transmitted bits = %d.\n\n',length(txDataBits));

    % Recreate image from received data
    fprintf('\nConstructing image from received data.\n');

    decdata = bi2de(reshape(rxData(1:186624*bitsPerOctet), 8, [])');   %length(txImage)=186624

    receivedImage = uint8(reshape(decdata,imsize));
    % Plot received image
    if exist('imFig', 'var') && ishandle(imFig) % If Tx figure is open
        figure(imFig); %subplot(212);
    else
        figure; %subplot(212);
    end
    imshow(receivedImage);
    imwrite(receivedImage,'outputImagerx.jpeg','Quality',100);
    title(sprintf('Received Image'));
end

system('python client.py');
system('python server.py');


fileTx1 = 'server_image1.jpg';            % Image file name
fData1 = imread(fileTx1);
imshow(fData1);
title('sift Image');
