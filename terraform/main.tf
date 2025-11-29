# Configurações globais do Terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  
  # -----------------------------------------------------------
  # BACKEND REMOTO: Armazena o estado no S3.
  # -----------------------------------------------------------
  backend "s3" {
    # 🛑 SUBSTITUA: Use o nome **real** e único do seu bucket S3
    bucket         = "terraform-state-vinciuslim" 
    key            = "trabalho-cicd/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

# Definição do Provider
provider "aws" {
  region = "us-east-1" # Mude se for usar outra região
}

# -----------------------------------------------------------
# 1. BUSCA DE IMAGEM (AMI)
# -----------------------------------------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
  owners = ["amazon"]
}

# -----------------------------------------------------------
# 2. SEGURANÇA (Security Group)
# -----------------------------------------------------------
resource "aws_security_group" "app_sg" {
  name_prefix = "app-sg-"
  
  # Regra de Entrada (Ingress) - Porta 22 (SSH)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Regra de Entrada (Ingress) - Porta 5000 (Flask App)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Regra de Saída (Egress) - Todo o Tráfego de Saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------------------------
# 3. CHAVE SSH
# -----------------------------------------------------------
resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  # O Terraform lê o arquivo minha-chave.pub na mesma pasta
  public_key = file("${path.module}/minha-chave.pub") 
}

# -----------------------------------------------------------
# 4. RECURSO DO SERVIDOR (EC2)
# -----------------------------------------------------------
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.deployer_key.key_name
  
  # ✅ CORREÇÃO: Usa user_data_base64 para o script de Cloud-Init
  user_data_base64 = filebase64("${path.module}/user_data.sh") 
  
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  tags = {
    Name = "Trabalho-CICD-App-Server"
  }
}