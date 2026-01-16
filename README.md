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

## 🛠️ Guia por Ferramenta

### Como instalar no Portainer?
1. No Portainer, acesse **Stacks** > **Add stack**.
2. Escolha **Repository** ou **Web editor**.
3. Se usar o editor, utilize as configurações contidas no arquivo [docker-compose.example.yml](docker-compose.example.yml).
4. Se usar **Repository**, aponte para o link do seu GitHub e configure a porta 3000.

### Como instalar no Coolify?
1. Acesse o painel do Coolify.
2. Clique em **Create New Resource** > **Application** > **GitHub Repository**.
3. Selecione o repositório Flashp.
4. O Coolify detectará automaticamente o Next.js. Garanta que a porta de destino seja **3000**.
5. Clique em **Deploy**.

### Como instalar no Easypanel?
1. No Easypanel, crie um novo **Project**.
2. Clique em **Add Service** > **App** > **Git**.
3. Insira a URL do seu repositório GitHub.
4. Em **Environment**, escolha **Node.js**.
5. Em **Domains**, aponte seu domínio para a porta **3000**.

## 🌐 Deploy Manual
Para detalhes sobre como implantar em uma VPS manualmente passo a passo, consulte o arquivo [vps_deployment_guide.md](vps_deployment_guide.md) no repositório.

---
Desenvolvido com foco em velocidade e privacidade. ⚡

