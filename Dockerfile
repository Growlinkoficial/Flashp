# Usar a imagem oficial do Node.js
FROM node:20-alpine

# Criar diretório da aplicação
WORKDIR /app

# Copiar arquivos de configuração primeiro para aproveitar o cache das camadas
COPY package*.json ./

# Instalar dependências
RUN npm install

# Copiar o restante do código
COPY . .

# Gerar o build do Next.js
RUN npm run build

# Expor a porta 3000
EXPOSE 3000

# Comando para iniciar a aplicação
CMD ["npm", "start"]
