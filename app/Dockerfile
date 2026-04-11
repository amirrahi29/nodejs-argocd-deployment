FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM node:22-alpine
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json index.js ./
USER node
EXPOSE 3000
ENV NODE_ENV=production
ENV PORT=3000
LABEL org.opencontainers.image.title="chat-app" \
  org.opencontainers.image.description="Express sample for GitOps demo"

CMD ["node", "index.js"]
