import socket

localhost = '169.254.79.35'    #when using ethernet cable
#localhost = '192.168.0.30'       #when using wifi
port = 1234

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

