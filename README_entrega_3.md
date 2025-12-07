# ENTREGA 3: Infraestrutura como Código (IaC) com Terraform

## Arquivos da Entrega

| Arquivo | Descrição |
|---------|-----------|
| `terraform/main.tf` | Definição do provider AWS e recurso EC2 |
| `terraform/outputs.tf` | Exportação do IP público |
| `terraform/terraform.tfvars` | Variáveis sensíveis (local, não versionado) |
| `terraform/user_data.sh` | Script de Cloud-Init para instalar Docker |
| `.github/workflows/cicd.yml` | Pipeline atualizado com job de Terraform |

---

## 1. Desenvolvimento Local da Infraestrutura (IaC)

### Estrutura da Pasta Terraform

```
terraform/
├── main.tf                  # Provider, Security Group, EC2
├── outputs.tf               # IP público da instância
├── terraform.tfvars         # Variáveis sensíveis (local)
├── minha-chave.pub          # Chave SSH pública (local)
└── user_data.sh             # Script de inicialização
```

### 1.1 Definição do Provider e Recursos

**Arquivo:** `terraform/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  
  # Backend remoto para armazenar estado no S3
  backend "s3" {
    bucket         = "terraform-state-seu-nome"
    key            = "trabalho-cicd/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# Busca de AMI (Amazon Linux 2023)
data "aws_ami" "amazon_linux" {
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
  owners = ["amazon"]
}

# Security Group - Libera SSH (22) e Flask (5000)
resource "aws_security_group" "app_sg" {
  name_prefix = "app-sg-"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Chave SSH para acesso ao servidor
resource "aws_key_pair" "deployer_key" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/minha-chave.pub")
}

# Instância EC2 com Cloud-Init
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.deployer_key.key_name
  user_data_base64       = filebase64("${path.module}/user_data.sh")
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  
  tags = {
    Name = "Trabalho-CICD-App-Server"
  }
}
```

**Características:**
- Provider: AWS
- Recurso: EC2 (t2.micro - elegível free tier)
- Security Group: Portas 22 (SSH) e 5000 (Flask)
- Chave SSH: Injetada para acesso futuro
- Cloud-Init: Script que instala Docker automaticamente

### 1.2 Outputs

**Arquivo:** `terraform/outputs.tf`

```hcl
output "public_ip" {
  value       = aws_instance.app_server.public_ip
  description = "IP público da instância EC2"
}
```

Esse output será usado pelo GitHub Actions para descobrir qual IP do servidor foi criado.

### 1.3 Gerenciamento de Variáveis e Segredos

**Arquivo:** `terraform/terraform.tfvars` (LOCAL - NÃO VERSIONADO)

```hcl
# Adicione ao .gitignore
```

**No `.gitignore`:**

```
# Terraform
*.tfvars
*.tfvars.json
.terraform/
terraform.tfstate
terraform.tfstate.*
crash.log
.terraform.lock.hcl
```

**Importante:** Nunca commitar:
- `terraform.tfvars` (variáveis sensíveis)
- `.terraform/` (cache local)
- `terraform.tfstate*` (estado da infraestrutura)

### 1.4 Script de Cloud-Init

**Arquivo:** `terraform/user_data.sh`

```bash
#!/bin/bash
# Instalação automática de Docker, Docker Compose e Git

# Atualiza sistema
sudo yum update -y

# Instala Docker
sudo yum install -y docker

# Inicia Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Instala Docker Compose v2
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Link simbólico
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Instala Git
sudo yum install -y git
```

**Características:**
- Executa na primeira inicialização
- Instala Docker automaticamente
- Instala Docker Compose
- Instala Git
- **Não cria .env** (será criado pelo deploy SSH)

### 1.5 Teste Local

#### Setup Inicial

```bash
# 1. Instalar Terraform
# Windows: choco install terraform
# macOS: brew install terraform
# Linux: https://www.terraform.io/downloads

# 2. Configurar credenciais AWS
aws configure
# ou
export AWS_ACCESS_KEY_ID="xxxxx"
export AWS_SECRET_ACCESS_KEY="xxxxx"

# 3. Gerar chave SSH
ssh-keygen -t rsa -b 4096 -f minha-chave -N ""
# Isso cria minha-chave (privada) e minha-chave.pub (pública)
```

#### Executar Terraform Localmente

```bash
cd terraform

# Inicializa Terraform (configura backend S3)
terraform init

# Visualiza o plano de execução
terraform plan

# Aplica as mudanças (cria EC2)
terraform apply

# Captura o IP público
terraform output public_ip
```

#### Acessar o Servidor

```bash
# Conectar via SSH
ssh -i caminho/para/minha-chave ec2-user@seu-ip

# Verificar Docker
docker --version
docker-compose --version
```

---

## 2. Configuração do State Remoto (Cloud State)

### 2.1 Backend Remoto no S3

O estado do Terraform está configurado em `main.tf`:

```hcl
backend "s3" {
  bucket         = "terraform-state-seu-nome"
  key            = "trabalho-cicd/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
}
```

### 2.2 Preparar o Bucket S3

**Uma única vez, via AWS Console ou CLI:**

```bash
# Criar bucket S3
aws s3api create-bucket \
  --bucket terraform-state-seu-nome \
  --region us-east-1

# Ativar versionamento
aws s3api put-bucket-versioning \
  --bucket terraform-state-seu-nome \
  --versioning-configuration Status=Enabled

# Ativar criptografia padrão
aws s3api put-bucket-encryption \
  --bucket terraform-state-seu-nome \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Bloquear acesso público
aws s3api put-bucket-public-access-block \
  --bucket terraform-state-seu-nome \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 2.3 Migrar Estado Local para S3

```bash
cd terraform

# Se já tem terraform.tfstate local, ele será movido para S3
terraform init

# Confirme a migração
# O arquivo .tfstate permanece localmente, mas o estado remoto estará no S3
```

---

## 3. Integração com GitHub Actions

### 3.1 Novos Secrets Necessários

Configure os seguintes secrets em `Settings > Secrets and variables > Actions`:

| Secret | Descrição | Exemplo |
|--------|-----------|---------|
| `AWS_ACCESS_KEY_ID` | Access Key AWS | AKIAIOSFODNN7EXAMPLE |
| `AWS_SECRET_ACCESS_KEY` | Secret Key AWS | wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY |
| `TF_BUCKET_NAME` | Nome do bucket S3 | terraform-state-seu-nome |
| `DOCKERHUB_USERNAME` | Usuário Docker Hub | seu-usuario |
| `DOCKERHUB_TOKEN` | Token Docker Hub | dckr_pat_xxxxx |
| `SSH_KEY` | Chave SSH privada | -----BEGIN PRIVATE KEY----- |

### 3.2 Job de Infraestrutura no Pipeline

**Arquivo atualizado:** `.github/workflows/cicd.yml`

```yaml
name: CI/CD - Flask + Docker + Terraform + AWS

on:
  push:
    branches: ["main"]

env:
  DOCKER_IMAGE: ${{ secrets.DOCKERHUB_USERNAME }}/trabalho_ci_cd
  AWS_REGION: us-east-1

jobs:
  # JOB 1: CI (Testes)
  ci:
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: 🐍 Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - name: 📦 Instalar Dependências
        working-directory: app
        run: pip install -r requirements.txt

      - name: 🧪 Rodar Testes
        run: |
          echo "PYTHONPATH=$(pwd)" >> $GITHUB_ENV
          pytest

  # JOB 2: Build e Push
  build-and-push:
    needs: ci
    runs-on: ubuntu-latest
    outputs:
      image_tag: ${{ steps.vars.outputs.TAG }}
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: 🏷️ Definir Tag
        id: vars
        run: echo "TAG=$(echo ${{ github.sha }} | cut -c1-7)" >> $GITHUB_OUTPUT

      - name: 🔐 Login Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: ⚙️ Build e Push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./app/Dockerfile
          push: true
          tags: |
            ${{ env.DOCKER_IMAGE }}:latest
            ${{ env.DOCKER_IMAGE }}:${{ steps.vars.outputs.TAG }}

  # JOB 3: Provisionar Infraestrutura (NOVO)
  provision-infra:
    name: 🏗️ Provisionar Infraestrutura
    runs-on: ubuntu-latest
    needs: [build-and-push]
    outputs:
      server_ip: ${{ steps.tf_output.outputs.public_ip }}
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: 🛠️ Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: 🔑 Configurar Credenciais AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: 🔄 Terraform Init
        working-directory: terraform
        run: terraform init

      - name: 📋 Terraform Plan
        working-directory: terraform
        run: terraform plan -out=tfplan

      - name: 🚀 Terraform Apply
        working-directory: terraform
        run: terraform apply -auto-approve tfplan

      - name: 📍 Capturar IP Público
        id: tf_output
        working-directory: terraform
        run: echo "public_ip=$(terraform output -raw public_ip)" >> $GITHUB_OUTPUT

  # JOB 4: Deploy via SSH (atualizado)
  deploy:
    name: 🚀 Deploy Aplicação
    needs: [build-and-push, provision-infra]
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout
        uses: actions/checkout@v4

      - name: 🚀 Deploy SSH
        uses: appleboy/ssh-action@master
        with:
          host: ${{ needs.provision-infra.outputs.server_ip }}
          username: ec2-user
          key: ${{ secrets.SSH_KEY }}
          script: |
            # Clone ou atualiza repositório
            if [ -d "Trabalho_ci_cd" ]; then
              cd Trabalho_ci_cd
              git pull origin main
            else
              git clone https://github.com/${{ github.repository }}.git Trabalho_ci_cd
              cd Trabalho_ci_cd
            fi

            # Cria .env para produção
            cat > .env << 'EOF'
            MYSQL_ROOT_PASSWORD=${{ secrets.MYSQL_ROOT_PASSWORD }}
            MYSQL_DATABASE=crud_db
            MYSQL_USER=app_user
            MYSQL_PASSWORD=${{ secrets.MYSQL_PASSWORD }}
            EOF

            # Deploy com docker-compose
            export IMAGE_TAG=${{ needs.build-and-push.outputs.image_tag }}
            docker-compose -f docker-compose.prod.yml --env-file .env up -d --force-recreate
```

**Explicação dos Jobs:**

1. **ci**: Testa o código
2. **build-and-push**: Compila e publica imagem
3. **provision-infra** (NOVO): Provisiona infraestrutura com Terraform
   - Faz `terraform init`
   - Faz `terraform plan`
   - Faz `terraform apply -auto-approve`
   - Captura o IP público
4. **deploy**: Deploy via SSH usando IP do Terraform

---

## 4. Documentação Atualizada do README.md

### Seção de Pré-requisitos de Infraestrutura

```markdown
## Pré-requisitos de Infraestrutura (Entrega 3)

### Cloud Provider
- Conta AWS (ou outra cloud provider)
- Bucket S3 para armazenar estado do Terraform

### Terraform Local
```bash
# Instalar Terraform
# https://www.terraform.io/downloads

# Gerar chaves SSH
ssh-keygen -t rsa -b 4096 -f terraform/minha-chave -N ""
```

### Secrets do GitHub (CI/CD + Infraestrutura)

| Secret | Descrição |
|--------|-----------|
| `AWS_ACCESS_KEY_ID` | Access Key AWS |
| `AWS_SECRET_ACCESS_KEY` | Secret Key AWS |
| `TF_BUCKET_NAME` | Bucket S3 para state |
| `DOCKERHUB_USERNAME` | Usuário Docker Hub |
| `DOCKERHUB_TOKEN` | Token Docker Hub |
| `SSH_KEY` | Chave SSH privada (terraform/minha-chave) |
| `MYSQL_ROOT_PASSWORD` | Senha root MySQL |
| `MYSQL_PASSWORD` | Senha app_user MySQL |
```

### Seção de Boot da Infraestrutura

```markdown
## Infraestrutura como Código (Terraform)

### Como Funciona

1. **Desenvolvimento Local**
   - Código Terraform define infraestrutura (EC2, Security Group, etc.)
   - Cloud-Init (`user_data.sh`) instala Docker automaticamente
   - Estado armazenado no S3 (não localmente)

2. **GitHub Actions Automation**
   - Job `provision-infra` roda `terraform apply`
   - Cria servidor EC2 automaticamente
   - Captura IP público dinâmico
   - Job `deploy` usa esse IP para fazer deploy

3. **Resultado**
   - ✅ Infraestrutura criada automaticamente
   - ✅ Docker/Docker Compose já instalados
   - ✅ Acesso SSH via chave
   - ✅ Pronto para receber aplicação

### Teste Local

```bash
cd terraform

# Setup
terraform init
terraform plan
terraform apply

# Capturar IP
terraform output public_ip

# SSH
ssh -i minha-chave ec2-user@<IP>
```


## CI/CD 

[![CI/CD - Flask + Docker + EC2](https://github.com/vinciusLim/trabalho_ci_cd/actions/workflows/cicd.yml/badge.svg)](https://github.com/vinciusLim/trabalho_ci_cd/actions/workflows/cicd.yml)

**Pipeline completo:**
- ✅ CI: Testes unitários
- ✅ Build: Docker Hub
- ✅ Infrastructure: Terraform + AWS
- ✅ Deploy: SSH dinâmico


---

## 5. Fluxo Completo de Execução


## Resumo dos Resultados Esperados

✓ **Infraestrutura como Código funcional**
- Arquivo `main.tf` define EC2, Security Group, Chave SSH
- Arquivo `outputs.tf` exporta IP público
- Backend S3 para gerenciar estado remotamente

✓ **Cloud-Init automatiza setup**
- Docker instalado automaticamente na primeira execução
- Docker Compose instalado
- Servidor pronto para receber aplicação

✓ **GitHub Actions com Terraform**
- Job `provision-infra` provisiona infraestrutura
- Captura IP dinâmico
- Deploy usa IP fornecido pelo Terraform

✓ **Pipeline Completo**
- Testes → Build Docker → Provisiona Infra → Deploy Automático

✓ **Segurança**
- Variáveis sensíveis em GitHub Secrets
- Estado Terraform armazenado em S3 criptografado
- Chave SSH gerenciada de forma segura

✓ **Documentação**
- README atualizado com badges
- Instruções de setup local
- Explicação do fluxo de execução

---

## Entrega

**GitHub Repository:** https://github.com/vinciusLim/Trabalho_ci_cd

**Checklist de Entrega:**
- ✅ Pasta `terraform/` com `main.tf`, `outputs.tf`, `user_data.sh`
- ✅ Arquivo `.env` não versionado (em `.gitignore`)
- ✅ Arquivo `minha-chave.pub` em `terraform/`
- ✅ Workflow atualizado com job `provision-infra`
- ✅ Secrets do GitHub configurados
- ✅ README.md atualizado com documentação
- ✅ GitHub Actions passando (verde) com todos os jobs
