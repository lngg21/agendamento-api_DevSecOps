# Estágio 1: Build e Resolução de Dependências
FROM node:20-alpine AS builder

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build --if-present
RUN npm prune --production

# Estágio 2: Execução em Produção (Imagem Mínima)
FROM node:20-alpine AS runner

WORKDIR /usr/src/app

ENV NODE_ENV=production

USER node

COPY --chown=node:node --from=builder /usr/src/app/node_modules ./node_modules
COPY --chown=node:node --from=builder /usr/src/app/package*.json ./
COPY --chown=node:node --from=builder /usr/src/app/dist ./dist

EXPOSE 3000

# Healthcheck via Node nativo, sem curl/wget na imagem final
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/api/health', res => process.exit(res.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

CMD ["node", "dist/server.js"]