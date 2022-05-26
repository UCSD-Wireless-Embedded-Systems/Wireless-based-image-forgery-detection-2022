clc;
clear;
close all;

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

%  Initialize SDR device
deviceNameSDR = 'Pluto'; % Set SDR Device
radio = sdrdev(deviceNameSDR);           % Create SDR device object

txGain = -10;

% Input an image file and convert to binary stream
fileTx = 'cat.jpeg';            % Image file name
fData = imread(fileTx);            % Read image data from file
scale = 0.2;                       % Image scaling factor
origSize = size(fData);            % Original input image size
scaledSize = max(floor(scale.*origSize(1:2)),1); % Calculate new image size
heightIx = min(round(((1:scaledSize(1))-0.5)./scale+0.5),origSize(1));
widthIx = min(round(((1:scaledSize(2))-0.5)./scale+0.5),origSize(2));
fData = fData(heightIx,widthIx,:); % Resize image
imsize = size(fData);              % Store new image size
txImage = fData(:);

% Plot transmit image
figure(imFig);
imFig.Visible = 'on';
% subplot(211);
    imshow(fData);
    title('Transmitted Image');
% subplot(212);
%     title('Received image will appear here...');
%     set(gca,'Visible','off');
%     set(findall(gca, 'type', 'text'), 'visible', 'on');

pause(1); % Pause to plot Tx image

msduLength = 2304; % MSDU length in bytes
numMSDUs = ceil(length(txImage)/msduLength);
padZeros = msduLength-mod(length(txImage),msduLength);
txData = [txImage; zeros(padZeros,1)];
txDataBits = double(reshape(de2bi(txData, 8)', [], 1));

% Divide input data stream into fragments
bitsPerOctet = 8;
data = zeros(0, 1);

for ind=0:numMSDUs-1

    % Extract image data (in octets) for each MPDU
    frameBody = txData(ind*msduLength+1:msduLength*(ind+1),:);

    % Create MAC frame configuration object and configure sequence number
    cfgMAC = wlanMACFrameConfig('FrameType', 'Data', 'SequenceNumber', ind);

    % Generate MPDU
    [mpdu, lengthMPDU]= wlanMACFrame(frameBody, cfgMAC);

    % Convert MPDU bytes to a bit stream
    psdu = reshape(de2bi(hex2dec(mpdu), 8)', [], 1);

    % Concatenate PSDUs for waveform generation
    data = [data; psdu]; %#ok<AGROW>

end

nonHTcfg = wlanNonHTConfig;         % Create packet configuration
nonHTcfg.MCS = 6;                   % Modulation: 64QAM Rate: 2/3
nonHTcfg.NumTransmitAntennas = 1;   % Number of transmit antenna
chanBW = nonHTcfg.ChannelBandwidth;
nonHTcfg.PSDULength = lengthMPDU;   % Set the PSDU length

% The sdrTransmitter uses the |transmitRepeat| functionality to transmit
% the baseband WLAN waveform in a loop from the DDR memory on the PlutoSDR.
% The transmitted RF signal is oversampled and transmitted at 30 MHz.  The
% 802.11a signal is transmitted on channel 5, which corresponds to a center
% frequency of 2.432 GHz as defined in section 15.4.4.3 of [1].

sdrTransmitter = sdrtx(deviceNameSDR); % Transmitter properties
sdrTransmitter.RadioID = 'usb:0';

% Resample the transmit waveform at 30 MHz
fs = wlanSampleRate(nonHTcfg); % Transmit sample rate in MHz
osf = 1.5;                     % Oversampling factor

sdrTransmitter.BasebandSampleRate = fs*osf;
sdrTransmitter.CenterFrequency = 2.432e9;  % Channel 5
sdrTransmitter.ShowAdvancedProperties = true;
sdrTransmitter.Gain = txGain;

% Initialize the scrambler with a random integer for each packet
scramblerInitialization = randi([1 127],numMSDUs,1);

% Generate baseband NonHT packets separated by idle time
txWaveform = wlanWaveformGenerator(data,nonHTcfg, ...
    'NumPackets',numMSDUs,'IdleTime',20e-6, ...
    'ScramblerInitialization',scramblerInitialization);

% Resample transmit waveform
txWaveform  = resample(txWaveform,fs*osf,fs);

fprintf('\nGenerating WLAN transmit waveform:\n')

% Scale the normalized signal to avoid saturation of RF stages
powerScaleFactor = 0.8;
txWaveform = txWaveform.*(1/max(abs(txWaveform))*powerScaleFactor);

% Transmit RF waveform
sdrTransmitter.transmitRepeat(txWaveform);

% release(sdrTransmitter)

