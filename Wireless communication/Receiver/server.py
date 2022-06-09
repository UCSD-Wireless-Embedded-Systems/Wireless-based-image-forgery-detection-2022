import socket

localhost = 'XXX.XXX.XX.XX'    #when using ethernet cable - ip address of computer 2
#localhost = 'XXX.XXX.XX.XX'       #when using wifi - ip address of computer 2
port = 1234

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)  
server.bind((localhost, port)) 
server.listen()

client_socket, client_address = server.accept()

file = open('server_image1.jpg', "wb")
image_chunk = client_socket.recv(2048)  

while image_chunk:
    file.write(image_chunk)
    image_chunk = client_socket.recv(2048)

file.close()
client_socket.close()

