import socket

localhost = 'XXX.XXX.XX.XX'  #when using ethernet cable - ip address of Raspberry Pi
#localhost = 'XXX.XXX.XX.XX'     #when using wifi - ip address of Raspberry Pi
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




