# Wireless-based-image-forgery-detection
WES 207 - Capstone project. Repository for MATLAB and Python programming for wireless-based image forgery detection using SIFT algorithm


Introduction:

This project has two parts: 
1. Wireless communication using 802.11a WLAN 
2. Image Processing for forgery detection

**************************************************************

Wireless communication using 802.11a WLAN:

The wireless communication part of the project shows how to encode and pack an image file into WLAN packets for transmission and subsequently decode the packets 
to retrieve the image. To facilitate the wireless communictation we used two adalm pluto sdr radios for transmission and reception of the waveform. 

Required Hardware and Software to design the wireless communicaion part in MATLAB:
1. Communication toolbox
2. ADALM PlutoSDR 
3. Software communication toolbox support package for ADALM PlutoSDR


The Wireless communication folder contains the transmitter and receiver MATLAB code that was used for this project.
In addition, inside the Receiver folder there are client and server python codes. These codeds are used to receive and transmit the reconstracted and processed image
between the remote computer and Raspberry Pi. 

The Image is loaded and transmitted from a local computer using 802.11a WLN communication on a "1 antenna" plotosdr. And the remote compter receives the transmitted 
image using another "1 antenna" pluto sdr. Once all the transmitted packets are received fully, then the MATLAB design reconstract and transmit the image to the 
Raspberry Pi. Then, the Raspberry Pi performs the image forgery detection and send the result back to the remote computer. 

For further pictorial desctripton, please refer to flow_chart located in the "Additional Documentation folder" 

**************************************************************

Image Processing for forgery detection:

The use of the Raspberry Pi is to process the image and Identify whether the image is forged or not. We used a scale invarient feature transform (SIFT)
algorithm inorder to detect the image features and key-point descriptors. 

To implement the image processing part of the project, we used the Raspberry Pi and the code is written in Python. The "Image Processing" folder includes the image 
forgery detection code. This folder also includes the client and server python code that was used for image transmission and reception between the remote computer and 
Raspberry Pi. 

The Python code that was used in this projects performs the the following SIFT algorithm. 

1. Constructing a Scale Space
   1.Gaussian Blur
   2.Difference of Gaussian
2. Keypoint Localization
   1.Local Maxima/Minima
   2.Keypoint Selection
3. Orientation Assignment
   1.Calculate Magnitude & Orientation
   2.Create Histogram of Magnitude & Orientation
4. Keypoint Descriptor
5. Feature Matching


      
Reference:
MATLAB: Image Transmission and Reception Using 802.11 Waveform and SDR

