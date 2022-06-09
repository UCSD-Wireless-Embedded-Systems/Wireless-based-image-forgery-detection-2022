#!/usr/bin/env python
# coding: utf-8

# In[5]:


import socket

localhost = 'XXX.XXX.XX.XX'  #when using ethernet cable - Ip address of Computer 2
#localhost = 'XXX.XXX.XX.XX'     #when using wifi - Ip address of Computer 2
port = 1234

client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # AF_INET = IP, SOCK_STREAM = TCP
client.connect((localhost, port)) 

file = open('cat.jpeg', 'rb')
image_data = file.read(2048)

while image_data:
    client.send(image_data)
    image_data = file.read(2048)

file.close()
client.close()


# In[ ]:




