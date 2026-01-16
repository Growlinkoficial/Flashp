#!/bin/bash

################################################################################
# Flashp Uninstaller - Script de Remoção Completa
# Versão: 1.0.0
# Descrição: Remove todos os componentes do Flashp e restaura o estado do sistema
################################################################################

set -euo pipefail

# Cores
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

readonly CONFIG_FILE="/etc/flashp/install.conf"
readonly LOG_DIR="/var/log/flashp"
readonly UNINSTALL_LOG="${LOG_DIR}/uninstall_$(date +%Y%m%d_%H%M%S).log"
readonly APP_USER="flashp"
readonly APP_DIR="/opt/flashp"

# ============================================================================
# LOGGING
# ============================================================================

mkdir -p "$LOG_DIR"
exec > >(tee -a "$UNINSTALL_LOG") 2>&1

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

# ============================================================================
# VALIDAÇÃO
# ============================================================================

validate_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

check_installation() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_warning "Nenhuma configuração de instalação do Flashp encontrada"
        log_warning "Tentarei detectar e remover componentes de qualquer forma"
        return 1
    fi
    return 0
}

# ============================================================================
# FUNÇÕES DE DESINSTALAÇÃO
# ============================================================================

show_banner() {
    clear
    cat <<EOF
${RED}
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ⚠️  DESINSTALADOR FLASHP v1.0  ⚠️            ║
║                                                           ║
║              Ferramenta de Limpeza Completa               ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
${NC}

EOF
}

confirm_uninstall() {
    echo -e "${YELLOW}AVISO: Isso removerá completamente o Flashp e todos os componentes relacionados!${NC}"
    echo
    
    if check_installation; then
        echo "Detalhes da instalação:"
        cat "$CONFIG_FILE" | grep -v "^#" | sed 's/^/  /'
        echo
    fi
    
    echo -e "${RED}Esta ação NÃO PODE ser desfeita!${NC}"
    echo
    read -p "Digite 'DELETAR' para confirmar a desinstalação: " confirmation
    
    if [ "$confirmation" != "DELETAR" ]; then
        log_info "Desinstalação cancelada pelo usuário"
        exit 0
    fi
    
    echo
    read -p "Criar backup antes de desinstalar? (s/n): " backup_choice
    if [[ $backup_choice =~ ^[SsYy]$ ]]; then
        create_backup
    fi
}

create_backup() {
    local backup_dir="/var/backups/flashp_$(date +%Y%m%d_%H%M%S)"
    log_info "Criando backup em $backup_dir..."
    
    mkdir -p "$backup_dir"
    
    # Backup da configuração
    [ -f "$CONFIG_FILE" ] && cp "$CONFIG_FILE" "$backup_dir/" 2>/dev/null || true
    
    # Backup dos logs
    [ -d "$LOG_DIR" ] && cp -r "$LOG_DIR" "$backup_dir/" 2>/dev/null || true
    
    # Backup dos arquivos da aplicação
    [ -d "$APP_DIR" ] && tar -czf "$backup_dir/flashp_app.tar.gz" "$APP_DIR" 2>/dev/null || true
    
    # Backup das configurações do Nginx
    [ -f "/etc/nginx/sites-available/flashp" ] && cp /etc/nginx/sites-available/flashp "$backup_dir/" 2>/dev/null || true
    [ -f "/etc/nginx/sites-available/portainer" ] && cp /etc/nginx/sites-available/portainer "$backup_dir/" 2>/dev/null || true
    
    # Backup da configuração do PM2
    if [ -d "$APP_DIR/.pm2" ]; then
        tar -czf "$backup_dir/pm2_config.tar.gz" "$APP_DIR/.pm2" 2>/dev/null || true
    fi
    
    log_success "Backup criado em $backup_dir"
    echo "Localização do backup: $backup_dir" >> "$UNINSTALL_LOG"
}

get_installation_method() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "$METHOD"
    else
        echo "desconhecido"
    fi
}

remove_bare_metal() {
    log_info "Removendo instalação Bare Metal..."
    
    # Parar processos PM2
    if command -v pm2 &> /dev/null; then
        log_info "Parando processos PM2..."
        sudo -u "$APP_USER" pm2 delete flashp 2>/dev/null || true
        sudo -u "$APP_USER" pm2 kill 2>/dev/null || true
    fi
    
    # Remover script de inicialização do PM2
    if [ -f "/etc/systemd/system/pm2-$APP_USER.service" ]; then
        log_info "Removendo serviço systemd do PM2..."
        systemctl stop "pm2-$APP_USER" 2>/dev/null || true
        systemctl disable "pm2-$APP_USER" 2>/dev/null || true
        rm -f "/etc/systemd/system/pm2-$APP_USER.service"
        systemctl daemon-reload
    fi
    
    # Remover configuração do Nginx
    log_info "Removendo configuração do Nginx..."
    rm -f /etc/nginx/sites-enabled/flashp 2>/dev/null || true
    rm -f /etc/nginx/sites-available/flashp 2>/dev/null || true
    
    # Testar e recarregar Nginx se ainda estiver instalado
    if command -v nginx &> /dev/null; then
        nginx -t && systemctl reload nginx || log_warning "Teste de configuração do Nginx falhou"
    fi
    
    # Remover certificados SSL
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        if [ -n "$DOMAIN" ] && [ "$HAS_DOMAIN" -eq 1 ]; then
            log_info "Removendo certificados SSL para $DOMAIN..."
            certbot delete --cert-name "$DOMAIN" --non-interactive 2>/dev/null || true
        fi
    fi
    
    log_success "Componentes Bare Metal removidos"
}

remove_portainer() {
    log_info "Removendo instalação do Portainer..."
    
    # Parar e remover container do Portainer
    if docker ps -a --format '{{.Names}}' | grep -q "portainer"; then
        log_info "Parando container do Portainer..."
        docker stop portainer 2>/dev/null || true
        docker rm portainer 2>/dev/null || true
    fi
    
    # Remover volume do Portainer
    if docker volume ls | grep -q "portainer_data"; then
        log_info "Removendo volume do Portainer..."
        docker volume rm portainer_data 2>/dev/null || true
    fi
    
    # Remover configuração do Nginx para o Portainer
    rm -f /etc/nginx/sites-enabled/portainer 2>/dev/null || true
    rm -f /etc/nginx/sites-available/portainer 2>/dev/null || true
    
    if command -v nginx &> /dev/null; then
        nginx -t && systemctl reload nginx || log_warning "Teste de configuração do Nginx falhou"
    fi
    
    log_success "Componentes do Portainer removidos"
}

remove_coolify() {
    log_info "Removendo instalação do Coolify..."
    
    # Coolify tem seu próprio processo de desinstalação
    if [ -d "/data/coolify" ]; then
        log_warning "Diretório de dados do Coolify detectado"
        log_warning "Por favor, use o método oficial de desinstalação do Coolify ou remova manualmente /data/coolify"
    fi
    
    # Remover containers do Coolify
    log_info "Parando containers do Coolify..."
    docker ps -a --format '{{.Names}}' | grep -i coolify | xargs -r docker stop 2>/dev/null || true
    docker ps -a --format '{{.Names}}' | grep -i coolify | xargs -r docker rm 2>/dev/null || true
    
    log_success "Componentes do Coolify removidos"
}

remove_easypanel() {
    log_info "Removendo instalação do Easypanel..."
    
    # Parar containers do Easypanel
    docker ps -a --format '{{.Names}}' | grep -i easypanel | xargs -r docker stop 2>/dev/null || true
    docker ps -a --format '{{.Names}}' | grep -i easypanel | xargs -r docker rm 2>/dev/null || true
    
    # Remover diretório de configuração do Easypanel
    if [ -d "/etc/easypanel" ]; then
        log_info "Removendo diretório de configuração do Easypanel..."
        rm -rf /etc/easypanel
    fi
    
    log_success "Componentes do Easypanel removidos"
}

remove_common_components() {
    log_info "Removendo componentes comuns..."
    
    # Remover diretório da aplicação
    if [ -d "$APP_DIR" ]; then
        log_info "Removendo diretório da aplicação: $APP_DIR"
        rm -rf "$APP_DIR"
    fi
    
    # Remover usuário da aplicação
    if id "$APP_USER" &>/dev/null; then
        log_info "Removendo usuário da aplicação: $APP_USER"
        
        # Matar quaisquer processos do usuário
        pkill -u "$APP_USER" 2>/dev/null || true
        sleep 2
        
        # Remover usuário
        userdel -r "$APP_USER" 2>/dev/null || true
    fi
    
    # Remover diretório de configuração
    if [ -d "/etc/flashp" ]; then
        log_info "Removendo diretório de configuração..."
        rm -rf /etc/flashp
    fi
    
    log_success "Componentes comuns removidos"
}

cleanup_docker() {
    if ! command -v docker &> /dev/null; then
        return
    fi
    
    echo
    read -p "Remover imagens e volumes Docker não utilizados? (s/n): " cleanup_choice
    
    if [[ $cleanup_choice =~ ^[SsYy]$ ]]; then
        log_info "Limpando recursos do Docker..."
        docker system prune -af --volumes 2>/dev/null || true
        log_success "Limpeza do Docker concluída"
    fi
}

cleanup_nginx() {
    if ! command -v nginx &> /dev/null; then
        return
    fi
    
    echo
    read -p "Remover Nginx? (s/n): " remove_nginx
    
    if [[ $remove_nginx =~ ^[SsYy]$ ]]; then
        log_info "Removendo Nginx..."
        systemctl stop nginx 2>/dev/null || true
        apt-get remove -y nginx nginx-common 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        log_success "Nginx removido"
    fi
}

cleanup_logs() {
    echo
    read -p "Remover logs do Flashp? (s/n): " remove_logs
    
    if [[ $remove_logs =~ ^[SsYy]$ ]]; then
        log_info "Removendo diretório de logs (mantendo este log de desinstalação)..."
        find "$LOG_DIR" -type f ! -name "$(basename $UNINSTALL_LOG)" -delete 2>/dev/null || true
        log_success "Logs removidos"
    else
        log_info "Logs preservados em $LOG_DIR"
    fi
}

# ============================================================================
# PROCESSO PRINCIPAL DE DESINSTALAÇÃO
# ============================================================================

main() {
    show_banner
    validate_root
    confirm_uninstall
    
    echo
    log_info "Iniciando processo de desinstalação..."
    log_info "Log de desinstalação: $UNINSTALL_LOG"
    echo
    
    # Detectar método de instalação
    local method=$(get_installation_method)
    log_info "Método de instalação detectado: $method"
    
    # Remover baseado no método
    case $method in
        bare_metal)
            remove_bare_metal
            ;;
        portainer)
            remove_portainer
            ;;
        coolify)
            remove_coolify
            ;;
        easypanel)
            remove_easypanel
            ;;
        desconhecido)
            log_warning "Método de instalação desconhecido, tentando remover todos os componentes..."
            remove_bare_metal
            remove_portainer
            remove_coolify
            remove_easypanel
            ;;
    esac
    
    # Remover componentes comuns
    remove_common_components
    
    # Limpezas opcionais
    cleanup_docker
    cleanup_nginx
    cleanup_logs
    
    echo
    log_success "═══════════════════════════════════════════════════"
    log_success "  Flashp foi completamente desinstalado!"
    log_success "  Log de desinstalação: $UNINSTALL_LOG"
    log_success "═══════════════════════════════════════════════════"
    echo
    
    if [ -d "/var/backups/flashp_"* ] 2>/dev/null; then
        echo -e "${BLUE}Backups disponíveis em:${NC}"
        ls -1d /var/backups/flashp_* 2>/dev/null || true
    fi
}

# Executar função principal
main "$@"