# ⚡ Flashp - Image Converter

O **Flashp** é um conversor de imagens de alta performance e ultra-privado, focado na conversão de diversos formatos para **WebP** diretamente no navegador do usuário.

## ✨ Principais Características
- **Privacidade Total**: Suas imagens nunca saem do seu navegador. Todo o processamento é feito localmente via Canvas API.
- **Performance Premium**: Interface moderna, minimalista e rápida.
- **Comparativo Inteligente**: Visualize o tamanho original vs. convertido e veja a economia de espaço em tempo real.
- **Design Monocromático**: Estética elegante em branco e preto com detalhes em verde profundo.
- **Rótulos Dinâmicos**: A interface se adapta se você está processando um único arquivo ou múltiplos.

## � Arquitetura do Projeto
```text
.
├── directives/          # SOPs e regras de desenvolvimento
├── execution/           # Scripts de deploy e utilitários Python/Bash
├── public/              # Ativos estáticos (ícones, logos)
├── src/
│   ├── app/            # Rotas e estilos globais (Next.js App Router)
│   ├── components/     # Componentes React (Converter.tsx é o coração do app)
├── .tmp/                # Logs de execução e logs de decisão
├── README.md            # Documentação principal
└── vps_deployment_guide.md # Guia detalhado de deploy manual
```

## �🚀 Formatos Suportados
- PNG, JPEG, JPG, BMP, TIFF, GIF para **WebP**.

## 🛠️ Tecnologias
- [Next.js](https://nextjs.org/) (App Router)
- React
- Canvas API
- Vanilla CSS (Glassmorphism & Gradients)

## 📦 Como rodar localmente

1. Clone o repositório:
```bash
git clone https://github.com/Growlinkoficial/Flashp.git
```

2. Instale as dependências:
```bash
npm install
```

3. Inicie o servidor de desenvolvimento:
```bash
npm run dev
```

4. Acesse em `http://localhost:3000`.

## 🛠️ Instalação Automatizada (v2.0)

O Flashp possui um sistema de instalação completo e profissional (v2.0.0) que automatiza o deploy em diversos ambientes.

### 📋 Métodos Suportados
- **Bare Metal**: Node.js 20 + PM2 + Nginx + SSL.
- **Docker + Portainer**: Gestão via containers com interface web.
- **Coolify**: Plataforma PaaS completa.
- **Easypanel**: Painel de gerenciamento simplificado.

### 🚀 Como Instalar
Para iniciar a instalação na sua VPS (Ubuntu 20.04+ ou Debian 11+), execute o script mestre:

```bash
# Baixar e executar o instalador
curl -sSL https://raw.githubusercontent.com/Growlinkoficial/Flashp/main/execution/flashp_install.sh | sudo bash
```

### 🧹 Desinstalação
Caso precise remover o sistema completamente:
```bash
curl -sSL https://raw.githubusercontent.com/Growlinkoficial/Flashp/main/execution/flashp_uninstall.sh | sudo bash
```

## 🔧 Estrutura de Documentação
- [Guia de Instalação](Atualização recente/Installation_System.md) - Detalhes sobre cada método.
- [Solução de Problemas](Atualização recente/Troubleshooting.md) - Guia completo para resolver erros comuns.
- [Guia de Agentes](AGENTS_V1.0.md) - Instruções para IAs trabalhando no projeto.

## 📁 Localização de Arquivos (Produção)
- **App**: `/opt/flashp/`
- **Config**: `/etc/flashp/install.conf`
- **Logs**: `/var/log/flashp/`

---
Desenvolvido com foco em velocidade e privacidade. ⚡
