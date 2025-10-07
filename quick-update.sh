#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
DOCKER_COMPOSE_FILE="docker-compose.production.modificado.yaml"

# Detectar comando docker-compose
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo -e "${RED}Erro: Docker Compose não encontrado. Instale docker-compose ou docker compose.${NC}"
    exit 1
fi

# Função para logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}$1${NC}"
}

warning() {
    echo -e "${YELLOW}$1${NC}"
}

error() {
    echo -e "${RED}Erro: $1${NC}"
    exit 1
}

# Parar os containers
stop_containers() {
    log "Parando containers..."
    $DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" down || true
    success "Containers parados"
}

# Atualizar código via git
update_code() {
    log "Atualizando código via git..."
    # Salvar mudanças locais se houver
    git_status=$(git status --porcelain)
    if [ -n "$git_status" ]; then
        log "Mudanças locais detectadas. Stashing..."
        git stash push -m "Pre-quick-update stash: $(date +"%Y%m%d_%H%M%S")" || error "Falha ao fazer stash das mudanças locais"
        STASHED=true
    else
        STASHED=false
    fi

    git pull origin main || error "Falha ao fazer git pull"
    success "Código atualizado"

    # Aplicar stash se houver
    if [ "$STASHED" = true ]; then
        log "Aplicando stash de volta..."
        git stash pop || warning "Conflitos ao aplicar stash. Resolva manualmente."
    fi
}

# Iniciar containers
start_containers() {
    log "Iniciando containers..."
    $DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" up -d
    
    # Aguardar containers iniciarem
    log "Aguardando containers iniciarem..."
    sleep 10
    
    success "Containers iniciados"
}

# Verificar se a aplicação está funcionando
verify_application() {
    log "Verificando se a aplicação está funcionando..."
    
    # Aguardar um pouco mais para garantir que tudo carregou
    sleep 15
    
    # Verificar se os containers estão rodando
    if ! $DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" ps | grep -q "Up"; then
        error "Alguns containers não estão rodando"
    fi
    
    # Verificar se a aplicação responde (se estiver rodando na porta 3000)
    if command -v curl >/dev/null 2>&1; then
        log "Testando resposta da aplicação..."
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|302"; then
            success "Aplicação respondendo corretamente em http://localhost:3000"
        else
            warning "Aplicação pode não estar respondendo corretamente"
        fi
    fi
    
    # Mostrar status dos containers
    log "Status dos containers:"
    $DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" ps
    
    success "Verificação concluída"
}

# Função principal
main() {
    log "Iniciando processo de atualização rápida..."

    stop_containers
    update_code
    start_containers
    verify_application

    echo -e "\n=========================================="
    echo -e "${GREEN}    ATUALIZAÇÃO RÁPIDA CONCLUÍDA!${NC}"
    echo -e "${GREEN}    Data: $(date)${NC}"
    echo -e "=========================================="
}

main
