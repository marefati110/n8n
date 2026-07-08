# syntax=docker/dockerfile:1.5

###############################
# 1) Builder – compile n8n   #
###############################
ARG NODE_VERSION=24.16.0

FROM node:${NODE_VERSION}-alpine AS builder

WORKDIR /src

# Install pnpm via Corepack (version must match packageManager in package.json)
RUN corepack enable pnpm \
    && corepack prepare pnpm@10.32.1 --activate \
    && apk add --no-cache python3 make g++ git

COPY . /src

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    DOCKER_BUILD=true pnpm install --frozen-lockfile

# Compile monorepo (same approach as the previous working custom Dockerfile)
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    DOCKER_BUILD=true pnpm build

# Deploy pruned production bundle into ./compiled
RUN DOCKER_BUILD=true CI=true node scripts/docker-deploy-n8n.mjs

# Rebuild native modules for Alpine/musl (sqlite3, isolated-vm)
RUN cd /src/compiled && \
    npm rebuild sqlite3 && \
    rm -rf node_modules/isolated-vm/prebuilds && \
    cd node_modules/isolated-vm && \
    node /usr/local/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --release -j max

###############################
# 2) Runtime                  #
###############################
FROM node:${NODE_VERSION}-alpine

ENV NODE_ENV=production \
    N8N_RELEASE_TYPE=stable \
    N8N_DIAGNOSTICS_ENABLED=false \
    GENERIC_TIMEZONE=Asia/Tehran \
    TZ=Asia/Tehran

# Install chromium for puppeteer (headless browser nodes)
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    tini \
    su-exec \
    git \
    graphicsmagick

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    NODE_FUNCTION_ALLOW_EXTERNAL=* \
    NODE_PATH=/home/node/.n8n/custom/node_modules

WORKDIR /home/node

# Deployed production bundle (all workspace deps resolved correctly)
COPY --from=builder /src/compiled /usr/local/lib/node_modules/n8n

# Install external community nodes and modules
RUN mkdir -p /home/node/.n8n/custom && \
    cd /home/node/.n8n/custom && \
    npm init -y && \
    npm install n8n-nodes-text-manipulation n8n-nodes-globals n8n-nodes-document-generator n8n-nodes-puppeteer-extended moment-jalaali

COPY docker/images/n8n/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && \
    ln -sf /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node && \
    rm -rf /root/.npm /tmp/*

EXPOSE 5678

USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
