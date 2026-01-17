#!/bin/bash

################################################################################
# Flashp Domain Manager - Gerenciador de Domínios para Portainer
# Versão: 1.0.0
# Descrição: Automatiza configuração de Nginx + SSL para aplicações no Portainer
################################################################################

set -euo pipefail

# Cores
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

readonly LOG_DIR="/var/log/flashp"
readonly LOG_FILE="${LOG_DIR}/domain_$(date +%Y%m%d_%H%M%S).log"
readonly NGINX_SITES="/etc/nginx/sites-available"
readonly NGINX_ENABLED="/etc/nginx/sites-enabled"

# ============================================================================
# LOGGING
# ============================================================================

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

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
# VALIDAÇÕES
# ============================================================================

validate_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

validate_domain() {
    local domain="$1"
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Formato de domínio inválido: $domain"
        return 1
    fi
    return 0
}

validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "Porta inválida: $port (deve ser entre 1-65535)"
        return 1
    fi
    return 0
}

validate_email() {
    local email="$1"
    if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Formato de email inválido: $email"
        return 1
    fi
    return 0
}

check_port_in_use() {
    local port="$1"
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        return 0  # Porta em uso
    else
        return 1  # Porta livre
    fi
}

check_domain_exists() {
    local domain="$1"
    local config_name=$(echo "$domain" | sed 's/\./-/g')
    
    if [ -f "$NGINX_SITES/$config_name" ]; then
        return 0  # Domínio já configurado
    else
        return 1  # Domínio não configurado
    fi
}

# ============================================================================
# FUNÇÕES PRINCIPAIS
# ============================================================================

show_banner() {
    clear
    cat <<EOF
${BLUE}
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║        🌐 FLASHP DOMAIN MANAGER v1.0 🌐                  ║
║                                                           ║
║        Gerenciador de Domínios para Portainer            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
${NC}

EOF
}

show_main_menu() {
    echo -e "${BLUE}O que você deseja fazer?${NC}"
    echo
    echo "  1) Adicionar novo domínio"
    echo "  2) Listar domínios configurados"
    echo "  3) Remover domínio"
    echo "  4) Renovar certificado SSL"
    echo "  5) Testar configuração do Nginx"
    echo "  6) Remover COMPLETAMENTE Nginx + Certbot"
    echo "  7) Sair"
    echo
    read -p "Opção: " option
    
    case $option in
        1) add_domain ;;
        2) list_domains ;;
        3) remove_domain ;;
        4) renew_ssl ;;
        5) test_nginx ;;
        6) purge_nginx_certbot ;;
        7) log_info "Saindo..."; exit 0 ;;
        *) log_error "Opção inválida"; show_main_menu ;;
    esac
}

add_domain() {
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         ADICIONAR NOVO DOMÍNIO                    ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo
    
    # Coletar informações
    local domain port email use_ssl
    
    # Domínio
    while true; do
        read -p "Digite o domínio (ex: app.seudominio.com): " domain
        if validate_domain "$domain"; then
            if check_domain_exists "$domain"; then
                log_warning "Este domínio já está configurado!"
                read -p "Deseja reconfigurar? (s/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
                    show_main_menu
                    return
                fi
            fi
            break
        fi
    done
    
    # Porta
    while true; do
        read -p "Digite a porta da aplicação no Portainer (ex: 5000): " port
        if validate_port "$port"; then
            if ! check_port_in_use "$port"; then
                log_warning "A porta $port não parece estar em uso"
                read -p "Continuar mesmo assim? (s/n): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
                    continue
                fi
            fi
            break
        fi
    done
    
    # SSL
    read -p "Configurar SSL/HTTPS? (s/n) [s]: " use_ssl
    use_ssl=${use_ssl:-s}
    
    if [[ $use_ssl =~ ^[SsYy]$ ]]; then
        while true; do
            read -p "Digite seu email para o certificado SSL: " email
            if validate_email "$email"; then
                break
            fi
        done
    fi
    
    # WebSocket
    read -p "Esta aplicação usa WebSocket? (s/n) [n]: " use_websocket
    use_websocket=${use_websocket:-n}
    
    # Resumo
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Resumo da Configuração:${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo "Domínio: $domain"
    echo "Porta: $port"
    echo "SSL: $([ "$use_ssl" = "s" ] || [ "$use_ssl" = "S" ] && echo "Sim" || echo "Não")"
    echo "WebSocket: $([ "$use_websocket" = "s" ] || [ "$use_websocket" = "S" ] && echo "Sim" || echo "Não")"
    [ "$use_ssl" = "s" ] || [ "$use_ssl" = "S" ] && echo "Email: $email"
    echo
    
    read -p "Confirmar? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
        log_info "Operação cancelada"
        show_main_menu
        return
    fi
    
    # Verificar DNS
    check_dns "$domain"
    
    # Criar configuração
    create_nginx_config "$domain" "$port" "$use_websocket"
    
    # Configurar SSL se solicitado
    if [[ $use_ssl =~ ^[SsYy]$ ]]; then
        configure_ssl "$domain" "$email"
    fi
    
    log_success "═══════════════════════════════════════════════════"
    log_success "  Domínio configurado com sucesso!"
    log_success "  Acesso: http$([ "$use_ssl" = "s" ] || [ "$use_ssl" = "S" ] && echo "s")://$domain"
    log_success "  Log: $LOG_FILE"
    log_success "═══════════════════════════════════════════════════"
    
    echo
    read -p "Pressione ENTER para voltar ao menu..."
    show_main_menu
}

check_dns() {
    local domain="$1"
    local server_ip=$(hostname -I | awk '{print $1}')
    local domain_ip=$(dig +short "$domain" | tail -n1)
    
    log_info "Verificando DNS para $domain..."
    
    if [ -z "$domain_ip" ]; then
        log_warning "⚠️  O domínio $domain não resolve para nenhum IP"
        log_warning "⚠️  Certifique-se de configurar o registro DNS:"
        log_warning "    Tipo A: $domain → $server_ip"
        echo
        read -p "DNS configurado? Continuar? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            log_info "Operação cancelada"
            show_main_menu
            exit 0
        fi
    elif [ "$domain_ip" != "$server_ip" ]; then
        log_warning "⚠️  Domínio resolve para: $domain_ip"
        log_warning "⚠️  IP do servidor: $server_ip"
        log_warning "⚠️  Os IPs não correspondem!"
        echo
        read -p "Continuar mesmo assim? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            log_info "Operação cancelada"
            show_main_menu
            exit 0
        fi
    else
        log_success "✓ DNS configurado corretamente ($domain_ip)"
    fi
}

create_nginx_config() {
    local domain="$1"
    local port="$2"
    local use_websocket="$3"
    local config_name=$(echo "$domain" | sed 's/\./-/g')
    local config_file="$NGINX_SITES/$config_name"
    
    log_info "Criando configuração do Nginx..."
    
    # Headers WebSocket adicionais
    local websocket_headers=""
    if [[ $use_websocket =~ ^[SsYy]$ ]]; then
        websocket_headers="
    # Configurações WebSocket
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_cache_bypass \$http_upgrade;"
    fi
    
    cat > "$config_file" <<EOF
# Configuração criada por Flashp Domain Manager
# Domínio: $domain
# Porta: $port
# Data: $(date)

server {
    listen 80;
    server_name $domain;

    # Logs
    access_log /var/log/nginx/${config_name}-access.log;
    error_log /var/log/nginx/${config_name}-error.log;

    location / {
        proxy_pass http://localhost:$port;$websocket_headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 600;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
        send_timeout 600;
    }
}
EOF
    
    # Habilitar site
    ln -sf "$config_file" "$NGINX_ENABLED/$config_name"
    
    # Testar configuração
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        systemctl reload nginx
        log_success "Configuração do Nginx criada e ativada"
    else
        log_error "Erro na configuração do Nginx"
        rm -f "$config_file" "$NGINX_ENABLED/$config_name"
        exit 1
    fi
}

configure_ssl() {
    local domain="$1"
    local email="$2"
    
    log_info "Configurando certificado SSL..."
    
    # Verificar se certbot está instalado
    if ! command -v certbot &> /dev/null; then
        log_info "Instalando Certbot..."
        apt-get update -qq
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Gerar certificado
    if certbot --nginx -d "$domain" \
        --non-interactive \
        --agree-tos \
        --email "$email" \
        --redirect 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Certificado SSL configurado com sucesso"
    else
        log_error "Falha ao configurar SSL"
        log_warning "O domínio ainda está acessível via HTTP"
        log_warning "Verifique:"
        log_warning "  1. DNS está propagado corretamente"
        log_warning "  2. Portas 80 e 443 estão abertas no firewall"
        log_warning "  3. Não há outro serviço usando essas portas"
    fi
}

list_domains() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}         DOMÍNIOS CONFIGURADOS                     ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    
    local count=0
    for config in "$NGINX_SITES"/*; do
        if [ -f "$config" ] && [ "$(basename "$config")" != "default" ] && [ "$(basename "$config")" != "flashp" ] && [ "$(basename "$config")" != "portainer" ] && [ "$(basename "$config")" != "coolify" ] && [ "$(basename "$config")" != "easypanel" ]; then
            local domain=$(grep -m 1 "server_name" "$config" | awk '{print $2}' | tr -d ';')
            local port=$(grep -m 1 "proxy_pass" "$config" | grep -oP ':\d+' | tr -d ':')
            local ssl_status="HTTP"
            
            if grep -q "listen 443 ssl" "$config" 2>/dev/null; then
                ssl_status="HTTPS ✓"
            fi
            
            echo -e "${GREEN}Domínio:${NC} $domain"
            echo -e "${BLUE}Porta:${NC} $port"
            echo -e "${YELLOW}SSL:${NC} $ssl_status"
            echo -e "${BLUE}Config:${NC} $(basename "$config")"
            echo "---"
            
            ((count++))
        fi
    done
    
    if [ $count -eq 0 ]; then
        echo "Nenhum domínio configurado ainda."
    else
        echo
        echo "Total: $count domínio(s) configurado(s)"
    fi
    
    echo
    read -p "Pressione ENTER para voltar ao menu..."
    show_main_menu
}

remove_domain() {
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         REMOVER DOMÍNIO                           ${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo
    
    read -p "Digite o domínio a remover (ex: app.seudominio.com): " domain
    
    if ! validate_domain "$domain"; then
        show_main_menu
        return
    fi
    
    local config_name=$(echo "$domain" | sed 's/\./-/g')
    
    if ! check_domain_exists "$domain"; then
        log_error "Domínio não encontrado na configuração"
        read -p "Pressione ENTER para voltar ao menu..."
        show_main_menu
        return
    fi
    
    echo
    echo -e "${RED}⚠️  ATENÇÃO: Isso removerá:${NC}"
    echo "  - Configuração do Nginx"
    echo "  - Certificado SSL (se existir)"
    echo
    read -p "Confirmar remoção de $domain? (s/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
        log_info "Operação cancelada"
        show_main_menu
        return
    fi
    
    log_info "Removendo $domain..."
    
    # Remover certificado SSL
    if certbot certificates 2>/dev/null | grep -q "$domain"; then
        log_info "Removendo certificado SSL..."
        certbot delete --cert-name "$domain" --non-interactive 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Remover configurações Nginx
    rm -f "$NGINX_ENABLED/$config_name"
    rm -f "$NGINX_SITES/$config_name"
    
    # Recarregar Nginx
    if nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        systemctl reload nginx
        log_success "Domínio $domain removido com sucesso"
    else
        log_error "Erro ao recarregar Nginx"
    fi
    
    echo
    read -p "Pressione ENTER para voltar ao menu..."
    show_main_menu
}

renew_ssl() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}         RENOVAR CERTIFICADOS SSL                  ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    
    if ! command -v certbot &> /dev/null; then
        log_error "Certbot não está instalado"
        read -p "Pressione ENTER para voltar ao menu..."
        show_main_menu
        return
    fi
    
    log_info "Renovando certificados..."
    
    if certbot renew 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Certificados renovados com sucesso"
    else
        log_warning "Nenhum certificado precisa ser renovado ou houve erro"
    fi
    
    echo
    read -p "Pressione ENTER para voltar ao menu..."
    show_main_menu
}

test_nginx() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}         TESTAR CONFIGURAÇÃO DO NGINX              ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    
    if nginx -t; then
        log_success "Configuração do Nginx está OK"
    else
        log_error "Há erros na configuração do Nginx"
    fi
    
    echo
    read -p "Pressione ENTER para voltar ao menu..."
    show_main_menu
}

# ============================================================================
# EXECUÇÃO PRINCIPAL
# ============================================================================

purge_nginx_certbot() {
    echo
    echo -e "${RED}⚠️  AVISO CRÍTICO: Isso removerá COMPLETAMENTE o Nginx e o Certbot do sistema!${NC}"
    echo "Esta ação purgará todos os binários, configurações, certificados e logs."
    echo
    read -p "Deseja continuar? (s/N): " confirm
    if [[ ! $confirm =~ ^[SsYy]$ ]]; then
        log_info "Operação cancelada"
        show_main_menu
        return
    fi

    log_info "Iniciando purga do Nginx..."
    sudo systemctl stop nginx 2>/dev/null || true
    sudo systemctl disable nginx 2>/dev/null || true
    sudo apt remove --purge nginx nginx-common nginx-core -y
    sudo apt remove --purge nginx-full nginx-light -y
    sudo apt autoremove --purge -y
    sudo apt autoclean
    sudo rm -rf /etc/nginx
    sudo rm -rf /var/log/nginx
    sudo rm -rf /var/cache/nginx
    sudo rm -rf /usr/share/nginx

    log_info "Iniciando purga do Certbot..."
    sudo systemctl stop certbot.timer 2>/dev/null || true
    sudo systemctl disable certbot.timer 2>/dev/null || true
    sudo systemctl stop certbot.service 2>/dev/null || true
    sudo systemctl disable certbot.service 2>/dev/null || true
    sudo apt remove --purge certbot -y
    sudo apt remove --purge python3-certbot-nginx python3-certbot-apache -y
    sudo apt autoremove --purge -y
    sudo apt autoclean
    sudo rm -rf /etc/letsencrypt
    sudo rm -rf /var/lib/letsencrypt
    sudo rm -rf /var/log/letsencrypt

    log_info "Limpando timers/cron remanescentes..."
    # systemctl list-timers | grep certbot
    sudo ls -l /etc/cron.d | grep certbot || true
    sudo rm -f /etc/cron.d/certbot

    log_success "Remoção concluída. Validando estado..."
    whereis nginx
    whereis certbot
    
    echo
    read -p "Pressione ENTER para voltar ao menu..."
    show_main_menu
}

main() {
    show_banner
    validate_root
    log_info "Domain Manager iniciado - Log: $LOG_FILE"
    show_main_menu
}

main "$@"