#!/bin/bash
# Script para instalar Docker, Docker Compose e Git na inicialização do EC2 (Amazon Linux 2023)

# 1. Atualiza o sistema
sudo yum update -y

# 2. Instala o Docker
sudo yum install -y docker

# 3. Inicia o Docker e adiciona ec2-user ao grupo docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# 4. Instala o Docker Compose (v2)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 5. Cria link simbólico para compatibilidade
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# 6. Instala Git
sudo yum install -y git

# 7. Nota: NÃO CRIAR O .env AQUI!
# O arquivo .env precisa ser criado no deploy via SSH usando os secrets do GitHub Actions,
# pois o EC2 não tem acesso a essas variáveis.
