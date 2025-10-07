#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="chatwoot_backup_${TIMESTAMP}"
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

# Criar diretório de backup se não existir
mkdir -p "$BACKUP_DIR"

# Fazer backup de volumes e arquivos importantes
create_backup() {
    log "Criando backup completo..."

    # Parar containers para garantir consistência do backup de volumes
    log "Parando containers para backup de volumes..."
    $DOCKER_COMPOSE_CMD -f "$DOCKER_COMPOSE_FILE" stop || warning "Não foi possível parar todos os containers, continuando com o backup."

    # Criar um diretório temporário para o backup
    TEMP_BACKUP_DIR=$(mktemp -d -t chatwoot-backup-XXXXXXXXXX)
    log "Diretório temporário de backup: $TEMP_BACKUP_DIR"

    # Backup de volumes Docker
    log "Fazendo backup dos volumes Docker..."
    VOLUMES=$(docker volume ls --format "{{.Name}}" | grep -E "^chatwoot_" || true)

    for volume in $VOLUMES; do
        log "Backup do volume: $volume"
        docker run --rm -v "$volume":/volume -v "$TEMP_BACKUP_DIR":/backup alpine tar czf "/backup/${volume}.tar.gz" -C /volume . || warning "Falha ao fazer backup do volume $volume"
    done

    # Backup de arquivos importantes
    log "Fazendo backup de arquivos importantes..."
    cp "$DOCKER_COMPOSE_FILE" "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar $DOCKER_COMPOSE_FILE"
    cp .env "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar .env"
    cp -r config "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar config/"
    [ -d "enterprise" ] && cp -r enterprise "$TEMP_BACKUP_DIR/" || warning "Diretório enterprise/ não encontrado, pulando..."
    [ -d "app" ] && cp -r app "$TEMP_BACKUP_DIR/" || warning "Diretório app/ não encontrado, pulando..."
    [ -d "public" ] && cp -r public "$TEMP_BACKUP_DIR/" || warning "Diretório public/ não encontrado, pulando..."
    [ -d "storage" ] && cp -r storage "$TEMP_BACKUP_DIR/" || warning "Diretório storage/ não encontrado, pulando..."
    [ -d "docker" ] && cp -r docker "$TEMP_BACKUP_DIR/" || warning "Diretório docker/ não encontrado, pulando..."
    [ -d "db" ] && cp -r db "$TEMP_BACKUP_DIR/" || warning "Diretório db/ não encontrado, pulando..."
    cp Gemfile* "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar Gemfile*"
    cp package.json "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar package.json"
    cp pnpm-lock.yaml "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar pnpm-lock.yaml"
    cp vite.config.ts "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar vite.config.ts"
    cp .gitignore "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar .gitignore"
    cp compile-docker.sh "$TEMP_BACKUP_DIR/" || warning "Falha ao copiar compile-docker.sh"

    # Comprimir o diretório temporário
    log "Comprimindo backup para $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    tar czf "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" -C "$TEMP_BACKUP_DIR" . || error "Falha ao comprimir o backup"

    # Limpar diretório temporário
    rm -rf "$TEMP_BACKUP_DIR"

    success "Backup completo criado: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
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
        git stash push -m "Pre-upgrade stash: ${TIMESTAMP}" || error "Falha ao fazer stash das mudanças locais"
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

# Compilar assets frontend
compile_frontend() {
    log "Compilando assets frontend..."
    if [ -f "./compile-docker.sh" ]; then
        ./compile-docker.sh || error "Falha na compilação dos assets frontend"
    else
        error "Script compile-docker.sh não encontrado"
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
    log "Iniciando processo de upgrade de produção..."

    create_backup
    stop_containers
    update_code
    compile_frontend
    start_containers
    verify_application

    echo -e "\n=========================================="
    echo -e "${GREEN}    UPGRADE CONCLUÍDO COM SUCESSO!${NC}"
    echo -e "${GREEN}    Backup: $BACKUP_DIR/${BACKUP_NAME}.tar.gz${NC}"
    echo -e "${GREEN}    Data: $(date)${NC}"
    echo -e "=========================================="
}

main
