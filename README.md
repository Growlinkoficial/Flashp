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
git clone https://github.com/seu-usuario/flashp.git
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

## 🛠️ Instalação Automatizada (VPS)

Para implantar o Flashp em produção de forma rápida e segura, utilize o nosso script de automação. Ele suporta instalação direta (Bare Metal), Docker/Portainer, Coolify e Easypanel.

### Requisitos
- VPS rodando Ubuntu 22.04+ ou Debian 11+.
- Acesso root (sudo).
- Domínio apontado para o IP da VPS (para SSL).

### Como rodar
Transfira o arquivo `execution/flashp_install.sh` para sua VPS ou execute via comando remoto:

```bash
# Via arquivo local
chmod +x execution/flashp_install.sh
sudo ./execution/flashp_install.sh
```

## 🌐 Deploy Manual
Para detalhes sobre como implantar em uma VPS manualmente passo a passo, consulte o arquivo `vps_deployment_guide.md` no repositório.

---
Desenvolvido com foco em velocidade e privacidade. ⚡
