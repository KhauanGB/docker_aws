#!/bin/bash
# Atualiza os pacotes do sistema
sudo yum update -y

# Instala o Docker
sudo yum install -y docker

# Inicia e habilita o serviço Docker
sudo systemctl start docker
sudo systemctl enable docker

# Adiciona o usuário ec2-user ao grupo docker
sudo usermod -aG docker ec2-user

# Instala o Docker Compose
sudo curl -L https://github.com/docker/compose/releases/download/v2.17.3/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Cria o diretório da aplicação
sudo mkdir /app

# Gera o arquivo docker-compose.yml com as instruções do WordPress
cat <<EOF > /app/docker-compose.yml
version: '3.3'
services:
  wordpress:
    image: wordpress
    restart: always
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: <RDS_ENDPOINT>
      WORDPRESS_DB_USER: <DB_USER>
      WORDPRESS_DB_PASSWORD: <DB_PASSWORD>
      WORDPRESS_DB_NAME: <DB_NAME>
    volumes:
      - /mnt/efs:/var/www/html
EOF

# Monta o EFS
sudo mkdir -p /mnt/efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport <EFS_ID>.efs.<REGION>.amazonaws.com:/ /mnt/efs

# Realiza o deploy da aplicação WordPress
cd /app
sudo docker-compose up -d
