clc;
close all;
clear;

%Create an object to interact with the PlutoSDR
DEV = sdrdev('Pluto');

%% Input image
img1 = imread('image1.jpg');    %original image ---image1 is any image in the "image folder", and place it in the transmitter folder

%Uncomment the following three lines to display the original image
% figure(1)
% imshow(img1)
% title("original image of img1");

%% 
sc = 0.2; % scaling factor 

%original image size 
img1_size = size(img1);

%scaled image
scaled1_size = max(floor(sc.*img1_size(1:2)),1);


%%height and width index
heightIx1 = min(round(((1:scaled1_size(1))-0.5)./sc+0.5),img1_size(1));
widthIx1 = min(round(((1:scaled1_size(2))-0.5)./sc+0.5),img1_size(2));

%scaled the original images
img11 = img1(heightIx1,widthIx1,:);  %Resize image
img11_size = size(img11);
img11_tx = img11(:);

%Uncomment the following four line to display the original and resized image
% figure(2)
% imshow(img1)
% hold on
% imshow(img11)


%% Fragment transmit data
MSDU_len1 = 2304; %byte
N_MSDU1 = ceil(length(img11_tx)/MSDU_len1);
zero_p1 = MSDU_len1 - mod(length(img11_tx),MSDU_len1);
tx_data1 = [img11_tx;zeros(zero_p1,1)];
tx_dbit1 = double(reshape(de2bi(tx_data1,8)',[],1)); 


%%Divide tx_dbit1 into fragments
bpo = 8;   %bits per octet
data1 = zeros(0,1);

for i = 0:N_MSDU1-1
    frame_body1 = tx_data1(i*MSDU_len1+1:MSDU_len1*(i+1),:); %frame body
    config1 = wlanMACFrameConfig('FrameType', 'Data', 'SequenceNumber', i);
    [frame1,frameLength1]= wlanMACFrame(frame_body1, config1); %generate mpdu
    psdu1 = reshape(de2bi(hex2dec(frame1), 8)', [], 1);
    %concatenate psdu for waveform generation
    data1 = [data1; psdu1]; %#ok<AGROW> 
end



%% Generate 802.11a baseboand WLAN signal
cfgNonHT = wlanNonHTConfig;
cfgNonHT.MCS = 6; %modulation QPSK rate: 2/3 
cfgNonHT.NumTransmitAntennas = 1; %number of tx antenna
chBW = cfgNonHT.ChannelBandwidth;
cfgNonHT.PSDULength = MSDU_len1;


h = sdrtx('Pluto'); %sdr transmitter system object for 'plutosdr'


fs  = wlanSampleRate(cfgNonHT);
usf = 1.5; %upsampling factor

h.BasebandSampleRate = fs*usf;
h.CenterFrequency = 2.432e9;
h.ShowAdvancedProperties = true;

%Transmit gain
Tx_gain = -10;

h.Gain = Tx_gain;


% Initialize the scrambler with a random integer for each packet
scrambler_init = randi([1 127],N_MSDU1,1);

% Generate baseband NonHT packets separated by idle time
waveform = wlanWaveformGenerator(data1,cfgNonHT, ...
    'NumPackets',N_MSDU1,'IdleTime',20e-6, ...
    'ScramblerInitialization',scrambler_init);

% Resample transmit waveform
waveform  = resample(waveform,fs*usf,fs);
fprintf('\nGenerating WLAN transmit waveform:\n')

% Scale the normalized signal to avoid saturation of RF stages
psf = 0.8; %power scale factor
waveform = waveform.*(1/max(abs(waveform))*psf);

% Transmit RF waveform
h.transmitRepeat(waveform);
