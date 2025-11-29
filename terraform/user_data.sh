#!/bin/bash
# Script para instalar Docker e Docker Compose na inicialização

# 1. Atualiza o sistema e instala o Docker (para Amazon Linux 2023)
sudo yum update -y
sudo yum install -y docker

# 2. Inicia o serviço Docker e adiciona o usuário ec2-user ao grupo docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# 3. Instala o Docker Compose (V2)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 4. Cria o link simbólico que o script de deploy espera
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Nota: A sessão SSH para o deploy será uma nova, então as permissões do grupo docker funcionarão.