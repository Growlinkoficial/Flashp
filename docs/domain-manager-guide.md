# 🌐 Guia de Uso - Flashp Domain Manager

**Versão:** 1.0.0  
**Para:** Gerenciar domínios de aplicações no Portainer

---

## 📖 O Que Este Script Faz?

Automatiza **TODO** o processo de configuração de domínio para aplicações no Portainer:

✅ Cria configuração do Nginx automaticamente  
✅ Gera certificado SSL (Let's Encrypt)  
✅ Verifica DNS  
✅ Testa configurações  
✅ Suporte a WebSocket  
✅ Remove domínios facilmente  

---

## 🚀 Instalação

```bash
# 1. Baixar o script
wget https://seu-repo.com/flashp_domain_manager.sh
chmod +x flashp_domain_manager.sh

# 2. Executar
sudo ./flashp_domain_manager.sh
```

---

## 📋 Passo a Passo Completo

### **Cenário:** Você tem uma aplicação no Portainer na porta 5000

---

### **1️⃣ Configurar DNS (Primeiro Passo SEMPRE)**

No seu provedor DNS (Cloudflare, Route53, etc):

```
Tipo: A
Nome: app
Valor: IP_DO_SEU_SERVIDOR
TTL: Auto ou 300

Resultado: app.seudominio.com → 45.123.456.789
```

**Aguarde 5-30 minutos para propagação**

Verificar propagação:
```bash
dig +short app.seudominio.com
# Deve retornar o IP do seu servidor
```

---

### **2️⃣ Executar o Domain Manager**

```bash
sudo ./flashp_domain_manager.sh
```

**Menu que aparece:**
```
╔═══════════════════════════════════════════════════════════╗
║        🌐 FLASHP DOMAIN MANAGER v1.0 🌐                  ║
╚═══════════════════════════════════════════════════════════╝

O que você deseja fazer?

  1) Adicionar novo domínio
  2) Listar domínios configurados
  3) Remover domínio
  4) Renovar certificado SSL
  5) Testar configuração do Nginx
  6) Sair

Opção: 
```

---

### **3️⃣ Adicionar Novo Domínio**

**Escolha opção 1**

#### **Pergunta 1: Domínio**
```
Digite o domínio (ex: app.seudominio.com): app.growlinklabs.com
```

#### **Pergunta 2: Porta**
```
Digite a porta da aplicação no Portainer (ex: 5000): 5000
```

#### **Pergunta 3: SSL**
```
Configurar SSL/HTTPS? (s/n) [s]: s
```

#### **Pergunta 4: Email (se SSL = sim)**
```
Digite seu email para o certificado SSL: admin@growlinklabs.com
```

#### **Pergunta 5: WebSocket (opcional)**
```
Esta aplicação usa WebSocket? (s/n) [n]: n
```
*Digite "s" se for app real-time (chat, notificações, etc)*

---

### **4️⃣ Confirmar**

O script mostra um resumo:
```
═══════════════════════════════════════════════════
Resumo da Configuração:
═══════════════════════════════════════════════════
Domínio: app.growlinklabs.com
Porta: 5000
SSL: Sim
WebSocket: Não
Email: admin@growlinklabs.com

Confirmar? (s/n): s
```

---

### **5️⃣ Aguardar Configuração Automática**

O script faz automaticamente:

1. ✓ Verifica DNS
2. ✓ Cria configuração Nginx
3. ✓ Ativa o site
4. ✓ Testa configuração
5. ✓ Gera certificado SSL
6. ✓ Configura redirecionamento HTTP→HTTPS
7. ✓ Recarrega Nginx

---

### **6️⃣ Pronto! 🎉**

```
═══════════════════════════════════════════════════
  Domínio configurado com sucesso!
  Acesso: https://app.growlinklabs.com
  Log: /var/log/flashp/domain_20260117_143022.log
═══════════════════════════════════════════════════
```

**Acesse:** `https://app.growlinklabs.com`

---

## 🎯 Exemplo Completo Real

### **Aplicação WordPress no Portainer**

**1. No Portainer:**
```
Containers → Add Container
Name: wordpress-site
Image: wordpress:latest
Port mapping: 8080 → 80
```

**2. DNS:**
```
blog.growlinklabs.com → 45.123.456.789
```

**3. Domain Manager:**
```bash
sudo ./flashp_domain_manager.sh

# Opção 1
# Domínio: blog.growlinklabs.com
# Porta: 8080
# SSL: s
# Email: admin@growlinklabs.com
# WebSocket: n
```

**4. Resultado:**
```
https://blog.growlinklabs.com → Seu WordPress
```

---

## 📊 Casos de Uso Comuns

### **Caso 1: API Node.js**
```
Container: api-backend
Porta: 3000
Domínio: api.seudominio.com
SSL: Sim
WebSocket: Não
```

### **Caso 2: Frontend React**
```
Container: react-app
Porta: 3001
Domínio: app.seudominio.com
SSL: Sim
WebSocket: Não
```

### **Caso 3: Chat Real-Time**
```
Container: chat-app
Porta: 4000
Domínio: chat.seudominio.com
SSL: Sim
WebSocket: Sim ← IMPORTANTE!
```

### **Caso 4: Painel Admin**
```
Container: admin-panel
Porta: 5000
Domínio: admin.seudominio.com
SSL: Sim
WebSocket: Não
```

---

## 🔧 Gerenciamento de Domínios

### **Listar Domínios Configurados**
```bash
sudo ./flashp_domain_manager.sh
# Opção 2
```

**Saída:**
```
═══════════════════════════════════════════════════
         DOMÍNIOS CONFIGURADOS                     
═══════════════════════════════════════════════════

Domínio: app.growlinklabs.com
Porta: 5000
SSL: HTTPS ✓
Config: app-growlinklabs-com
---
Domínio: api.growlinklabs.com
Porta: 3000
SSL: HTTPS ✓
Config: api-growlinklabs-com
---

Total: 2 domínio(s) configurado(s)
```

---

### **Remover Domínio**
```bash
sudo ./flashp_domain_manager.sh
# Opção 3
# Digite: app.growlinklabs.com
```

Remove:
- ✓ Configuração Nginx
- ✓ Certificado SSL
- ✓ Links simbólicos

---

### **Renovar Certificados SSL**
```bash
sudo ./flashp_domain_manager.sh
# Opção 4
```

Renova todos os certificados que estão próximos do vencimento.

**Nota:** Certbot já faz isso automaticamente! Esta opção é para forçar renovação ou troubleshooting.

---

## 🚨 Solução de Problemas

### **Erro: "Domínio não resolve"**

**Causa:** DNS não configurado ou não propagado

**Solução:**
```bash
# Verificar DNS
dig +short app.seudominio.com

# Se não retornar IP:
1. Verificar configuração no provedor DNS
2. Aguardar propagação (até 48h, geralmente 5-30min)
3. Tentar DNS público: 8.8.8.8
```

---

### **Erro: "Porta não está em uso"**

**Causa:** Container não está rodando

**Solução:**
```bash
# Verificar containers
docker ps | grep seu-container

# Verificar porta específica
sudo lsof -i :5000

# Se não estiver rodando:
1. Iniciar container no Portainer
2. Verificar port mapping
```

---

### **Erro: "SSL falhou"**

**Causa:** DNS não propagado ou firewall bloqueando

**Solução:**
```bash
# 1. Verificar DNS propagado
dig +short app.seudominio.com

# 2. Verificar firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 3. Tentar manualmente
sudo certbot --nginx -d app.seudominio.com
```

---

### **Erro: "502 Bad Gateway"**

**Causa:** Container parado ou porta errada

**Solução:**
```bash
# 1. Verificar container rodando
docker ps

# 2. Verificar porta correta
docker port nome-do-container

# 3. Testar porta localmente
curl http://localhost:5000
```

---

## 📝 Logs e Debug

### **Localização dos Logs**
```bash
# Logs do Domain Manager
ls -lh /var/log/flashp/domain_*.log

# Log mais recente
sudo tail -100 /var/log/flashp/domain_*.log

# Logs do Nginx por domínio
sudo tail -50 /var/log/nginx/app-seudominio-com-access.log
sudo tail -50 /var/log/nginx/app-seudominio-com-error.log
```

### **Testar Nginx**
```bash
# Testar sintaxe
sudo nginx -t

# Ver status
sudo systemctl status nginx

# Ver configuração específica
cat /etc/nginx/sites-available/app-seudominio-com
```

---

## 🎓 Boas Práticas

### **1. Use Subdomínios Diferentes**
```
✓ app.seudominio.com
✓ api.seudominio.com
✓ admin.seudominio.com

✗ seudominio.com/app
✗ seudominio.com/api
```

### **2. Configure DNS Antes**
Sempre configure o DNS **ANTES** de executar o script.

### **3. Use SSL Sempre**
Exceto para:
- Ambiente de desenvolvimento local
- Testes internos
- Acesso apenas por IP interno

### **4. Documente Suas Portas**
```
app.seudominio.com    → :5000 (Frontend)
api.seudominio.com    → :3000 (Backend)
admin.seudominio.com  → :4000 (Admin)
db.seudominio.com     → :5432 (PostgreSQL Admin)
```

### **5. Use WebSocket Quando Necessário**
Ative WebSocket para:
- ✓ Chats em tempo real
- ✓ Notificações push
- ✓ Dashboards ao vivo
- ✓ Colaboração em tempo real

---

## 🔄 Workflow Recomendado

```
1. Criar container no Portainer
   ↓
2. Testar via IP:porta (http://IP:5000)
   ↓
3. Configurar DNS (app.dominio.com → IP)
   ↓
4. Aguardar propagação DNS (5-30min)
   ↓
5. Executar Domain Manager
   ↓
6. Acessar via domínio (https://app.dominio.com)
   ↓
7. Sucesso! 🎉
```

---

## 📞 Suporte

### **Logs para Compartilhar ao Pedir Ajuda**
```bash
# 1. Log do Domain Manager
sudo cat /var/log/flashp/domain_*.log

# 2. Teste do Nginx
sudo nginx -t

# 3. Status do Nginx
sudo systemctl status nginx

# 4. Verificação DNS
dig +short seu-dominio.com

# 5. Portas em uso
sudo netstat -tuln | grep LISTEN
```

---

## ✨ Vantagens vs Processo Manual

| Aspecto | Manual | Com Script |
|---------|--------|------------|
| Tempo | ~15 minutos | ~2 minutos |
| Passos | 5-6 comandos | Interativo guiado |
| Erros | Comum | Validação automática |
| SSL | Configurar manualmente | Automático |
| WebSocket | Config adicional | Pergunta simples |
| Logs | Nenhum | Centralizado |
| Remoção | 3-4 comandos | 1 opção do menu |

---

**Última Atualização:** 17 de Janeiro de 2026  
**Versão:** 1.0.0  
**Compatível com:** Portainer CE/EE