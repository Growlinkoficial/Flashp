#!/bin/bash

# Flashp Deployer - Script de Instalação Automatizada
# Versão: 1.0.0

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}################################################"
echo -e "      ⚡ FLASHP - INSTALADOR AUTOMATIZADO ⚡"
echo -e "################################################${NC}"

# Requisito: Root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Por favor, rode como root (sudo).${NC}"
  exit 1
fi

# 1. Preparação do Servidor
echo -e "\n${YELLOW}1. Atualizando pacotes do sistema...${NC}"
apt update && apt upgrade -y

echo -e "\n${BLUE}Escolha o método de instalação:${NC}"
echo "1) Bare Metal (Node.js + PM2 + Nginx + SSL)"
echo "2) Docker + Portainer + Nginx"
echo "3) Coolify (Ferramenta Completa)"
echo "4) Easypanel (Painel Simples)"
echo "5) Sair"
read -p "Opção: " OPTION

case $OPTION in
  1)
    echo -e "\n${YELLOW}### Instalação Bare Metal ###${NC}"
    
    # Node.js via NVM
    if ! command -v node &> /dev/null; then
        echo -e "${BLUE}Instalando Node.js 20...${NC}"
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install 20
        nvm use 20
    fi

    # Git Link
    read -p "Insira o link do repositório Flashp no GitHub: " GIT_URL
    REPO_NAME="flashp"
    git clone "$GIT_URL" $REPO_NAME
    cd $REPO_NAME

    # Config & Build
    echo -e "${BLUE}Instalando dependências e gerando build...${NC}"
    npm install
    npm run build

    # PM2
    echo -e "${BLUE}Configurando PM2...${NC}"
    npm install -g pm2
    pm2 start npm --name "flashp" -- start
    pm2 save
    pm2 startup

    # Nginx
    if ! command -v nginx &> /dev/null; then
        echo -e "${BLUE}Instalando Nginx...${NC}"
        apt install nginx -y
    else
        echo -e "${GREEN}Nginx já detectado. Aplicando manutenções...${NC}"
    fi

    echo -e "\n${BLUE}Configuração de Acesso (Domínio/IP):${NC}"
    echo "1) Com Domínio (Configura Nginx + SSL/HTTPS)"
    echo "2) Sem Domínio (Apenas IP via porta 80)"
    read -p "Opção: " DOMAIN_OPTION

    if [ "$DOMAIN_OPTION" == "1" ]; then
        read -p "Qual será o domínio do projeto? (ex: flashp.seu-dominio.com): " DOMAIN
        CONF_FILE="flashp"
        SERVER_NAME="$DOMAIN"
    else
        DOMAIN=""
        CONF_FILE="flashp_ip"
        SERVER_NAME="_"
        echo -e "${YELLOW}Usando configuração baseada em IP (Porta 80).${NC}"
    fi
    
    # Nginx Config
    cat <<EOF > /etc/nginx/sites-available/$CONF_FILE
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/$CONF_FILE /etc/nginx/sites-enabled/
    nginx -t && systemctl restart nginx

    # SSL (Somente se tiver domínio)
    if [ "$DOMAIN_OPTION" == "1" ]; then
        echo -e "\n${YELLOW}Configurando Certificado SSL...${NC}"
        apt install certbot python3-certbot-nginx -y
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email webmaster@$DOMAIN || echo -e "${RED}Erro ao gerar SSL. Verifique se o domínio está apontado para este IP.${NC}"
        FINAL_URL="https://$DOMAIN"
    else
        FINAL_URL="http://$(hostname -I | awk '{print $1}')"
    fi

    echo -e "\n${GREEN}✔ Flashp instalado com sucesso em: $FINAL_URL${NC}"
    ;;

  2)
    echo -e "\n${YELLOW}### Instalação Portainer + Nginx ###${NC}"
    # Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${BLUE}Instalando Docker...${NC}"
        curl -fsSL https://get.docker.com | sh
    fi
    
    # Portainer
    echo -e "${BLUE}Instalando Portainer...${NC}"
    docker volume create portainer_data
    docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest

    echo -e "\n${GREEN}✔ Portainer instalado em: https://SEU-IP:9443${NC}"
    echo -e "${YELLOW}Instruções:${NC}"
    echo "1. Acesse o Portainer e crie um novo Stack."
    echo "2. Use o link do seu GitHub ($GIT_URL) para fazer o deploy automático do Flashp."
    echo "3. Recomendamos usar Nginx Proxy Manager no Docker para gerenciar domínios."
    ;;

  3)
    echo -e "\n${YELLOW}### Instalação Coolify ###${NC}"
    curl -fsSL https://get.coollabs.io/coolify/install.sh | bash
    echo -e "\n${GREEN}✔ Coolify instalado com sucesso!${NC}"
    echo "Acesse a interface web na porta 8000 para configurar o projeto Flashp via GitHub."
    ;;

  4)
    echo -e "\n${YELLOW}### Instalação Easypanel ###${NC}"
    curl -sSL https://get.easypanel.io | sh
    echo -e "\n${GREEN}✔ Easypanel instalado com sucesso!${NC}"
    echo "Acesse a interface web na porta 3000 (ou conforme indicado pelo Easypanel) para configurar."
    ;;

  5)
    exit 0
    ;;

  *)
    echo -e "${RED}Opção inválida.${NC}"
    ;;
esac
