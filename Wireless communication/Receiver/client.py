import socket

localhost = '169.254.79.35'  #when using ethernet cable
#localhost = '192.168.0.30'     #when using wifi
port = 5678

client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  # AF_INET = IP, SOCK_STREAM = TCP
client.connect((localhost, port)) 

file = open('outputImagerx.jpeg', 'rb')
image_data = file.read(2048)

while image_data:
    client.send(image_data)
    image_data = file.read(2048)

file.close()
client.close()


# In[ ]:




