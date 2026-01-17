# 🔧 Guia de Solução de Problemas Flashp

**Versão:** 2.0.0  
**Última Atualização:** Janeiro 2026

---

## 📋 Índice

1. [Diagnóstico Rápido](#diagnóstico-rápido)
2. [Problemas de Instalação](#problemas-de-instalação)
3. [Problemas de SSL/Certificado](#problemas-de-sslcertificado)
4. [Problemas da Aplicação](#problemas-da-aplicação)
5. [Problemas Docker/Container](#problemas-dockercontainer)
6. [Problemas do Nginx](#problemas-do-nginx)
7. [Problemas de Performance](#problemas-de-performance)
8. [Análise de Logs](#análise-de-logs)
9. [Procedimentos de Recuperação](#procedimentos-de-recuperação)

---

## 🔍 Diagnóstico Rápido

### Verificar Status da Instalação

```bash
# Ver configuração de instalação
sudo cat /etc/flashp/install.conf

# Verificar logs de instalação
sudo tail -100 /var/log/flashp/install_*.log

# Verificar se os serviços estão rodando
sudo systemctl status nginx
sudo systemctl status pm2-flashp
docker ps | grep -E "portainer|coolify|easypanel"
```

### Script de Verificação de Saúde

```bash
#!/bin/bash
# Verificação rápida de saúde

echo "=== Verificação de Saúde Flashp ==="

# Verificar usuário da aplicação
if id flashp &>/dev/null; then
    echo "✓ Usuário da aplicação existe"
else
    echo "✗ Usuário da aplicação ausente"
fi

# Verificar diretório da aplicação
if [ -d "/opt/flashp" ]; then
    echo "✓ Diretório da aplicação existe"
else
    echo "✗ Diretório da aplicação ausente"
fi

# Verificar se a app está rodando
if curl -sf http://localhost:3000 > /dev/null 2>&1; then
    echo "✓ Aplicação respondendo na porta 3000"
else
    echo "✗ Aplicação não está respondendo"
fi

# Verificar Nginx
if systemctl is-active --quiet nginx; then
    echo "✓ Nginx está rodando"
else
    echo "✗ Nginx não está rodando"
fi

# Verificar portas
netstat -tuln | grep -E ":80|:443|:3000" || echo "⚠ Portas esperadas não estão ouvindo"
```

---

## 🚨 Problemas de Instalação

### Problema: Erro "Permissão Negada"

**Sintomas:**
```
Permissão negada ao tentar conectar ao daemon Docker
```

**Solução:**
```bash
# Adicionar usuário atual ao grupo docker
sudo usermod -aG docker $USER

# Aplicar mudanças de grupo (logout/login ou use)
newgrp docker

# Verificar
docker ps
```

---

### Problema: "Porta Já em Uso"

**Sintomas:**
```
Erro: Porta 80 já está em uso
Erro: Porta 3000 já está em uso
```

**Solução:**
```bash
# Descobrir o que está usando a porta
sudo lsof -i :80
sudo netstat -tuln | grep :80

# Parar o serviço conflitante
sudo systemctl stop apache2  # se Apache estiver rodando
sudo systemctl stop nginx    # se instância antiga do Nginx

# Matar processo específico
sudo kill -9 <PID>

# Re-executar instalação
sudo ./flashp_install.sh
```

---

### Problema: "Falha no Git Clone"

**Sintomas:**
```
fatal: repositório não encontrado
fatal: não foi possível ler o Nome de Usuário
```

**Soluções:**

**1. Verificar URL do repositório:**
```bash
# Formato correto
https://github.com/usuario/flashp.git

# Não isso
github.com/usuario/flashp
```

**2. Para repositórios privados:**
```bash
# Use URL SSH
git@github.com:usuario/flashp.git

# Ou use token de acesso pessoal
https://TOKEN@github.com/usuario/flashp.git
```

**3. Verificar conectividade de rede:**
```bash
ping github.com
curl -I https://github.com
```

---

### Problema: "Falha no npm install"

**Sintomas:**
```
npm ERR! code EINTEGRITY
npm ERR! falha na requisição de rede
```

**Solução:**
```bash
# Limpar cache do npm
sudo -u flashp npm cache clean --force

# Usar registro diferente
sudo -u flashp npm install --registry https://registry.npmjs.org

# Se problema de espaço em disco
df -h
# Limpar se necessário
sudo apt-get clean
sudo apt-get autoremove
```

---

### Problema: "RAM/Espaço em Disco Insuficiente"

**Sintomas:**
```
RAM disponível (1024MB) está abaixo do recomendado (2048MB)
Espaço em disco insuficiente
```

**Soluções:**

**Verificar recursos:**
```bash
# Verificar RAM
free -h

# Verificar disco
df -h

# Verificar o que está usando espaço
du -sh /* | sort -h
```

**Liberar espaço:**
```bash
# Limpar cache de pacotes
sudo apt-get clean
sudo apt-get autoremove

# Limpar Docker (se instalado)
docker system prune -af

# Remover logs antigos
sudo journalctl --vacuum-time=7d
```

---

## 🔒 Problemas de SSL/Certificado

### Problema: "Falha na Geração de Certificado SSL"

**Sintomas:**
```
Erro: Certbot falhou ao obter certificado
Desafio falhou para o domínio
```

**Soluções:**

**1. Verificar DNS:**
```bash
# Verificar se o domínio aponta para o servidor
dig +short seudominio.com

# Deve corresponder ao IP do servidor
hostname -I | awk '{print $1}'
```

**2. Verificar propagação DNS:**
```bash
# Usar verificador DNS externo
nslookup seudominio.com 8.8.8.8

# Aguardar propagação (pode levar até 48 horas)
```

**3. Verificar firewall:**
```bash
# Permitir HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# Verificar
sudo ufw status
```

**4. Renovação manual de certificado:**
```bash
# Testar renovação
sudo certbot renew --dry-run

# Forçar renovação
sudo certbot renew --force-renewal

# Verificar certificado
sudo certbot certificates
```

---

### Problema: "Aviso de Conteúdo Misto (HTTP/HTTPS)"

**Sintomas:**
- Navegador mostra aviso "Não Seguro"
- Alguns recursos não carregam

**Solução:**
```bash
# Verificar configuração SSL do Nginx
sudo nano /etc/nginx/sites-available/flashp

# Garantir que estas linhas existam:
# listen 443 ssl;
# ssl_certificate /etc/letsencrypt/live/seudominio/fullchain.pem;
# ssl_certificate_key /etc/letsencrypt/live/seudominio/privkey.pem;

# Forçar redirecionamento HTTPS
server {
    listen 80;
    server_name seudominio.com;
    return 301 https://$server_name$request_uri;
}

# Testar e recarregar
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🖥️ Problemas da Aplicação

### Problema: "Aplicação Não Inicia"

**Sintomas:**
```
Processo PM2 trava imediatamente
Aplicação sai com código 1
```

**Passos de Diagnóstico:**

**1. Verificar status do PM2:**
```bash
sudo -u flashp pm2 status
sudo -u flashp pm2 logs flashp --lines 100
```

**2. Verificar versão do Node.js:**
```bash
sudo -u flashp node --version
# Deve ser v20.x.x

# Se versão errada
sudo -u flashp nvm use 20
```

**3. Verificar variáveis de ambiente:**
```bash
sudo -u flashp pm2 env flashp
```

**4. Inicialização manual para debug:**
```bash
# Mudar para usuário da app
sudo -u flashp bash

# Navegar para a app
cd /opt/flashp/flashp

# Iniciar manualmente
npm start

# Verificar erros
```

**5. Verificar dependências:**
```bash
cd /opt/flashp/flashp
sudo -u flashp npm install
sudo -u flashp npm run build
```

---

### Problema: "Aplicação Rodando mas Não Acessível"

**Sintomas:**
- PM2 mostra app rodando
- Não consegue acessar via navegador

**Solução:**

**1. Testar conexão local:**
```bash
curl http://localhost:3000
# Deve retornar HTML

# Se conexão recusada
sudo -u flashp netstat -tuln | grep 3000
```

**2. Verificar proxy do Nginx:**
```bash
# Testar configuração do Nginx
sudo nginx -t

# Verificar log de erro do Nginx
sudo tail -50 /var/log/nginx/error.log

# Verificar proxy_pass
sudo cat /etc/nginx/sites-available/flashp | grep proxy_pass
# Deve ser: proxy_pass http://localhost:3000;
```

**3. Verificar firewall:**
```bash
sudo ufw status
sudo ufw allow 'Nginx Full'
```

---

### Problema: "502 Bad Gateway"

**Sintomas:**
- Nginx mostra erro 502
- Aplicação pode estar parada

**Soluções:**

**1. Verificar se a app está rodando:**
```bash
sudo -u flashp pm2 status
# Se parada
sudo -u flashp pm2 restart flashp
```

**2. Verificar vinculação de porta:**
```bash
sudo lsof -i :3000
# Deve mostrar processo Node.js
```

**3. Aumentar timeout:**
```bash
sudo nano /etc/nginx/sites-available/flashp

# Adicionar dentro do bloco location:
proxy_connect_timeout 600;
proxy_send_timeout 600;
proxy_read_timeout 600;
send_timeout 600;

sudo systemctl reload nginx
```

---

## 🐳 Problemas Docker/Container

### Problema: "Daemon Docker Não Está Rodando"

**Sintomas:**
```
Não é possível conectar ao daemon Docker
O daemon docker está rodando?
```

**Solução:**
```bash
# Iniciar Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verificar status
sudo systemctl status docker

# Se ainda falhar, reinstalar
curl -fsSL https://get.docker.com | sh
```

---

### Problema: "Container do Portainer Não Inicia"

**Sintomas:**
```
Resposta de erro do daemon: Conflito
porta já está alocada
```

**Soluções:**

**1. Verificar containers existentes:**
```bash
docker ps -a | grep portainer

# Remover container antigo
docker rm -f portainer
```

**2. Verificar conflitos de porta:**
```bash
sudo netstat -tuln | grep -E ":9443|:8000"

# Matar processo conflitante
sudo lsof -ti:9443 | xargs kill -9
```

**3. Recriar container:**
```bash
docker volume create portainer_data

docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

---

### Problema: "Docker Sem Espaço"

**Sintomas:**
```
sem espaço no dispositivo
falha ao criar shim
```

**Solução:**
```bash
# Verificar uso de disco do Docker
docker system df

# Limpar
docker system prune -af --volumes

# Remover imagens não usadas
docker image prune -af

# Verificar espaço disponível
df -h
```

---

## 🌐 Problemas do Nginx

### Problema: "Teste de Configuração do Nginx Falhou"

**Sintomas:**
```
nginx: [emerg] diretiva desconhecida
nginx: teste do arquivo de configuração /etc/nginx/nginx.conf falhou
```

**Solução:**
```bash
# Verificar localização do erro de sintaxe
sudo nginx -t

# Problemas comuns:
# - Ponto e vírgula faltando
# - Erro de digitação no nome da diretiva
# - Chave de fechamento } faltando

# Restaurar padrão se quebrado
sudo cp /etc/nginx/sites-available/flashp /tmp/backup
sudo nano /etc/nginx/sites-available/flashp

# Testar novamente
sudo nginx -t
```

---

### Problema: "Nginx Não Reinicia"

**Sintomas:**
```
Job para nginx.service falhou
```

**Solução:**
```bash
# Verificar erro detalhado
sudo systemctl status nginx.service -l

# Verificar se outro processo está usando a porta 80
sudo lsof -i :80

# Matar processo conflitante
sudo systemctl stop apache2

# Limpar arquivo PID antigo se existir
sudo rm -f /var/run/nginx.pid

# Reiniciar
sudo systemctl start nginx
```

---

## 📊 Problemas de Performance

### Problema: "Tempos de Resposta Lentos"

**Diagnóstico:**
```bash
# Verificar uso de CPU
top -u flashp

# Verificar memória
free -h

# Verificar I/O de disco
iostat -x 1 5

# Verificar logs da aplicação
sudo -u flashp pm2 logs flashp --lines 200
```

**Soluções:**

**1. Aumentar instâncias PM2:**
```bash
sudo -u flashp pm2 delete flashp
sudo -u flashp pm2 start npm --name flashp -i max -- start
sudo -u flashp pm2 save
```

**2. Habilitar cache do Nginx:**
```bash
sudo nano /etc/nginx/sites-available/flashp

# Adicionar dentro do bloco http:
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=flashp_cache:10m max_size=100m;

# Adicionar dentro do bloco location:
proxy_cache flashp_cache;
proxy_cache_valid 200 60m;
proxy_cache_use_stale error timeout http_500 http_502 http_503;

sudo systemctl reload nginx
```

**3. Otimizar Node.js:**
```bash
# Definir limite de memória do Node
sudo -u flashp pm2 delete flashp
sudo -u flashp pm2 start npm --name flashp --node-args="--max-old-space-size=2048" -- start
```

---

## 📝 Análise de Logs

### Visualizar Todos os Logs

```bash
# Logs de instalação
sudo ls -lh /var/log/flashp/

# Ver log específico
sudo cat /var/log/flashp/install_AAAAMMDD_HHMMSS.log

# Logs da aplicação (PM2)
sudo -u flashp pm2 logs flashp

# Log de acesso do Nginx
sudo tail -100 /var/log/nginx/access.log

# Log de erro do Nginx
sudo tail -100 /var/log/nginx/error.log

# Log do sistema
sudo journalctl -u nginx -n 100
sudo journalctl -u pm2-flashp -n 100
```

### Padrões Comuns de Log

**Conexão Recusada:**
```
connect() falhou (111: Conexão recusada) ao conectar ao upstream
```
→ Aplicação não está rodando na porta 3000

**Timeout:**
```
upstream expirou (110: Tempo limite de conexão excedido)
```
→ Aplicação muito lenta, aumentar timeout

**Permissão Negada:**
```
open() "/opt/flashp" falhou (13: Permissão negada)
```
→ Corrigir permissões: `sudo chown -R flashp:flashp /opt/flashp`

---

## 🔄 Procedimentos de Recuperação

### Reset Completo da Aplicação

```bash
# Parar aplicação
sudo -u flashp pm2 delete flashp

# Remover diretório da aplicação
sudo rm -rf /opt/flashp/flashp

# Re-clonar
sudo -u flashp git clone SUA_URL_GIT /opt/flashp/flashp

# Reinstalar
cd /opt/flashp/flashp
sudo -u flashp npm install
sudo -u flashp npm run build

# Reiniciar
sudo -u flashp pm2 start npm --name flashp -- start
sudo -u flashp pm2 save
```

---

### Restaurar do Backup

```bash
# Listar backups disponíveis
ls -lh /var/backups/flashp_*

# Restaurar backup específico
sudo tar -xzf /var/backups/flashp_20260116_123456/flashp_app.tar.gz -C /

# Restaurar configuração
sudo cp /var/backups/flashp_20260116_123456/install.conf /etc/flashp/

# Reiniciar serviços
sudo systemctl restart nginx
sudo -u flashp pm2 resurrect
```

---

### Desinstalação e Reinstalação de Emergência

```bash
# 1. Executar desinstalador
sudo ./flashp_uninstall.sh

# 2. Verificar limpeza
sudo rm -rf /opt/flashp /etc/flashp
sudo userdel -r flashp 2>/dev/null || true

# 3. Reinstalar
sudo ./flashp_install.sh
```

---

## 🆘 Obtendo Ajuda

### Informações para Coletar

Ao pedir ajuda, forneça:

```bash
# 1. Informações do sistema
uname -a
lsb_release -a

# 2. Configuração de instalação
sudo cat /etc/flashp/install.conf

# 3. Logs recentes (últimas 50 linhas)
sudo tail -50 /var/log/flashp/install_*.log
sudo -u flashp pm2 logs flashp --lines 50 --nostream

# 4. Status do serviço
sudo systemctl status nginx
sudo -u flashp pm2 status

# 5. Status da rede
curl -I http://localhost:3000
sudo netstat -tuln | grep -E ":80|:443|:3000"
```

### Criar Relatório de Diagnóstico

```bash
#!/bin/bash
# Gerar relatório de diagnóstico

REPORT_FILE="flashp_diagnostico_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "=== RELATÓRIO DE DIAGNÓSTICO FLASHP ==="
    echo "Gerado: $(date)"
    echo
    
    echo "--- Informações do Sistema ---"
    uname -a
    lsb_release -a
    echo
    
    echo "--- Configuração de Instalação ---"
    cat /etc/flashp/install.conf 2>/dev/null || echo "Nenhuma configuração encontrada"
    echo
    
    echo "--- Status do Serviço ---"
    systemctl status nginx --no-pager
    sudo -u flashp pm2 status
    echo
    
    echo "--- Status da Porta ---"
    netstat -tuln | grep -E ":80|:443|:3000"
    echo
    
    echo "--- Logs Recentes ---"
    tail -50 /var/log/flashp/install_*.log 2>/dev/null
    echo
    
    echo "--- Teste do Nginx ---"
    nginx -t 2>&1
    echo
    
} > "$REPORT_FILE"

echo "Relatório salvo em: $REPORT_FILE"
```

---

## 📚 Recursos Adicionais

- **Documentação Oficial:** https://flashp.dev/docs
- **Issues no GitHub:** https://github.com/flashp/flashp/issues
- **Fórum da Comunidade:** https://community.flashp.dev
- **Suporte por Email:** support@flashp.dev

---

**Última Atualização:** 16 de Janeiro de 2026  
**Mantenedor:** Equipe Flashp