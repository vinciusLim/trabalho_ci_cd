# ENTREGA 2: Automação de CI/CD com GitHub Actions

## Arquivos da Entrega

| Arquivo | Descrição |
|---------|-----------|
| `.github/workflows/cicd.yml` | Pipeline CI/CD do GitHub Actions |
| `docker-compose.prod.yml` | Compose adaptado para produção |
| `tests/test_app.py` | Testes unitários (expandido) |

---

## 1. Testes Unitários (CI)

**Arquivo:** `tests/test_app.py`

Testes unitários para todas as rotas do CRUD usando pytest e mocks:

```python
import json
import pytest
from unittest.mock import patch, MagicMock

from app.app import app, get_connection

@pytest.fixture
def client():
    app.testing = True
    return app.test_client()

# GET /users
def test_get_users(client):
    fake_users = [
        {"id": 1, "name": "Ana", "email": "ana@example.com"},
        {"id": 2, "name": "Joao", "email": "joao@example.com"},
    ]

    mock_cursor = MagicMock()
    mock_cursor.fetchall.return_value = fake_users

    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.get("/users")

    assert response.status_code == 200
    assert response.get_json() == fake_users

# POST /users
def test_add_user(client):
    payload = {"name": "Ana", "email": "ana@example.com"}

    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.post("/users", json=payload)

    assert response.status_code == 200
    assert response.get_json()["message"] == "User added successfully"

# PUT /users/<id>
def test_update_user(client):
    payload = {"name": "Novo Nome", "email": "novo@example.com"}

    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.put("/users/1", json=payload)

    assert response.status_code == 200
    assert response.get_json()["message"] == "User updated successfully"

# DELETE /users/<id>
def test_delete_user(client):
    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.delete("/users/1")

    assert response.status_code == 200
    assert response.get_json()["message"] == "User deleted successfully"
```

**Características:**
- Testes para todos os endpoints CRUD (GET, POST, PUT, DELETE)
- Uso de mocks para não depender do banco real
- Framework: pytest
- Executável via `pytest tests/test_app.py -v`

---

## 2. Configuração de Secrets no GitHub

Os secrets são credenciais armazenadas de forma segura no GitHub, não expostas no código.

**Secrets necessários:**

| Secret | Descrição | Exemplo |
|--------|-----------|---------|
| `DOCKERHUB_USERNAME` | Usuário do Docker Hub | seu-usuario |
| `DOCKERHUB_TOKEN` | Token de acesso Docker Hub | dckr_pat_xxxxx |
| `SSH_HOST` | IP ou hostname do servidor | 192.168.1.100 |
| `SSH_USERNAME` | Usuário SSH do servidor | ubuntu |
| `SSH_KEY` | Chave privada SSH (PEM) | -----BEGIN PRIVATE KEY----- |

**Como adicionar:**
1. Vá em `Settings` → `Secrets and variables` → `Actions`
2. Clique em `New repository secret`
3. Adicione cada secret acima

---

## 3. Adaptação do Docker Compose para Produção

**Arquivo:** `docker-compose.prod.yml`

Compose adaptado para usar imagem publicada no Docker Hub:

```yaml
services:
  app:
    image: ${DOCKERHUB_USERNAME}/trabalho_ci_cd:${IMAGE_TAG}
    container_name: flask_app
    ports:
      - "5000:5000"
    environment:
      - DB_HOST=db
      - DB_USER=${MYSQL_USER}
      - DB_PASSWORD=${MYSQL_PASSWORD}
      - DB_NAME=${MYSQL_DATABASE}
    depends_on:
      - db
    networks:
      - app_network

  db:
    image: mysql:8.0
    container_name: mysql_db
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - app_network

volumes:
  db_data:

networks:
  app_network:
    driver: bridge
```

**Diferenças com `docker-compose.yml` (desenvolvimento):**
- **Desenvolvimento:** `build: ./app` - Compila imagem localmente
- **Produção:** `image: ${DOCKERHUB_USERNAME}/trabalho_ci_cd:${IMAGE_TAG}` - Puxa imagem do Docker Hub

---

## 4. Configuração Inicial do Servidor

### Pré-requisitos no Servidor

- Docker instalado
- Docker Compose instalado
- Acesso SSH via chave (não senha)
- Usuário com permissão Docker (adicionado ao grupo `docker`)

### Passos Manuais (Uma única vez)

#### Passo 1: Conectar ao Servidor via SSH

```bash
ssh -i caminho/da/chave.pem ubuntu@seu-ip-do-servidor
```

#### Passo 2: Clonar o Repositório

```bash
git clone https://github.com/seu-usuario/Trabalho_ci_cd.git
cd Trabalho_ci_cd
```

#### Passo 3: Criar Arquivo `.env` de Produção

```bash
cat > .env << EOF
MYSQL_ROOT_PASSWORD=senha_root_segura_prod
MYSQL_DATABASE=crud_db
MYSQL_USER=app_user
MYSQL_PASSWORD=senha_app_segura_prod
EOF
```

**Importante:** Este arquivo **não deve ir ao repositório** (adicionar ao `.gitignore`)

#### Passo 4: Verificar Permissões Docker

```bash
# Adicionar usuário ao grupo docker (se necessário)
sudo usermod -aG docker $USER

# Aplicar mudanças
newgrp docker

# Testar
docker ps
```

### Após Configuração Inicial

O GitHub Actions se encarregará do resto! A cada push na `main`:
1. Testa o código
2. Compila a imagem Docker
3. Envia para Docker Hub
4. Faz SSH no servidor e atualiza a aplicação

---

## 5. Workflow do GitHub Actions

**Arquivo:** `.github/workflows/cicd.yml`

Pipeline completo de CI/CD com 3 jobs:

```yaml
name: CI/CD - Flask + Docker + EC2

on:
  push:
    branches: ["main"]

env:
  DOCKER_IMAGE: ${{ secrets.DOCKERHUB_USERNAME }}/trabalho_ci_cd

jobs:
  # JOB 1: Testes (CI)
  ci:
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout do Código
        uses: actions/checkout@v4

      - name: 🐍 Configurar Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.x'

      - name: Instalar Dependências
        working-directory: app
        run: pip install -r requirements.txt

      - name: 🛠️ Adicionar Projeto ao PYTHONPATH
        run: echo "PYTHONPATH=$(pwd)" >> $GITHUB_ENV

      - name: 🧪 Rodar Testes Unitários
        run: pytest

  # JOB 2: Build e Push da Imagem
  build-and-push:
    needs: ci
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout do Código
        uses: actions/checkout@v4

      - name: 🏷️ Definir Tag da Imagem
        id: vars
        run: echo "TAG=$(echo ${{ github.sha }} | cut -c1-7)" >> $GITHUB_OUTPUT

      - name: 🔐 Login no DockerHub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: ⚙️ Build e Push da Imagem
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./app/Dockerfile
          push: true
          tags: |
            ${{ env.DOCKER_IMAGE }}:latest
            ${{ env.DOCKER_IMAGE }}:${{ steps.vars.outputs.TAG }}

    outputs:
      image_tag: ${{ steps.vars.outputs.TAG }}

  # JOB 3: Deploy via SSH
  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - name: 📥 Checkout do Código
        uses: actions/checkout@v4

      - name: 🚀 Deploy via SSH
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USERNAME }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd ~/Trabalho_ci_cd
            git pull origin main
            export IMAGE_TAG=${{ needs.build-and-push.outputs.image_tag }}
            docker-compose -f docker-compose.prod.yml --env-file .env up -d --force-recreate
```

**Explicação dos Jobs:**

1. **ci**: Testa o código com pytest
2. **build-and-push**: Compila e publica imagem no Docker Hub (só executa se testes passarem)
3. **deploy**: Conecta ao servidor via SSH e atualiza os containers

---

## 6. Documentação no README.md

## CI/CD Status

[![CI/CD - Flask + Docker + EC2](https://github.com/vinciusLim/trabalho_ci_cd/actions/workflows/cicd.yml/badge.svg)](https://github.com/vinciusLim/trabalho_ci_cd/actions/workflows/cicd.yml)

### Seção Completa do README.md

```markdown
## CI/CD Pipeline

O projeto utiliza **GitHub Actions** para automatizar testes, build e deploy.

### 🔐 Secrets Necessários

Configure os seguintes secrets em `Settings > Secrets and variables > Actions`:

| Secret | Descrição |
|--------|-----------|
| `DOCKERHUB_USERNAME` | Usuário do Docker Hub |
| `DOCKERHUB_TOKEN` | Token/Senha do Docker Hub |
| `SSH_HOST` | IP ou hostname do servidor |
| `SSH_USERNAME` | Usuário SSH (ex: ubuntu) |
| `SSH_KEY` | Chave privada SSH (PEM) |

### 📝 Configuração Manual no Servidor

Execute uma única vez no servidor:

```bash
# 1. Clonar repositório
ssh -i chave.pem ubuntu@seu-ip
git clone https://github.com/seu-usuario/Trabalho_ci_cd.git
cd Trabalho_ci_cd

# 2. Criar arquivo .env (NÃO será versionado)
cat > .env << EOF
MYSQL_ROOT_PASSWORD=seu_senha
MYSQL_DATABASE=crud_db
MYSQL_USER=app_user
MYSQL_PASSWORD=sua_senha
EOF

# 3. Garantir permissões Docker
sudo usermod -aG docker ubuntu
newgrp docker
```

### ✅ Fluxo de Funcionamento

1. **Push para main** → GitHub Actions é disparado
2. **Testes rodam** → Verificam sintaxe e lógica
3. **Se testes passarem** → Compila imagem Docker
4. **Push para Docker Hub** → Imagem fica disponível
5. **SSH no servidor** → Puxa e atualiza containers
6. **Aplicação atualizada** → Nova versão está ao vivo

```

---

## Resumo dos Resultados Esperados

✓ **Pipeline de CI/CD funcional no GitHub Actions**
- Arquivo `.github/workflows/cicd.yml` implementado
- 3 jobs: CI (testes), Build (Docker), Deploy (SSH)

✓ **Testes unitários executados automaticamente**
- Todos os endpoints CRUD testados
- Usa mocks para não depender do banco real
- Pipeline falha se testes não passarem

✓ **Nova imagem Docker construída e enviada ao Docker Hub**
- Tag `latest` sempre aponta para versão mais recente
- Tag com SHA do commit (7 caracteres) para rastreabilidade
- Só faz build se testes passarem

✓ **Deploy automático no servidor via SSH**
- GitHub Actions conecta ao servidor
- Faz git pull
- Executa docker-compose com nova imagem
- Aplicação atualizada sem downtime significativo

✓ **GitHub Secrets para proteger credenciais**
- Nenhuma senha exposta no código
- Secrets usados apenas em tempo de execução
- SSH key segura no GitHub

✓ **README.md atualizado com documentação**
- Badge de status do GitHub Actions
- Explicação do pipeline
- Lista de secrets necessários
- Passos manuais no servidor

---

## Entrega

**GitHub Repository:** https://github.com/vinciusLim/Trabalho_ci_cd
