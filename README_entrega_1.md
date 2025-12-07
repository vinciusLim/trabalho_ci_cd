# ENTREGA 1: Multi-Container Docker com API CRUD

## Arquivos da Entrega

| Arquivo | Descrição |
|---------|-----------|
| `app/Dockerfile` | Dockerfile multi-stage com Alpine |
| `docker-compose.yml` | Orquestração de dois serviços |
| `app/app.py` | API Flask com CRUD |
| `tests/test_app.py` | Testes unitários |
| `init.sql` | Script de inicialização do banco |
| `app/requirements.txt` | Dependências da aplicação |

---

## 1. Criação do Dockerfile

**Arquivo:** `app/Dockerfile`

Dockerfile com múltiplos estágios utilizando imagem Alpine para otimizar o tamanho da imagem final:

```dockerfile
# Etapa 1: build
FROM python:3.11-alpine AS builder

WORKDIR /app
COPY app/requirements.txt . 
RUN pip install --prefix=/install -r requirements.txt

# Etapa 2: runtime
FROM python:3.11-alpine
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app/. . 
CMD ["python", "app.py"]
```

**Características:**
- Imagem base Alpine para reduzir tamanho
- Múltiplos estágios: builder (compila dependências) e runtime (executa app)
- Apenas arquivos necessários são copiados para imagem final
- Reduz vulnerabilidades ao remover ferramentas de build do container final

---

## 2. Definição do Docker Compose

**Arquivo:** `docker-compose.yml`

Configuração de dois serviços: aplicação Flask e banco de dados MySQL

```yaml
version: "3.9"

services:
  app:
    build: ./app
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

**Serviços:**
- **app**: Aplicação Flask exposta na porta 5000
- **db**: MySQL 8.0 para armazenamento de dados

---

## 3. Configuração de Volumes

**Volume nomeado:** `db_data`

```yaml
volumes:
  db_data:
```

**Características:**
- Garante persistência dos dados do MySQL
- Dados persistem entre paradas e reinicializações dos containers
- Script `init.sql` é executado automaticamente na primeira inicialização
- Volume reutilizado em futuras execuções

**Script de inicialização (`init.sql`):**

```sql
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100)
);
```

---

## 4. Criação de Rede Customizada

**Rede isolada:** `app_network`

```yaml
networks:
  app_network:
    driver: bridge
```

**Características:**
- Rede bridge customizada para isolamento
- Containers se comunicam através de DNS interno
- Serviço `app` acessa banco de dados via hostname `db`
- Nenhuma porta do MySQL é exposta para o host
- Aumenta segurança ao isolar tráfego de rede

---

## 5. Utilização de Variáveis de Ambiente

Variáveis de ambiente para configuração segura e flexível da aplicação e banco de dados:

**Arquivo `.env` (criar na raiz do projeto):**

```env
MYSQL_ROOT_PASSWORD=root_password_123
MYSQL_DATABASE=crud_db
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password_456
```

**No `docker-compose.yml`** - Referência as variáveis:

```yaml
environment:
  - DB_HOST=db
  - DB_USER=${MYSQL_USER}
  - DB_PASSWORD=${MYSQL_PASSWORD}
  - DB_NAME=${MYSQL_DATABASE}
  MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
  MYSQL_DATABASE: ${MYSQL_DATABASE}
  MYSQL_USER: ${MYSQL_USER}
  MYSQL_PASSWORD: ${MYSQL_PASSWORD}
```

**Na aplicação (`app/app.py`)** - Leitura das variáveis:

```python
import os

db_config = {
    'host': os.getenv("DB_HOST", "db"),
    'user': os.getenv("DB_USER", "app_user"),
    'password': os.getenv("DB_PASSWORD", "1234"),
    'database': os.getenv("DB_NAME", "crud_db")
}
```

**Segurança:**
- Valores sensíveis não estão hardcoded no código
- Arquivo `.env` é ignorado pelo git (adicionar ao `.gitignore`)
- Diferentes ambientes usam diferentes valores de variáveis
- Facilita deploy em múltiplos ambientes

---

## 6. Documentação do Processo de Configuração

### Pré-requisitos

- Docker instalado
- Docker Compose instalado

### Passos para Executar

#### Passo 1: Configurar Variáveis de Ambiente

Criar arquivo `.env` na raiz do projeto:

```bash
MYSQL_ROOT_PASSWORD=root_password_123
MYSQL_DATABASE=crud_db
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password_456
```

#### Passo 2: Iniciar os Containers

```bash
docker-compose up --build
```

Isso irá:
- Construir a imagem Docker da aplicação
- Iniciar o container MySQL
- Iniciar o container Flask
- Criar a tabela de usuários através do `init.sql`

#### Passo 3: Testar a API CRUD

A aplicação está disponível em `http://localhost:5000`

**Listar usuários:**

```bash
curl http://localhost:5000/users
```

**Criar usuário:**

```bash
curl -X POST http://localhost:5000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "João Silva", "email": "joao@example.com"}'
```

**Atualizar usuário (ID 1):**

```bash
curl -X PUT http://localhost:5000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "João Silva Junior", "email": "joao.junior@example.com"}'
```

**Deletar usuário (ID 1):**

```bash
curl -X DELETE http://localhost:5000/users/1
```

#### Passo 4: Testar Conexão entre Containers

Os containers se comunicam automaticamente através da rede customizada. Para verificar:

```bash
# Ver logs do serviço de aplicação
docker-compose logs app

# Ver logs do serviço MySQL
docker-compose logs db
```

#### Passo 5: Parar os Containers

```bash
# Parar containers
docker-compose down

# Parar containers e remover volume de dados
docker-compose down -v
```

---

## 7. Estratégia de Segurança - Usuário Não-Root

**Configuração no Docker Compose:**

```yaml
db:
  environment:
    MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    MYSQL_USER: ${MYSQL_USER}
    MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    MYSQL_DATABASE: ${MYSQL_DATABASE}
```

**Benefícios:**
- Banco de dados criado com usuário `app_user` em vez de usar apenas `root`
- `app_user` tem acesso apenas ao banco `crud_db`
- Reduz risco de comprometimento em caso de vazamento de credenciais
- Segue o princípio de menor privilégio

---

## 8. API com CRUD

**Arquivo:** `app/app.py`

```python
from flask import Flask, request, jsonify
import mysql.connector
import os

app = Flask(__name__)

db_config = {
    'host': os.getenv("DB_HOST", "db"),
    'user': os.getenv("DB_USER", "app_user"),
    'password': os.getenv("DB_PASSWORD", "1234"),
    'database': os.getenv("DB_NAME", "crud_db")
}

def get_connection():
    return mysql.connector.connect(**db_config)

@app.route('/users', methods=['GET'])
def get_users():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM users")
    users = cursor.fetchall()
    conn.close()
    return jsonify(users)

@app.route('/users', methods=['POST'])
def add_user():
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("INSERT INTO users (name, email) VALUES (%s, %s)", 
                   (data['name'], data['email']))
    conn.commit()
    conn.close()
    return jsonify({'message': 'User added successfully'})

@app.route('/users/<int:id>', methods=['PUT'])
def update_user(id):
    data = request.json
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET name=%s, email=%s WHERE id=%s", 
                   (data['name'], data['email'], id))
    conn.commit()
    conn.close()
    return jsonify({'message': 'User updated successfully'})

@app.route('/users/<int:id>', methods=['DELETE'])
def delete_user(id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM users WHERE id=%s", (id,))
    conn.commit()
    conn.close()
    return jsonify({'message': 'User deleted successfully'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

**Endpoints CRUD:**

| Método | Rota | Ação |
|--------|------|------|
| `GET` | `/users` | Lista todos os usuários |
| `POST` | `/users` | Cria novo usuário |
| `PUT` | `/users/<id>` | Atualiza usuário |
| `DELETE` | `/users/<id>` | Deleta usuário |

**Dados persistem no banco MySQL e são recuperados a cada execução.**

---

## 9. Testes Unitários

**Arquivo:** `tests/test_app.py`

Testes com pytest usando mocks para não depender do banco de dados real:

```python
import json
import pytest
from unittest.mock import patch, MagicMock

from app.app import app, get_connection

@pytest.fixture
def client():
    app.testing = True
    return app.test_client()

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

def test_add_user(client):
    payload = {"name": "Ana", "email": "ana@example.com"}

    mock_cursor = MagicMock()
    mock_conn = MagicMock()
    mock_conn.cursor.return_value = mock_cursor

    with patch("app.app.get_connection", return_value=mock_conn):
        response = client.post("/users", json=payload)

    assert response.status_code == 200
    assert response.get_json()["message"] == "User added successfully"
```

**Executar testes:**

```bash
pytest tests/test_app.py -v
```

---

## Resumo dos Resultados Esperados

✓ **Configuração de um ambiente multi-container funcional com Docker Compose**
- Dois serviços (Flask e MySQL) orquestrados pelo docker-compose.yml

✓ **API com CRUD persistindo dados em um DB**
- Endpoints GET, POST, PUT, DELETE persistem dados no MySQL

✓ **Utilização efetiva de volumes para persistência de dados**
- Volume `db_data` garante que dados persistam entre execuções

✓ **Configuração de variáveis de ambiente para gerenciar configurações sensíveis**
- Arquivo `.env` centraliza credenciais e URLs
- Sem hardcoding no código ou docker-compose

✓ **Implementação de uma estratégia de segurança para o acesso ao banco de dados**
- Usuário `app_user` (não-root) criado automaticamente
- Acesso restrito apenas ao banco `crud_db`

✓ **Documentação clara e detalhada do processo de configuração e teste**
- Este arquivo detalha passo-a-passo a execução
- Inclui exemplos de testes da API

---

## Entrega

**GitHub Repository:** https://github.com/vinciusLim/Trabalho_ci_cd

