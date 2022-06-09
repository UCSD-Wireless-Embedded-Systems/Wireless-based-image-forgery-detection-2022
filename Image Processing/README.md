Image Forgery (Copy-Move) Detection:

An image forgery is called as Copy-Move forgery if some part of an image is copied and pasted within that same image. This is usually done to suppress some 
information of the image. 

The image below shows the classification of Image forgery detection

![alt text](/Images/copy_move.jpg)

In this project, we desgin a copy-move image detection model in Python and implemented it on a Raspberry Pi. The model used a Scale Invarient Feature Transform (SIFT)
and Random Sample Consensus (RANSAC) algorithm to detect keypoints and remove wrong matches.

SIFT is a feature detection algorithm in Computer Vision. it helps locate the local features in an image, commonly known as the ‘keypoints‘ of the image. 
These keypoints are scale & rotation invariant that can be used for various computer vision applications, like image matching, object detection, scene detection, etc.

There are mainly four steps involved in SIFT algorithm

1. Scale Space constrauction: To make sure that features are scale-independent
2. Keypoint Localisation: Identifying the suitable features or keypoints
3. Orientation Assignment: Ensure the keypoints are rotation invariant
4. Keypoint Descriptor: Assign a unique fingerprint to each keypoint

Additional information about SIFT can be found on David G. Lowe's paper. The information is listed in the "Reference" section.

Basic Block Diagram:                                                                                                                                                  

![alt text](/Images/blocks.jpg)

Note: The complete block diagram can be found on the main page README file. Also, the wireless communication part is explained in
the "Wireless Communication" folder one level up from here. This readme file only focuses on the Image processing on the Raspberry Pi. 

************************************
Python Script:                                                                                                                                                     
"Image Processing" folder contains the image forgery detection python script. In addition, it has a client and server Python scripts for image transmission between
a remote computer (comp2) and Raspberry Pi. 



Usage: 
1. Download "Image Processing" or Clone the "wireless-based-image-forgery-detection" folder to your local computer.
2. Open the Image_forgery.py file
3. Use your own copy-moved(forged) image or have one from the "Image" folder
4. Plce it in the same folder with the "Image_forgery.py" file 
5. Run the code
6. The result should display with the copy-move part inside a blue squre (refer the results displayed below)




TEST RESULT
************************************
Figures below are the resultant image in which forged part is accurately detected after applying the SIFT algorithm on forged image.


![alt text](/Images/Test1.jpg)
************************************
![alt text](/Images/Test2.jpg)
************************************
![alt text](/Images/Test3.jpg)
************************************
![alt text](/Images/Test4.jpg)
************************************
![alt text](/Images/Test5.jpg)
************************************

Conclusion: 
In the proposed work, a SIFT algorithm is implemented to detect the copy move forgery in digital images. Proposed algorithm is tested on various images. And, the results show that the forged region is detected accurately by using the SIFT algorithm. 

Reference:                         
David G. Lowe "Distinctive Image Features from Scale-Invariant Keypoints”, International Journal of Computer Vision
Copy-Move Image Forgery Detection using Scale Invariant Feature Transform-  P. Parimala, Mrs. A. Naveena                                                               
Image used from this link - https://pixabay.com/
