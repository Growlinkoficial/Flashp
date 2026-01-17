# ⚡ Flashp - Sistema de Instalação Automatizado

**Versão 2.0.0** - Plataforma de Implantação Production-Ready

---

## 📖 Visão Geral

O Flashp fornece um sistema de instalação abrangente, de nível empresarial, com múltiplas opções de implantação, tratamento robusto de erros, rollback automático e capacidades completas de limpeza.

### Recursos Principais

- ✅ **4 Métodos de Implantação**: Bare Metal, Docker/Portainer, Coolify, Easypanel
- ✅ **Detecção Inteligente de Infraestrutura**: Detecta automaticamente componentes existentes
- ✅ **Suporte a Domínio/Subdomínio**: Configuração flexível de DNS com SSL
- ✅ **SSL/TLS Automático**: Integração com Let's Encrypt
- ✅ **Rollback em Falha**: Limpeza automática em erros
- ✅ **Logging Completo**: Logs detalhados de instalação
- ✅ **Verificações de Saúde**: Verificação pós-instalação
- ✅ **Operações Idempotentes**: Seguro para re-executar
- ✅ **Desinstalação Limpa**: Restauração completa do sistema

---

## 🚀 Início Rápido

### Pré-requisitos

- **SO**: Ubuntu 20.04+ ou Debian 11+
- **RAM**: 2GB mínimo (4GB recomendado)
- **Disco**: 10GB de espaço livre mínimo
- **Rede**: Conexão de internet estável
- **Acesso**: Privilégios root/sudo

### Instalação

```bash
# 1. Baixar o instalador
wget https://github.com/seuusuario/flashp/raw/main/flashp_install.sh
chmod +x flashp_install.sh

# 2. Executar instalação
sudo ./flashp_install.sh

# 3. Seguir os prompts interativos
```

---

## 📋 Métodos de Instalação

### 1️⃣ Bare Metal (Recomendado para Controle Total)

**Melhor para**: Performance máxima, acesso direto ao servidor

**Inclui**:
- Node.js 20 (via NVM)
- Gerenciador de processos PM2
- Reverse proxy Nginx
- SSL automático (se domínio configurado)

**Uso de Recursos**: ~500MB RAM, ~2GB disco

```bash
# Selecionar opção 1 no menu
# Fornecer URL do repositório Git
# Aplicação estará disponível em:
# - Com domínio: https://seudominio.com
# - Sem domínio: http://SEU_IP
```

---

### 2️⃣ Docker + Portainer

**Melhor para**: Gerenciamento de containers, atualizações fáceis

**Inclui**:
- Docker Engine
- Portainer CE (interface web)
- Orquestração de containers

**Uso de Recursos**: ~800MB RAM, ~3GB disco

**Dois cenários**:

**A. Portainer Não Detectado**:
- Instala Docker + Portainer
- Opcionalmente configura acesso por domínio
- Acesse o Portainer em `https://seudominio.com` ou `https://IP:9443`

**B. Portainer Já Instalado**:
- Mostra instruções de implantação
- Implantar via interface do Portainer: Stacks → Add Stack → Repository

---

### 3️⃣ Coolify

**Melhor para**: Experiência Platform-as-a-Service, múltiplas aplicações

**Inclui**:
- Plataforma PaaS completa
- Integração com GitHub
- Suporte a múltiplas apps
- Monitoramento integrado

**Uso de Recursos**: ~1.5GB RAM, ~5GB disco

```bash
# Acessar painel Coolify na porta 8000
# Criar Projeto → Adicionar Aplicação → Repositório Público
# Coolify gerencia build e implantação automaticamente
```

---

### 4️⃣ Easypanel

**Melhor para**: Iniciantes, implantação simples

**Inclui**:
- Painel amigável
- Implantação rápida
- Monitoramento básico

**Uso de Recursos**: ~600MB RAM, ~2GB disco

```bash
# Acessar painel na porta 3000
# Criar Projeto → Serviço → Git
# Configurar build e implantar
```

---

## 🌐 Configuração de Domínio

### Opção 1: Subdomínio (Recomendado)

```
Exemplo: app.exemplo.com

Configuração:
1. Criar registro A: app.exemplo.com → IP_DO_SEU_SERVIDOR
2. Aguardar propagação DNS (5-30 minutos)
3. Executar instalador e escolher "Subdomínio"
4. Entrada: Subdomínio = "app", Domínio = "exemplo.com"
5. Certificado SSL será gerado automaticamente
```

### Opção 2: Domínio Raiz

```
Exemplo: exemplo.com

Configuração:
1. Criar registro A: exemplo.com → IP_DO_SEU_SERVIDOR
2. Aguardar propagação DNS
3. Executar instalador e escolher "Apenas domínio raiz"
4. Entrada: Domínio = "exemplo.com"
5. Certificado SSL será gerado automaticamente
```

### Opção 3: Somente IP (Sem Domínio)

```
Nenhuma configuração DNS necessária
Acesso via: http://IP_DO_SEU_SERVIDOR
Sem SSL/HTTPS (somente HTTP)
Bom para testes/desenvolvimento
```

---

## 🔧 Pós-Instalação

### Verificar Instalação

```bash
# Verificar configuração de instalação
sudo cat /etc/flashp/install.conf

# Ver log de instalação
sudo cat /var/log/flashp/install_*.log

# Verificar status da aplicação (Bare Metal)
sudo -u flashp pm2 status

# Verificar status do Nginx
sudo systemctl status nginx

# Testar aplicação
curl http://localhost:3000
```

### Tarefas Comuns Pós-Instalação

**Acessar Aplicação**:
```bash
# Encontrar sua URL de acesso no log de instalação
sudo grep "URL de acesso" /var/log/flashp/install_*.log
```

**Atualizar Aplicação** (Bare Metal):
```bash
cd /opt/flashp/flashp
sudo -u flashp git pull
sudo -u flashp npm install
sudo -u flashp npm run build
sudo -u flashp pm2 restart flashp
```

**Ver Logs da Aplicação** (Bare Metal):
```bash
sudo -u flashp pm2 logs flashp
sudo -u flashp pm2 logs flashp --lines 100
```

**Reiniciar Aplicação** (Bare Metal):
```bash
sudo -u flashp pm2 restart flashp
```

**Configuração do Nginx**:
```bash
# Editar configuração
sudo nano /etc/nginx/sites-available/flashp

# Testar configuração
sudo nginx -t

# Recarregar Nginx
sudo systemctl reload nginx
```

---

## 🗑️ Desinstalação

### Remoção Completa

```bash
# Baixar desinstalador
wget https://github.com/seuusuario/flashp/raw/main/flashp_uninstall.sh
chmod +x flashp_uninstall.sh

# Executar desinstalador
sudo ./flashp_uninstall.sh

# Seguir os prompts:
# - Digitar 'DELETAR' para confirmar
# - Escolher criar backup (recomendado)
# - Opcionalmente remover Docker/Nginx
```

### O Que É Removido

- ✅ Arquivos da aplicação (`/opt/flashp`)
- ✅ Configuração (`/etc/flashp`)
- ✅ Usuário da aplicação (`flashp`)
- ✅ Processos PM2
- ✅ Configurações do Nginx
- ✅ Certificados SSL
- ✅ Containers Docker (Portainer/Coolify/Easypanel)
- ✅ Opcionalmente: logs, imagens Docker, Nginx

### Localização do Backup

Backups são armazenados em: `/var/backups/flashp_TIMESTAMP/`

---

## 🐛 Solução de Problemas

### Diagnóstico Rápido

```bash
# Script de verificação de saúde
curl -sSL https://raw.githubusercontent.com/seuusuario/flashp/main/health_check.sh | sudo bash

# Gerar relatório de diagnóstico
sudo bash -c 'cat > /tmp/diagnostic.sh << "EOF"
#!/bin/bash
echo "=== Diagnóstico Flashp ==="
echo "Config:" && cat /etc/flashp/install.conf
echo "PM2:" && sudo -u flashp pm2 status
echo "Nginx:" && systemctl status nginx --no-pager
echo "Portas:" && netstat -tuln | grep -E ":80|:443|:3000"
echo "Logs:" && tail -20 /var/log/flashp/install_*.log
EOF
chmod +x /tmp/diagnostic.sh
/tmp/diagnostic.sh'
```

### Problemas Comuns

| Problema | Solução |
|----------|---------|
| Porta já em uso | `sudo lsof -i :80` → parar serviço conflitante |
| Falha no certificado SSL | Verificar propagação DNS com `dig +short seudominio.com` |
| Aplicação não inicia | `sudo -u flashp pm2 logs flashp` → verificar erros |
| 502 Bad Gateway | `sudo -u flashp pm2 restart flashp` |
| Permissão negada | `sudo chown -R flashp:flashp /opt/flashp` |

**Guia completo de solução de problemas**: Veja `TROUBLESHOOTING.md`

---

## 📊 Arquitetura do Sistema

### Stack Bare Metal

```
Internet → Nginx (Porta 80/443)
         ↓
    Terminação SSL
         ↓
    Reverse Proxy
         ↓
    App Node.js (Porta 3000)
         ↓
    Gerenciador de Processos PM2
         ↓
    Lógica da Aplicação
```

### Stack Docker/Portainer

```
Internet → Nginx (Opcional)
         ↓
    Docker Engine
         ↓
    Container Portainer (9443)
         ↓
    Container Flashp (3000)
```

---

## 🔐 Considerações de Segurança

### Recursos de Segurança Implementados

- ✅ Usuário não-root para aplicação
- ✅ Criptografia SSL/TLS automática
- ✅ Integração Fail2ban (opcional)
- ✅ Configuração de firewall UFW
- ✅ Validação e sanitização de entrada
- ✅ Permissões seguras de log

### Hardening Adicional (Recomendado)

```bash
# Habilitar firewall UFW
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable

# Instalar fail2ban
sudo apt-get install fail2ban -y
sudo systemctl enable fail2ban

# Hardening SSH
sudo nano /etc/ssh/sshd_config
# Definir: PermitRootLogin no
# Definir: PasswordAuthentication no
sudo systemctl restart ssh

# Manter sistema atualizado
sudo apt-get update && sudo apt-get upgrade -y
```

---

## 📁 Localizações de Arquivos

| Caminho | Descrição |
|---------|-----------|
| `/opt/flashp/` | Diretório da aplicação |
| `/etc/flashp/install.conf` | Configuração de instalação |
| `/var/log/flashp/` | Logs de instalação e aplicação |
| `/etc/nginx/sites-available/flashp` | Configuração do Nginx |
| `/etc/systemd/system/pm2-flashp.service` | Serviço systemd do PM2 |
| `/var/backups/flashp_*/` | Backups de desinstalação |

---

## 🔄 Atualizações e Manutenção

### Atualizar Script

```bash
# Atualizar script do instalador
wget -O flashp_install.sh https://github.com/seuusuario/flashp/raw/main/flashp_install.sh
chmod +x flashp_install.sh

# Atualizar desinstalador
wget -O flashp_uninstall.sh https://github.com/seuusuario/flashp/raw/main/flashp_uninstall.sh
chmod +x flashp_uninstall.sh
```

### Monitoramento

```bash
# Monitorar aplicação (Bare Metal)
sudo -u flashp pm2 monit

# Verificar uso de recursos
htop

# Monitorar logs em tempo real
sudo -u flashp pm2 logs flashp --lines 0
sudo tail -f /var/log/nginx/access.log
```

---

## 🆘 Suporte

### Obtendo Ajuda

1. **Verificar Guia de Solução de Problemas**: `TROUBLESHOOTING.md`
2. **Gerar Relatório de Diagnóstico**: Veja seção de solução de problemas acima
3. **Issues no GitHub**: https://github.com/seuusuario/flashp/issues
4. **Fórum da Comunidade**: https://community.flashp.dev
5. **Suporte por Email**: support@flashp.dev

### Antes de Pedir Ajuda

Por favor, forneça:
- Log de instalação: `/var/log/flashp/install_*.log`
- Configuração de instalação: `/etc/flashp/install.conf`
- Logs da aplicação: `sudo -u flashp pm2 logs flashp --lines 50`
- Informações do sistema: `uname -a && lsb_release -a`

---

## 📜 Licença

Licença MIT - Veja arquivo LICENSE para detalhes

---

## 🙏 Créditos

- **Equipe Flashp** - Desenvolvimento principal
- **Contribuidores da Comunidade** - Relatórios de bugs e recursos
- **Projetos Open Source**: Node.js, Nginx, PM2, Docker, Portainer, Coolify, Easypanel

---

## 🗺️ Roadmap

- [ ] Suporte para Rocky Linux/AlmaLinux
- [ ] Backups automatizados com cron
- [ ] Implantação multi-instância
- [ ] Dashboard de monitoramento integrado
- [ ] Mecanismo de auto-atualização
- [ ] Opção de implantação Kubernetes

---

**Última Atualização**: 16 de Janeiro de 2026  
**Versão**: 2.0.0  
**Mantido por**: Equipe Flashp