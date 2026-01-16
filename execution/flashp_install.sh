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

echo -e "\n${BLUE}Configuração Global de Domínio:${NC}"
echo "Você já tem um domínio apontado para este servidor?"
echo "1) Sim (Usar Domínio + SSL/HTTPS)"
echo "2) Não (Usar apenas IP via porta 80)"
read -p "Opção: " GLOBAL_DOMAIN_OPT

if [ "$GLOBAL_DOMAIN_OPT" == "1" ]; then
    read -p "Digite seu domínio (ex: flashp.meudominio.com): " DOMAIN
    HAS_DOMAIN=1
else
    HAS_DOMAIN=0
    echo -e "${YELLOW}Aviso: Sem domínio, o acesso será via IP sem criptografia (HTTP).${NC}"
fi

# Variáveis de detecção
HAS_NGINX=0
HAS_DOCKER=0
HAS_PORTAINER=0
HAS_COOLIFY=0
HAS_EASYPANEL=0

check_infrastructure() {
    echo -e "${BLUE}Auditoria de Infraestrutura...${NC}"
    
    # Nginx
    if command -v nginx &> /dev/null; then HAS_NGINX=1; fi
    
    # Docker
    if command -v docker &> /dev/null; then 
        HAS_DOCKER=1
        # Portainer
        if [ "$(docker ps -a -q -f name=portainer)" ]; then HAS_PORTAINER=1; fi
        # Easypanel
        if [ "$(docker ps -a -q -f name=easypanel)" ]; then HAS_EASYPANEL=1; fi
    fi
    
    # Coolify (Caminho padrão de dados)
    if [ -d "/data/coolify" ]; then HAS_COOLIFY=1; fi
    # Easypanel (Caminho padrão de config caso container mude nome)
    if [ -d "/etc/easypanel" ]; then HAS_EASYPANEL=1; fi
}

check_infrastructure

echo -e "\n${BLUE}Escolha o método de instalação:${NC}"
[ $HAS_NGINX -eq 1 ] && TAG_NGINX="${GREEN}[DETECTADO]${NC}" || TAG_NGINX=""
[ $HAS_PORTAINER -eq 1 ] && TAG_PORTAINER="${GREEN}[DETECTADO]${NC}" || TAG_PORTAINER=""
[ $HAS_COOLIFY -eq 1 ] && TAG_COOLIFY="${GREEN}[DETECTADO]${NC}" || TAG_COOLIFY=""
[ $HAS_EASYPANEL -eq 1 ] && TAG_EASYPANEL="${GREEN}[DETECTADO]${NC}" || TAG_EASYPANEL=""

echo -e "1) Bare Metal (Node.js + PM2 + Nginx) $TAG_NGINX"
echo -e "2) Docker + Portainer $TAG_PORTAINER"
echo -e "3) Coolify (Ferramenta Completa) $TAG_COOLIFY"
echo -e "4) Easypanel (Painel Simples) $TAG_EASYPANEL"
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

    if [ $HAS_DOMAIN -eq 1 ]; then
        CONF_FILE="flashp"
        SERVER_NAME="$DOMAIN"
    else
        CONF_FILE="flashp_ip"
        SERVER_NAME="_"
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
    if [ $HAS_DOMAIN -eq 1 ]; then
        echo -e "\n${YELLOW}Configurando Certificado SSL...${NC}"
        apt install certbot python3-certbot-nginx -y
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email webmaster@$DOMAIN || echo -e "${RED}Erro ao gerar SSL. Verifique o apontamento.${NC}"
        FINAL_URL="https://$DOMAIN"
    else
        FINAL_URL="http://$(hostname -I | awk '{print $1}')"
    fi

    echo -e "\n${GREEN}✔ Flashp instalado com sucesso em: $FINAL_URL${NC}"
    ;;

  2)
    echo -e "\n${YELLOW}### Opção Portainer ###${NC}"
    if [ $HAS_PORTAINER -eq 1 ]; then
        echo -e "${GREEN}Portainer detectado!${NC}"
        echo -e "Deseja gerar o arquivo 'docker-compose.yml' otimizado para o Flashp?"
        read -p "(s/n): " GEN_COMPOSE
        if [ "$GEN_COMPOSE" == "s" ]; then
            cp docker-compose.example.yml docker-compose.yml
            echo -e "${GREEN}✔ Arquivo 'docker-compose.yml' criado a partir do exemplo!${NC}"
            echo -e "${BLUE}Instruções:${NC}"
            echo "1. No Portainer, vá em Stacks > Add Stack."
            echo "2. Use o conteúdo do arquivo localizado em: $(pwd)/docker-compose.yml"
        fi
    else
        # Docker
        if [ $HAS_DOCKER -eq 0 ]; then
            echo -e "${BLUE}Instalando Docker...${NC}"
            curl -fsSL https://get.docker.com | sh
        fi
        # Portainer
        echo -e "${BLUE}Instalando Portainer...${NC}"
        docker volume create portainer_data
        docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
        echo -e "\n${GREEN}✔ Portainer instalado em: https://SEU-IP:9443${NC}"
    fi
    ;;

  3)
    echo -e "\n${YELLOW}### Opção Coolify ###${NC}"
    if [ $HAS_COOLIFY -eq 1 ]; then
        echo -e "${GREEN}Coolify detectado!${NC}"
        echo -e "${BLUE}Para instalar o Flashp no Coolify:${NC}"
        echo "1. Acesse o painel Coolify (porta 8000)."
        echo "2. Crie uma nova 'Application' > 'GitHub Repository'."
        echo "3. Configurações recomendadas: Port 3000 | Nixpack/Build Pack Auto."
    else
        echo -e "${BLUE}Instalando Coolify...${NC}"
        curl -fsSL https://get.coollabs.io/coolify/install.sh | bash
        echo -e "\n${GREEN}✔ Coolify instalado!${NC}"
    fi
    ;;

  4)
    echo -e "\n${YELLOW}### Opção Easypanel ###${NC}"
    if [ $HAS_EASYPANEL -eq 1 ]; then
        echo -e "${GREEN}Easypanel detectado!${NC}"
        echo -e "${BLUE}Para instalar o Flashp no Easypanel:${NC}"
        echo "1. Acesse o Easypanel (porta 3000)."
        echo "2. Crie um novo 'Project' > 'Service' > 'Git'."
        echo "3. Repositório: $GIT_URL"
        echo "4. Build: Node.js | Port: 3000"
    else
        echo -e "${BLUE}Instalando Easypanel...${NC}"
        curl -sSL https://get.easypanel.io | sh
        echo -e "\n${GREEN}✔ Easypanel instalado!${NC}"
    fi
    ;;

  5)
    exit 0
    ;;

  *)
    echo -e "${RED}Opção inválida.${NC}"
    ;;
esac
