Image Forgery (Copy-Move) Detection:

An image forgery is called as Copy-Move forgery if some part of an image is copied and pasted within that same image. This is usually done to suppress some 
information of the image. 

In this project, we desgin a copy-move image detection model in Python and implemented it on a Raspberry Pi. The model used a Scale Invarient Feature Transform (SIFT)
and Random Sample Consensus (RANSAC) algorithm to detect keypoints and remove wrong matches.

SIFT is a feature detection algorithm in Computer Vision. it helps locate the local features in an image, commonly known as the ‘keypoints‘ of the image. 
These keypoints are scale & rotation invariant that can be used for various computer vision applications, like image matching, object detection, scene detection, etc.

Its process divided into the following steps:

1. Scale Space constrauction: To make sure that features are scale-independent
2. Keypoint Localisation: Identifying the suitable features or keypoints
3. Orientation Assignment: Ensure the keypoints are rotation invariant
4. Keypoint Descriptor: Assign a unique fingerprint to each keypoint


Python Script:
"Image Processing" folder contains the image forgery detection python script. In addition, it has a client and server Python scripts for image transmission between
a remote computer (comp2) and Raspberry Pi. 


Basic Block Diagram:

 ___________        ___________          ____________
|           |      |           |        |            |
| Comp1 (Tx)|----->|Comp2 (Rx) | -----> |Raspberry Pi|
|___________|      |___________|        |____________|

Note: The complete block diagram can be found in the "Additional Documentation" folder one level up from here. Also, the wireless communication part is explained in
the "Wireless Communication" folder one level up from here. This readme file only focuses on the Image processing on the Raspberry Pi. 

![Image Result](/Images/Test1.jpg)

