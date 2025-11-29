# Etapa 1: build
FROM python:3.11-alpine AS builder

WORKDIR /app
# 🛑 CORRIGIDO: Agora copia de 'app/requirements.txt' (relativo ao Contexto)
COPY app/requirements.txt . 
RUN pip install --prefix=/install -r requirements.txt

# Etapa 2: runtime
FROM python:3.11-alpine
WORKDIR /app
COPY --from=builder /install /usr/local
# 🛑 CORRIGIDO: Agora copia todos os arquivos da pasta 'app/'
COPY app/. . 
CMD ["python", "app.py"]