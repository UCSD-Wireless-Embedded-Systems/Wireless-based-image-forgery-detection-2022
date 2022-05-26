import cv2
import matplotlib.pyplot as plt
from PIL import Image
import numpy as np
from scipy.spatial.distance import pdist
from abc import ABCMeta, abstractmethod
from math import sqrt
from scipy.stats import stats

import socket

localhost = '169.254.79.35'    #when using ethernet cable
#localhost = '192.168.0.30'       #when using wifi
port = 5678

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
server.bind((localhost, port)) 
server.listen()

client_socket, client_address = server.accept()

file = open('server_image.jpg', "wb")
image_chunk = client_socket.recv(2048)  

while image_chunk:
    file.write(image_chunk)
    image_chunk = client_socket.recv(2048)

file.close()
client_socket.close()




# import I2C_LCD_driver
# from time import *
# mylcd = I2C_LCD_driver.lcd()

# mylcd.lcd_display_string("Process started!", 1,0)

def Ransac(match_kp1, match_kp2):
    inliers1 = []
    inliers2 = []
    count, rec = 0, 0
    p1 = np.float32([kp1.pt for kp1 in match_kp1])
    p2 = np.float32([kp2.pt for kp2 in match_kp2])
    #print(p1)
    #print(p2)
    homography, status = cv2.findHomography(p1, p2, cv2.RANSAC, 5.0)
    inliers_thresold = 2.5
    
    good_matches = []
    for i, m in enumerate(match_kp1):

        col = np.ones((3, 1), dtype=np.float64)
        col[0:2, 0] = m.pt
        col = np.dot(homography, col)
        col /= col[2, 0]
        
        distance = sqrt(pow(col[0, 0] - match_kp2[i].pt[0], 2) + pow(col[1, 0] - match_kp2[i].pt[1], 2))

        if distance < inliers_thresold:
            count = count + 1
            
    if count * 2.5 < len(match_kp1):
        inliers_thresold = 339
        rec = 3   
        
        
    for i, m in enumerate(match_kp1):

            col = np.ones((3, 1), dtype=np.float64)
            col[0:2, 0] = m.pt
            col = np.dot(homography, col)
            col /= col[2, 0]

            distance = sqrt(pow(col[0, 0] - match_kp2[i].pt[0], 2) +
                        pow(col[1, 0] - match_kp2[i].pt[1], 2))

            if distance < inliers_thresold:
                good_matches.append(cv2.DMatch(len(inliers1), len(inliers2), 0))
                inliers1.append(match_kp1[i])
                inliers2.append(match_kp2[i])
                
    print('# match:                                     \t', len(match_kp1))
    print('# Inliers that matches the given homography: \t', len(inliers1))

    good_points1 = np.float32([kp1.pt for kp1 in inliers1])
    good_points2 = np.float32([kp2.pt for kp2 in inliers2])

    return good_points1, good_points2, rec            


class MatchFeatures:

    descriptors = None
    key_points = None
    distances = None
    gPoint1 = None
    gPoint2 = None
    cRectangle = None

    def __init__(self, key_points, descriptors, distances):
        self.key_points = key_points
        self.descriptors = descriptors
        self.distances = distances
        self.Match()

    def Match(self):
        bf = cv2.BFMatcher(self.distances)
        matches = bf.knnMatch(self.descriptors, self.descriptors, k=10)
        ratio = 0.5
        mkp1, mkp2 = [], []

        for m in matches:
            j = 1

            while m[j].distance < ratio * m[j + 1].distance:
                j = j + 1

            for k in range(1, j):
                temp = m[k]

                if pdist(np.array([self.key_points[temp.queryIdx].pt,
                                   self.key_points[temp.trainIdx].pt])) > 10:
                    mkp1.append(self.key_points[temp.queryIdx])
                    mkp2.append(self.key_points[temp.trainIdx])

        # remove the false matches
        self.gPoint1, self.gPoint2, self.cRectangle = Ransac(mkp1, mkp2)
        
        
        
class AbstractShape(metaclass=ABCMeta):

    @abstractmethod
    def draw(self, image, key_points1, key_points2, color): pass
    
    
class DrawLine(AbstractShape):
    image = None
    key_points1 = None
    key_points2 = None
    color = None

    def __init__(self, image, keypoints1, keypoints2, color):
        self.image = image
        self.key_points1 = keypoints1
        self.key_points2 = keypoints2
        self.color = color
        self.draw()

    def draw(self, **kwargs):
        forgery = self.image.copy()
        for keypoint1, keypoint2 in zip(self.key_points1, self.key_points2):
            if len(self.key_points1) > 1:
                cv2.line(forgery, (int(keypoint1[0]), int(keypoint1[1])), (int(keypoint2[0]), int(keypoint2[1])), self.color, 1)

        self.image = forgery
     
     
class DrawRectangle(AbstractShape):

    image = None
    keypoints1 = None
    keypoints2 = None
    color = None
    cRectangle = None

    def __init__(self, image, keypoints1, keypoints2, color, count_rectangle):
        self.image = image
        self.keypoints1 = keypoints1
        self.keypoints2 = keypoints2
        self.color = color
        self.cRectangle = count_rectangle  # counts of rectangle
        self.draw()

    def draw(self, **kwargs):
        new_image = self.image.copy()

        if self.cRectangle == 0:
            k1x, k2x = np.max(self.keypoints1, axis=0), np.max(self.keypoints2, axis=0)
            k1n, k2n = np.min(self.keypoints1, axis=0), np.min(self.keypoints2, axis=0)
            cv2.rectangle(new_image, (int(k2x[0]) + 10, int(k2n[1]) - 10), (int(k2n[0]) - 10, int(k2x[1]) + 10), self.color, 3)
            cv2.rectangle(new_image, (int(k1x[0]) + 10, int(k1n[1]) - 10), (int(k1n[0]) - 10, int(k1x[1]) + 10), self.color, 3)
            self.image = new_image
        # elif self.cRectangle == 3:
        #     point_list, z = np.zeros(len(self.keypoints1)), 0
        #     z2, z3, z4 = np.array([[0, 0]]), np.array([[0, 0]]), np.array([[0, 0]])
        #     for k1, k2 in zip(self.keypoints1, self.keypoints2):
        #         if len(self.keypoints1) > 1:
        #             p = (k1[0] - k2[0]) / (k1[1] - k2[1])
        #             point_list[z] = int(p)
        #             z = z + 1
        #     for k1, k2 in zip(self.keypoints1, self.keypoints2):
        #         if len(self.keypoints1) > 1:
        #             p = (k1[0] - k2[0]) / (k1[1] - k2[1])
        #             p = int(p)
        #             if p == max(point_list):
        #                 newrow = [k1[0], k1[1]]
        #                 z2 = np.vstack([z2, newrow])
        #             elif p < 0:
        #                 newrow = [k1[0], k1[1]]
        #                 z3 = np.vstack([z3, newrow])
        #                 newrow = [k2[0], k2[1]]
        #                 z4 = np.vstack([z4, newrow])
        #
        #     k1x, k11x, k2x = np.max(z3, axis=0), np.max(z2, axis=0), np.max(z4, axis=0)
        #     z2[0], z3[0], z4[0] = k11x, k1x, k2x
        #     k11n, k1n, k2n = np.min(z2, axis=0), np.min(z3, axis=0), np.min(z4, axis=0)
        #
        #     cv2.rectangle(new_image, (int(k2x[0]) + 10, int(k2n[1]) - 10), (int(k2n[0]) - 10, int(k2x[1]) + 10), self.color, 3)
        #     cv2.rectangle(new_image, (int(k11x[0]) + 10, int(k11n[1]) - 10), (int(k11n[0]) - 10, int(k11x[1]) + 10), self.color, 3)
        #     cv2.rectangle(new_image, (int(k1x[0]) + 10, int(k1n[1]) - 10), (int(k1n[0]) - 10, int(k1x[1]) + 10), self.color, 3)
        # self.image = new_image
        elif self.cRectangle == 3:
            egimlist, x = np.empty(0), 0
            reclist1, reclist2, reclist3 = np.empty(shape=[0, 2]), np.empty(shape=[0, 2]), np.empty(shape=[0, 2])
            for k1, k2 in zip(self.keypoints1, self.keypoints2):
                if len(self.keypoints1) > 1:
                    egim = (k1[0] - k2[0]) / (k1[1] - k2[1])
                    egim = int(egim)
                    egimlist = np.append(egimlist, [egim])
            mode = stats.mode(egimlist)

            while x != len(egimlist):
                if egimlist[x] == mode[0]:
                    egimlist = np.delete(egimlist, x)
                else:
                    x = x + 1
            mode2 = stats.mode(egimlist)
            for k1, k2 in zip(self.keypoints1, self.keypoints2):
                if len(self.keypoints1) > 1:
                    egim = (k1[0] - k2[0]) / (k1[1] - k2[1])
                    egim = int(egim)
                    if egim == mode[0]:
                        reclist1 = np.append(reclist1, [[k1[0], k1[1]]], axis=0)
                        reclist3 = np.append(reclist3, [[k2[0], k2[1]]], axis=0)
                    elif egim == mode2[0] or mode2[1] * 2 <= mode[1]:
                        reclist2 = np.append(reclist2, [[k1[0], k1[1]]], axis=0)

            k1x, k11x, k2x = np.max(reclist2, axis=0), np.max(reclist1, axis=0), np.max(reclist3, axis=0)
            k11n, k1n, k2n = np.min(reclist1, axis=0), np.min(reclist2, axis=0), np.min(reclist3, axis=0)

            cv2.rectangle(new_image, (int(k2x[0]) + 10, int(k2n[1]) - 10), (int(k2n[0]) - 10, int(k2x[1]) + 10),
                          self.color, 3)
            cv2.rectangle(new_image, (int(k11x[0]) + 10, int(k11n[1]) - 10), (int(k11n[0]) - 10, int(k11x[1]) + 10),
                          self.color, 3)
            cv2.rectangle(new_image, (int(k1x[0]) + 10, int(k1n[1]) - 10), (int(k1n[0]) - 10, int(k1x[1]) + 10),
                          self.color, 3)

        self.image = new_image               


class AbstractDetector(metaclass=ABCMeta):
    key_points = None
    descriptors = None
    color = None
    image = None
    distance = None
    MatchFeatures = None
    Draw = None

    def __init__(self, image):
        self.image = image
        self.MatchFeatures = MatchFeatures(self.key_points, self.descriptors, self.distance)  # match points
        self.Draw = DrawRectangle(self.image, self.MatchFeatures.gPoint1, self.MatchFeatures.gPoint2, self.color, self.MatchFeatures.cRectangle)  # draw matches
        #self.Draw = DrawLine(self.image,  self.MatchFeatures.gPoint1,  self.MatchFeatures.gPoint2, self.color) # from DrawFunctions.Line import DrawLine -> import it
        self.image = self.Draw.image

    # detect keypoints and descriptors
    @abstractmethod
    def detectFeature(self):
        pass
        
        
# copy-move forgery detection with sift
class SiftDetector(AbstractDetector):
    # blue
    image = None
    key_points = None
    descriptors = None
    color = (0, 0, 255)
    distance = cv2.NORM_L2

    def __init__(self, image):
        self.image = image
        self.detectFeature()
        super().__init__(self.image)

    # detect keypoints and descriptors
    def detectFeature(self):
        sift = cv2.SIFT_create()
        gray = cv2.cvtColor(self.image, cv2.COLOR_BGR2GRAY)
        self.key_points, self.descriptors = sift.detectAndCompute(gray, None)

        
        #plt.imshow(gray)
        #plt.show()        
        
        
image_orig = cv2.imread('server_image.jpg')
image_scaled = cv2.resize(image_orig, (0, 0), fx=0.2, fy=0.2)
image_rgb = cv2.cvtColor(image_orig, cv2.COLOR_BGR2RGB)
sift = SiftDetector(image_rgb)
image_sift = sift.image

img = Image.fromarray(image_sift, 'RGB')
img.save('image_sift.jpg')
#print(img.format)
#img.show()

##################Client to send the image bace to remote computer############################



localhost = '169.254.79.1'  #when using ethernet cable
#localhost = '192.168.0.107'     #when using wifi
port = 1234

client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # AF_INET = IP, SOCK_STREAM = TCP
client.connect((localhost, port)) 

file = open('image_sift.jpg', 'rb')
image_data = file.read(2048)

while image_data:
    client.send(image_data)
    image_data = file.read(2048)

file.close()
client.close()


# In[ ]:




# For ploting purpose

RGB_img = cv2.cvtColor(image_orig, cv2.COLOR_BGR2RGB)
RGB_scaled = cv2.cvtColor(image_scaled, cv2.COLOR_BGR2RGB)
gray_img = cv2.cvtColor(image_orig, cv2.COLOR_BGR2GRAY)
GRAY_img = cv2.cvtColor(gray_img, cv2.COLOR_BGR2RGB)

# mylcd.lcd_clear()
# mylcd.lcd_display_string("Process completed!", 2,0)
# # sleep(2)
# # mylcd.lcd_clear()


# create figure
fig = plt.figure(figsize=(10, 7))
  
# setting values to rows and column variables
rows = 2
columns = 2

# Adds a subplot at the 2nd position
fig.add_subplot(rows, columns, 1)
  
# showing image
plt.imshow(RGB_img)
plt.title("RGB_img")

# Adds a subplot at the 1st position
fig.add_subplot(rows, columns, 2)
  
# showing image
plt.imshow(GRAY_img)
plt.title("GRAY_img")

# Adds a subplot at the 3rd position
fig.add_subplot(rows, columns, 3)
  
# showing image
plt.imshow(RGB_scaled)
plt.title("RGB_scaled")
  
# Adds a subplot at the 4th position
fig.add_subplot(rows, columns, 4)
  
# showing image
plt.imshow(image_sift)
plt.title("image_sift")
plt.show()






      
