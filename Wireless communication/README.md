Hi!

This is an IEEE 802.11a Wireless Local Area Network (WLAN) communication for image transmission uing MATLAB

The wireless communication part of the project shows how to encode and pack an image file into WLAN packets for transmission 
and subsequently decode the packets to retrieve the image. To facilitate the wireless communictation we used two adalm pluto sdr radios for transmission 
and reception of the waveform.

Required Hardware and Software to design and implement the wireless communicaion part in MATLAB:
1. Communication toolbox
2. ADALM PlutoSDR 
3. Software communication toolbox support package for ADALM PlutoSDR


Basic Block Diagram:

![alt text](/Images/blocks.jpg)

Note: The complete block diagram can be found on the main page README file one level up from here.

Image Transmission flow:
1. From computer 1 to Computer 2 (using 802.11a WLAN)
2. From computer 2 to Raspberry Pi (using TCP/IP socket programming)
3. Perform Image forgery detection on a Raspberry Pi (using Python) 
4. Send the processed image back to computer 2 (using TCP/IP socket programming)

Note: Step 3 - the image forgery detection part described in the "Image processing" folder one level up from here. 
                

The Wireless communication folder contains the transmitter and receiver MATLAB code that was used for this project. 
In addition, inside the Receiver folder there are client and server python codes. These codes creates a TCP/IP connection between the receiver computer (comp2)
and the Raspberry Pi. 

Introduction:
First, the Image is loaded and transmitted from a local computer (comp1) using 802.11a WLN communication on a "1 antenna" plotosdr. And the remote compter receives 
the transmitted image using another "1 antenna" pluto sdr. Once all the transmitted wave packets are received fully, then the MATLAB design reconstract and transmit 
the image to the Raspberry Pi using TCP/IP network connection. Then, the Raspberry Pi performs the image forgery detection and send the result back to the remote 
computer (comp2).

Transmitter Design:
The general structure of the WLAN transmitter can be described as follows:

1. Import an image from a local computer (comp1) and convert it to binary stream.
2. Scale it down using nearest neighbor algorithm. 
3. Split the data stream into smaller groups
4. Generate Media Access Control (MAC) frame and encode the data bits
5. Generate a baseband WLAN waveform, pack the data stream into multiple 802.11a packets.
6. Prepare the baseband signal for transmission using the PlutoSDR hardware.
7. Send the baseband data to the PlutoSDR hardware for upsampling and continuous transmission at the desired center frequency.


Receiver Design:

The general structure of the WLAN receiver can be described as follows:

1. Capture the transmitted wave-packets using another "1 antenna" PlutoSDR 
2. Perform carrier frequency offset estimation and correction
3. Extract the L-LTF and perform channel estimation and correction
4. Extract the L-SIG field to recover the modulation codding scheme (MCS) value and the length of the "Data" portion
5. Extract the data field and perform carrier frequency offset (CFO)
6. Decode the received PSDU and check if the frame check sequence (FCS) passed for the PSDU.
7. Order the decoded MSDUs based on the SequenceNumber property in the recovered MAC frame configuration object.
8. Combine the decoded MSDUs from all the transmitted packets to form the received image

The plot shown below is the received 802.11a WLAN packets:- 

![alt text](/Images/packet.jpg)


Usage:
1. Download the Transmitter and Receiver MATLAB code. 
2. Connect one plutoSDR for each transmit and receive computer
3. Run the Transmit MATLAB script first 
4. Run the Receive MATLAB script next 


Reference:         
MIMO-OFDM Wireless Communications with MATLAB®, Yong Soo Cho; Jaekwon Kim; Won Young Yang; Chung G. Kang
https://www.mathworks.com/help/wlan/software-defined-radio.html?s_tid=CRUX_lftnav: Image Transmission and Reception Using 802.11 Waveform and SDR
