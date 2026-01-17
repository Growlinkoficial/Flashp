#!/bin/bash

################################################################################
# Flashp Deployer - Script de Instalação Automatizada
# Versão: 2.0.0
# Autor: Equipe Flashp
# Descrição: Instalador production-ready com segurança e suporte a rollback
################################################################################

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# VARIÁVEIS GLOBAIS
# ============================================================================

readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="/var/log/flashp"
readonly LOG_FILE="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"
readonly CONFIG_FILE="/etc/flashp/install.conf"
readonly APP_USER="flashp"
readonly APP_DIR="/opt/flashp"
readonly MIN_RAM_MB=2048
readonly MIN_DISK_GB=10

# Cores
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Rastreamento de estado
declare -a CLEANUP_STACK=()
INSTALLATION_STARTED=0

# Detecção de infraestrutura
HAS_NGINX=0
HAS_DOCKER=0
HAS_PORTAINER=0
HAS_COOLIFY=0
HAS_EASYPANEL=0
HAS_DOMAIN=0

# Inputs do usuário
DOMAIN=""
SUBDOMAIN=""
FULL_DOMAIN=""
GIT_URL=""
ADMIN_EMAIL=""

# ============================================================================
# SISTEMA DE LOGGING
# ============================================================================

setup_logging() {
    mkdir -p "$LOG_DIR"
    exec > >(tee -a "$LOG_FILE") 2>&1
    log_info "Instalação iniciada - Versão $SCRIPT_VERSION"
    log_info "Arquivo de log: $LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# ============================================================================
# TRATAMENTO DE ERROS & CLEANUP
# ============================================================================

cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ $INSTALLATION_STARTED -eq 1 ]; then
        log_error "Instalação falhou com código de saída $exit_code"
        log_warning "Iniciando rollback..."
        
        # Executar stack de cleanup em ordem reversa
        for ((i=${#CLEANUP_STACK[@]}-1; i>=0; i--)); do
            log_info "Rollback: ${CLEANUP_STACK[$i]}"
            eval "${CLEANUP_STACK[$i]}" || true
        done
        
        log_warning "Rollback concluído. Verifique o log: $LOG_FILE"
    fi
}

trap cleanup_on_error EXIT ERR

add_cleanup() {
    CLEANUP_STACK+=("$1")
}

# ============================================================================
# FUNÇÕES DE VALIDAÇÃO
# ============================================================================

validate_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "Este script deve ser executado como root (use sudo)"
        exit 1
    fi
}

validate_domain() {
    local domain="$1"
    
    # Validação básica de domínio com regex
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "Formato de domínio inválido: $domain"
        return 1
    fi
    
    # Verificar se o domínio resolve para este servidor
    local server_ip=$(hostname -I | awk '{print $1}')
    local domain_ip=$(dig +short "$domain" | tail -n1)
    
    if [ -z "$domain_ip" ]; then
        log_warning "O domínio $domain não resolve para nenhum IP"
        log_warning "Certifique-se de que o DNS está configurado corretamente"
        read -p "Continuar mesmo assim? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            return 1
        fi
    elif [ "$domain_ip" != "$server_ip" ]; then
        log_warning "Domínio resolve para $domain_ip mas o IP do servidor é $server_ip"
        read -p "Continuar mesmo assim? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            return 1
        fi
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

validate_git_url() {
    local url="$1"
    if [[ ! $url =~ ^https?://.*\.git$ ]] && [[ ! $url =~ ^git@.*:.+\.git$ ]]; then
        log_warning "A URL Git pode estar inválida: $url"
        read -p "Continuar mesmo assim? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
            return 1
        fi
    fi
    return 0
}

check_prerequisites() {
    log_info "Verificando pré-requisitos do sistema..."
    
    # Verificar RAM
    local total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt "$MIN_RAM_MB" ]; then
        log_warning "RAM disponível (${total_ram}MB) está abaixo do recomendado (${MIN_RAM_MB}MB)"
    else
        log_success "Verificação de RAM aprovada: ${total_ram}MB disponíveis"
    fi
    
    # Verificar espaço em disco
    local available_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_disk" -lt "$MIN_DISK_GB" ]; then
        log_error "Espaço em disco insuficiente: ${available_disk}GB disponíveis, ${MIN_DISK_GB}GB necessários"
        exit 1
    else
        log_success "Verificação de espaço em disco aprovada: ${available_disk}GB disponíveis"
    fi
    
    # Verificar portas necessárias
    check_port_available 80 "HTTP"
    check_port_available 443 "HTTPS"
    check_port_available 3000 "Aplicação"
}

check_port_available() {
    local port=$1
    local service=$2
    
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        log_warning "Porta $port ($service) já está em uso"
    else
        log_success "Porta $port ($service) está disponível"
    fi
}

# ============================================================================
# DETECÇÃO DE INFRAESTRUTURA
# ============================================================================

check_infrastructure() {
    log_info "Auditando infraestrutura existente..."
    
    # Nginx
    if command -v nginx &> /dev/null; then
        HAS_NGINX=1
        log_success "Nginx detectado: $(nginx -v 2>&1 | cut -d'/' -f2)"
    fi
    
    # Docker
    if command -v docker &> /dev/null; then 
        HAS_DOCKER=1
        log_success "Docker detectado: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        
        # Portainer
        if docker ps -a --format '{{.Names}}' | grep -q "portainer"; then
            HAS_PORTAINER=1
            log_success "Portainer detectado"
        fi
        
        # Easypanel
        if docker ps -a --format '{{.Names}}' | grep -q "easypanel"; then
            HAS_EASYPANEL=1
            log_success "Easypanel detectado"
        fi
    fi
    
    # Coolify
    if [ -d "/data/coolify" ] || [ -d "/var/lib/coolify" ]; then
        HAS_COOLIFY=1
        log_success "Coolify detectado"
    fi
    
    # Easypanel (detecção alternativa)
    if [ -d "/etc/easypanel" ]; then
        HAS_EASYPANEL=1
        log_success "Easypanel detectado (via diretório de config)"
    fi
}

# ============================================================================
# CONFIGURAÇÃO DE DOMÍNIO
# ============================================================================

configure_domain() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}         CONFIGURAÇÃO DE DOMÍNIO/SUBDOMÍNIO        ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo
    echo "Você possui um domínio ou subdomínio apontando para este servidor?"
    echo "1) Sim - Usar Domínio/Subdomínio com SSL/HTTPS"
    echo "2) Não - Usar apenas endereço IP (HTTP)"
    echo
    read -p "Opção: " domain_choice
    
    case $domain_choice in
        1)
            HAS_DOMAIN=1
            configure_domain_details
            ;;
        2)
            HAS_DOMAIN=0
            log_warning "Operando em modo somente IP (sem SSL/HTTPS)"
            ;;
        *)
            log_error "Opção inválida"
            configure_domain
            ;;
    esac
}

configure_domain_details() {
    echo
    echo -e "${YELLOW}Opções de Configuração de Domínio:${NC}"
    echo "1) Usar um subdomínio (ex: app.exemplo.com)"
    echo "2) Usar apenas domínio raiz (ex: exemplo.com)"
    echo
    read -p "Opção: " domain_type
    
    case $domain_type in
        1)
            while true; do
                read -p "Digite seu subdomínio (ex: app, flashp, painel): " SUBDOMAIN
                read -p "Digite seu domínio raiz (ex: exemplo.com): " DOMAIN
                
                FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
                
                if validate_domain "$FULL_DOMAIN"; then
                    log_success "Domínio configurado: $FULL_DOMAIN"
                    break
                else
                    log_error "Configuração de domínio inválida. Tente novamente."
                fi
            done
            ;;
        2)
            while true; do
                read -p "Digite seu domínio (ex: exemplo.com): " DOMAIN
                FULL_DOMAIN="$DOMAIN"
                SUBDOMAIN=""
                
                if validate_domain "$FULL_DOMAIN"; then
                    log_success "Domínio configurado: $FULL_DOMAIN"
                    break
                else
                    log_error "Domínio inválido. Tente novamente."
                fi
            done
            ;;
        *)
            log_error "Opção inválida"
            configure_domain_details
            ;;
    esac
    
    # Solicitar email do administrador para SSL
    while true; do
        read -p "Digite o email do administrador para certificados SSL: " ADMIN_EMAIL
        if validate_email "$ADMIN_EMAIL"; then
            break
        else
            log_error "Email inválido. Tente novamente."
        fi
    done
}

# ============================================================================
# PREPARAÇÃO DO SISTEMA
# ============================================================================

prepare_system() {
    log_info "Atualizando pacotes do sistema..."
    apt-get update -qq
    apt-get upgrade -y -qq
    
    # Instalar pacotes essenciais
    log_info "Instalando pacotes essenciais..."
    apt-get install -y -qq curl wget git ufw fail2ban htop net-tools dnsutils
    
    # Criar usuário da aplicação
    if ! id "$APP_USER" &>/dev/null; then
        log_info "Criando usuário da aplicação: $APP_USER"
        useradd -r -s /bin/bash -d "$APP_DIR" -m "$APP_USER"
        add_cleanup "userdel -r $APP_USER 2>/dev/null || true"
    fi
    
    # Criar diretório de configuração
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    log_success "Preparação do sistema concluída"
}

# ============================================================================
# MÉTODO DE INSTALAÇÃO: BARE METAL
# ============================================================================

install_bare_metal() {
    log_info "Iniciando instalação Bare Metal..."
    INSTALLATION_STARTED=1
    
    # Instalar Node.js
    install_nodejs
    
    # Obter URL do repositório
    get_git_repository
    
    # Clonar e compilar
    clone_and_build_app
    
    # Configurar PM2
    configure_pm2
    
    # Configurar Nginx
    configure_nginx_bare_metal
    
    # Configurar SSL se domínio disponível
    if [ $HAS_DOMAIN -eq 1 ]; then
        configure_ssl
        local access_url="https://$FULL_DOMAIN"
    else
        local access_url="http://$(hostname -I | awk '{print $1}')"
    fi
    
    # Salvar configuração
    save_installation_config "bare_metal"
    
    # Verificação de saúde
    perform_health_check "$access_url"
    
    log_success "═══════════════════════════════════════════════════"
    log_success "  Flashp instalado com sucesso!"
    log_success "  URL de acesso: $access_url"
    log_success "  Log de instalação: $LOG_FILE"
    log_success "═══════════════════════════════════════════════════"
}

install_nodejs() {
    if command -v node &> /dev/null; then
        log_info "Node.js já instalado: $(node --version)"
        return
    fi
    
    log_info "Instalando Node.js 20 via NVM..."
    
    # Instalar NVM como usuário da aplicação
    sudo -u "$APP_USER" bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash"
    
    # Carregar NVM e instalar Node
    sudo -u "$APP_USER" bash -c "
        export NVM_DIR=\"$APP_DIR/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        nvm install 20
        nvm use 20
        nvm alias default 20
    "
    
    add_cleanup "sudo -u $APP_USER bash -c 'rm -rf $APP_DIR/.nvm' 2>/dev/null || true"
    log_success "Node.js instalado com sucesso"
}

get_git_repository() {
    while true; do
        read -p "Digite a URL do repositório Flashp: " GIT_URL
        if validate_git_url "$GIT_URL"; then
            break
        fi
    done
}

clone_and_build_app() {
    local repo_dir="$APP_DIR/flashp"
    
    log_info "Clonando repositório..."
    if [ -d "$repo_dir" ]; then
        log_warning "Diretório já existe. Removendo..."
        rm -rf "$repo_dir"
    fi
    
    sudo -u "$APP_USER" git clone "$GIT_URL" "$repo_dir"
    add_cleanup "rm -rf $repo_dir 2>/dev/null || true"
    
    log_info "Instalando dependências e compilando..."
    cd "$repo_dir"
    
    sudo -u "$APP_USER" bash -c "
        export NVM_DIR=\"$APP_DIR/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        npm install
        npm run build
    "
    
    log_success "Aplicação compilada com sucesso"
}

configure_pm2() {
    log_info "Configurando PM2..."
    
    sudo -u "$APP_USER" bash -c "
        export NVM_DIR=\"$APP_DIR/.nvm\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        npm install -g pm2
        cd $APP_DIR/flashp
        pm2 start npm --name flashp -- start
        pm2 save
    "
    
    # Configurar inicialização do PM2
    env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u "$APP_USER" --hp "$APP_DIR"
    
    add_cleanup "sudo -u $APP_USER pm2 delete flashp 2>/dev/null || true"
    log_success "PM2 configurado com sucesso"
}

configure_nginx_bare_metal() {
    # Instalar Nginx se necessário
    if [ $HAS_NGINX -eq 0 ]; then
        log_info "Instalando Nginx..."
        apt-get install -y nginx
        systemctl enable nginx
        add_cleanup "apt-get remove -y nginx 2>/dev/null || true"
    fi
    
    local conf_file="/etc/nginx/sites-available/flashp"
    
    if [ $HAS_DOMAIN -eq 1 ]; then
        local server_name="$FULL_DOMAIN"
    else
        local server_name="_"
    fi
    
    log_info "Criando configuração do Nginx..."
    
    # Remover configurações antigas se existirem
    rm -f /etc/nginx/sites-enabled/flashp 2>/dev/null || true
    rm -f /etc/nginx/sites-available/flashp 2>/dev/null || true
    
    cat > "$conf_file" <<EOF
server {
    listen 80;
    server_name $server_name;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    ln -sf "$conf_file" /etc/nginx/sites-enabled/flashp
    add_cleanup "rm -f /etc/nginx/sites-enabled/flashp /etc/nginx/sites-available/flashp 2>/dev/null || true"
    
    # Testar antes de recarregar
    if ! nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Erro na configuração do Nginx"
        log_info "Removendo configuração problemática..."
        rm -f "$conf_file" /etc/nginx/sites-enabled/flashp
        return 1
    fi
    
    if ! systemctl reload nginx; then
        log_error "Falha ao recarregar Nginx"
        # Tentar restart
        log_info "Tentando restart completo do Nginx..."
        systemctl restart nginx || {
            log_error "Falha ao reiniciar Nginx"
            return 1
        }
    fi
    
    log_success "Nginx configurado com sucesso"
}

configure_ssl() {
    log_info "Configurando certificado SSL..."
    
    # Instalar Certbot
    if ! command -v certbot &> /dev/null; then
        apt-get install -y certbot python3-certbot-nginx
    fi
    
    # Obter certificado
    certbot --nginx -d "$FULL_DOMAIN" \
        --non-interactive \
        --agree-tos \
        --email "$ADMIN_EMAIL" \
        --redirect || {
            log_error "Falha na geração do certificado SSL"
            log_warning "Continuando apenas com HTTP"
            return 1
        }
    
    log_success "SSL configurado com sucesso"
}

# ============================================================================
# MÉTODO DE INSTALAÇÃO: DOCKER + PORTAINER
# ============================================================================

install_portainer() {
    log_info "Iniciando instalação do Portainer..."
    INSTALLATION_STARTED=1
    
    # Instalar Docker se necessário
    if [ $HAS_DOCKER -eq 0 ]; then
        install_docker
    fi
    
    if [ $HAS_PORTAINER -eq 1 ]; then
        log_info "Portainer já instalado"
        show_portainer_instructions
    else
        deploy_portainer
    fi
    
    save_installation_config "portainer"
}

install_docker() {
    log_info "Instalando Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker "$APP_USER" || true
    add_cleanup "systemctl stop docker 2>/dev/null || true"
    log_success "Docker instalado com sucesso"
}

deploy_portainer() {
    log_info "Implantando Portainer..."
    
    docker volume create portainer_data
    add_cleanup "docker volume rm portainer_data 2>/dev/null || true"
    
    docker run -d \
        -p 8000:8000 \
        -p 9443:9443 \
        --name portainer \
        --restart=always \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce:latest
    
    add_cleanup "docker rm -f portainer 2>/dev/null || true"
    
    # Configurar acesso por domínio se disponível
    if [ $HAS_DOMAIN -eq 1 ]; then
        configure_portainer_domain
        local access_url="https://$FULL_DOMAIN"
    else
        local access_url="https://$(hostname -I | awk '{print $1}'):9443"
    fi
    
    log_success "═══════════════════════════════════════════════════"
    log_success "  Portainer instalado com sucesso!"
    log_success "  URL de acesso: $access_url"
    log_success "  Credenciais padrão serão definidas no primeiro login"
    log_success "═══════════════════════════════════════════════════"
}

configure_portainer_domain() {
    if [ $HAS_NGINX -eq 0 ]; then
        apt-get install -y nginx
        systemctl enable nginx
    fi
    
    local config_name="portainer"
    local config_file="/etc/nginx/sites-available/$config_name"
    
    # Remover configurações antigas se existirem
    rm -f /etc/nginx/sites-enabled/portainer 2>/dev/null || true
    rm -f /etc/nginx/sites-available/portainer 2>/dev/null || true
    
    cat > "$config_file" <<EOF
server {
    listen 80;
    server_name $FULL_DOMAIN;

    location / {
        proxy_pass https://localhost:9443;
        proxy_ssl_verify off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    ln -sf "$config_file" /etc/nginx/sites-enabled/
    
    # Testar antes de recarregar
    if ! nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Erro na configuração do Nginx"
        log_info "Removendo configuração problemática..."
        rm -f "$config_file" /etc/nginx/sites-enabled/$config_name
        return 1
    fi
    
    systemctl reload nginx || {
        log_error "Falha ao recarregar Nginx"
        return 1
    }
    
    configure_ssl
}

show_portainer_instructions() {
    cat <<EOF

${BLUE}═══════════════════════════════════════════════════${NC}
${BLUE}  PORTAINER DETECTADO - GUIA DE IMPLANTAÇÃO FLASHP ${NC}
${BLUE}═══════════════════════════════════════════════════${NC}

Para implantar o Flashp no Portainer:

1. Acesse a interface web do Portainer
2. Vá em: Stacks → Add Stack
3. Nome: flashp
4. Método de compilação: Repository
5. URL do repositório: $GIT_URL
6. Variáveis de ambiente:
   - PORT=3000
7. Clique em "Deploy the stack"

EOF
}

# ============================================================================
# MÉTODO DE INSTALAÇÃO: COOLIFY
# ============================================================================

install_coolify() {
    log_info "Iniciando instalação do Coolify..."
    INSTALLATION_STARTED=1
    
    if [ $HAS_COOLIFY -eq 1 ]; then
        show_coolify_instructions
    else
        deploy_coolify
    fi
    
    save_installation_config "coolify"
}

deploy_coolify() {
    log_info "Instalando Coolify..."
    curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash
    
    if [ $HAS_DOMAIN -eq 1 ]; then
        configure_coolify_domain
        local access_url="https://$FULL_DOMAIN"
    else
        local access_url="http://$(hostname -I | awk '{print $1}'):8000"
    fi
    
    log_success "═══════════════════════════════════════════════════"
    log_success "  Coolify instalado com sucesso!"
    log_success "  URL de acesso: $access_url"
    log_success "  Primeiro login exigirá configuração"
    log_success "═══════════════════════════════════════════════════"
}

configure_coolify_domain() {
    if [ $HAS_NGINX -eq 0 ]; then
        apt-get install -y nginx
        systemctl enable nginx
    fi
    
    local config_name="coolify"
    local config_file="/etc/nginx/sites-available/$config_name"
    
    # Remover configurações antigas se existirem
    rm -f /etc/nginx/sites-enabled/coolify 2>/dev/null || true
    rm -f /etc/nginx/sites-available/coolify 2>/dev/null || true
    
    cat > "$config_file" <<EOF
server {
    listen 80;
    server_name $FULL_DOMAIN;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    ln -sf "$config_file" /etc/nginx/sites-enabled/
    
    # Testar antes de recarregar
    if ! nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Erro na configuração do Nginx"
        log_info "Removendo configuração problemática..."
        rm -f "$config_file" /etc/nginx/sites-enabled/$config_name
        return 1
    fi
    
    systemctl reload nginx || {
        log_error "Falha ao recarregar Nginx"
        return 1
    }
    
    configure_ssl
}

show_coolify_instructions() {
    cat <<EOF

${BLUE}═══════════════════════════════════════════════════${NC}
${BLUE}  COOLIFY DETECTADO - GUIA DE IMPLANTAÇÃO FLASHP   ${NC}
${BLUE}═══════════════════════════════════════════════════${NC}

Para implantar o Flashp no Coolify:

1. Acesse o painel web do Coolify (porta 8000)
2. Criar novo Projeto
3. Adicionar Aplicação → Repositório Público
4. URL do repositório: $GIT_URL
5. Build Pack: Nixpacks (detecção automática)
6. Porta: 3000
7. Implantar!

EOF
}

# ============================================================================
# MÉTODO DE INSTALAÇÃO: EASYPANEL
# ============================================================================

install_easypanel() {
    log_info "Iniciando instalação do Easypanel..."
    INSTALLATION_STARTED=1
    
    if [ $HAS_EASYPANEL -eq 1 ]; then
        show_easypanel_instructions
    else
        deploy_easypanel
    fi
    
    save_installation_config "easypanel"
}

deploy_easypanel() {
    log_info "Instalando Easypanel..."
    curl -sSL https://get.easypanel.io | sh
    
    if [ $HAS_DOMAIN -eq 1 ]; then
        configure_easypanel_domain
        local access_url="https://$FULL_DOMAIN"
    else
        local access_url="http://$(hostname -I | awk '{print $1}'):3000"
    fi
    
    log_success "═══════════════════════════════════════════════════"
    log_success "  Easypanel instalado com sucesso!"
    log_success "  URL de acesso: $access_url"
    log_success "═══════════════════════════════════════════════════"
}

configure_easypanel_domain() {
    if [ $HAS_NGINX -eq 0 ]; then
        apt-get install -y nginx
        systemctl enable nginx
    fi
    
    local config_name="easypanel"
    local config_file="/etc/nginx/sites-available/$config_name"
    
    # Remover configurações antigas se existirem
    rm -f /etc/nginx/sites-enabled/easypanel 2>/dev/null || true
    rm -f /etc/nginx/sites-available/easypanel 2>/dev/null || true
    
    cat > "$config_file" <<EOF
server {
    listen 80;
    server_name $FULL_DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    ln -sf "$config_file" /etc/nginx/sites-enabled/
    
    # Testar antes de recarregar
    if ! nginx -t 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Erro na configuração do Nginx"
        log_info "Removendo configuração problemática..."
        rm -f "$config_file" /etc/nginx/sites-enabled/$config_name
        return 1
    fi
    
    systemctl reload nginx || {
        log_error "Falha ao recarregar Nginx"
        return 1
    }
    
    configure_ssl
}

show_easypanel_instructions() {
    cat <<EOF

${BLUE}═══════════════════════════════════════════════════${NC}
${BLUE}  EASYPANEL DETECTADO - GUIA DE IMPLANTAÇÃO FLASHP ${NC}
${BLUE}═══════════════════════════════════════════════════${NC}

Para implantar o Flashp no Easypanel:

1. Acesse o painel do Easypanel (porta 3000)
2. Criar novo Projeto
3. Adicionar Serviço → Git
4. Repositório: $GIT_URL
5. Build: Node.js
6. Porta: 3000
7. Implantar!

EOF
}

# ============================================================================
# UTILITÁRIOS
# ============================================================================

save_installation_config() {
    local method=$1
    
    cat > "$CONFIG_FILE" <<EOF
# Configuração de Instalação do Flashp
# Gerado em: $(date)
VERSION=$SCRIPT_VERSION
METHOD=$method
DOMAIN=$FULL_DOMAIN
SUBDOMAIN=$SUBDOMAIN
ROOT_DOMAIN=$DOMAIN
HAS_DOMAIN=$HAS_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
GIT_URL=$GIT_URL
INSTALL_DATE=$(date +%Y-%m-%d)
INSTALL_TIME=$(date +%H:%M:%S)
EOF
    
    chmod 600 "$CONFIG_FILE"
    log_success "Configuração de instalação salva em $CONFIG_FILE"
}

perform_health_check() {
    local url=$1
    log_info "Realizando verificação de saúde..."
    
    sleep 5
    
    if curl -sSf "$url" > /dev/null 2>&1; then
        log_success "Verificação de saúde aprovada - Aplicação está respondendo"
    else
        log_warning "Verificação de saúde falhou - Aplicação pode não estar pronta ainda"
        log_warning "Por favor, verifique manualmente: $url"
    fi
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================

show_banner() {
    clear
    cat <<EOF
${BLUE}
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          ⚡ INSTALADOR AUTOMATIZADO FLASHP v${SCRIPT_VERSION} ⚡      ║
║                                                           ║
║          Sistema de Implantação Production-Ready          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
${NC}

EOF
}

show_main_menu() {
    check_infrastructure
    
    echo -e "${BLUE}Escolha o método de instalação:${NC}"
    echo
    [ $HAS_NGINX -eq 1 ] && TAG_NGINX="${GREEN}[DETECTADO]${NC}" || TAG_NGINX=""
    [ $HAS_PORTAINER -eq 1 ] && TAG_PORTAINER="${GREEN}[DETECTADO]${NC}" || TAG_PORTAINER=""
    [ $HAS_COOLIFY -eq 1 ] && TAG_COOLIFY="${GREEN}[DETECTADO]${NC}" || TAG_COOLIFY=""
    [ $HAS_EASYPANEL -eq 1 ] && TAG_EASYPANEL="${GREEN}[DETECTADO]${NC}" || TAG_EASYPANEL=""
    
    echo -e "  1) Bare Metal (Node.js + PM2 + Nginx) $TAG_NGINX"
    echo -e "  2) Docker + Portainer $TAG_PORTAINER"
    echo -e "  3) Coolify (Plataforma Completa) $TAG_COOLIFY"
    echo -e "  4) Easypanel (Painel Simples) $TAG_EASYPANEL"
    echo -e "  5) Sair"
    echo
    read -p "Opção: " OPTION
    
    case $OPTION in
        1) install_bare_metal ;;
        2) install_portainer ;;
        3) install_coolify ;;
        4) install_easypanel ;;
        5) log_info "Instalação cancelada pelo usuário"; exit 0 ;;
        *) log_error "Opção inválida"; show_main_menu ;;
    esac
}

# ============================================================================
# EXECUÇÃO PRINCIPAL
# ============================================================================

main() {
    show_banner
    validate_root
    setup_logging
    check_prerequisites
    prepare_system
    configure_domain
    show_main_menu
}

# Executar função principal
main "$@"