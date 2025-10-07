#!/bin/bash

echo "🔨 Compilando assets usando Docker..."

# Subir o serviço de build se não estiver rodando
echo "📦 Preparando container de build..."
docker compose -f docker-compose.production.modificado.yaml --profile build up -d vite-build

# Instalar pnpm e dependências se necessário
echo "📥 Preparando ambiente Node.js..."
docker compose -f docker-compose.production.modificado.yaml exec vite-build sh -c "
# Instalar pnpm se não existir
if ! command -v pnpm &> /dev/null; then
    echo '📦 Instalando pnpm...'
    npm install -g pnpm
fi

# Instalar dependências se necessário
if [ ! -d node_modules ] || [ ! -f node_modules/.pnpm-lock.yaml ]; then
    echo '📦 Instalando dependências...'
    pnpm install
else
    echo '✅ Dependências já instaladas'
fi"

# Compilar assets
echo "🔨 Compilando assets..."
docker compose -f docker-compose.production.modificado.yaml exec vite-build npx vite build

if [ $? -eq 0 ]; then
    echo "✅ Assets compilados com sucesso!"
    echo "🔄 Reiniciando container Rails..."
    docker compose -f docker-compose.production.modificado.yaml restart rails
    echo "✅ Container reiniciado!"
    echo "🌐 Aplicação disponível em: http://localhost:3000"
else
    echo "❌ Erro na compilação dos assets!"
    exit 1
fi

echo "🧹 Limpando container de build..."
docker compose -f docker-compose.production.modificado.yaml --profile build down vite-build 