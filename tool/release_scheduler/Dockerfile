FROM node:24-bookworm-slim

ENV NODE_ENV=production
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY --chown=node:node src ./src

USER node
EXPOSE 8080
CMD ["node", "src/server.ts"]
