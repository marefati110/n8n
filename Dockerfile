# syntax=docker/dockerfile:1.5

###############################
# 1) Builder – compile n8n   #
###############################
ARG NODE_VERSION=24.18.1

FROM node:${NODE_VERSION}-bookworm-slim AS builder

WORKDIR /src

# Build toolchain + git (needed by pnpm/prepare) + CA certs for registry HTTPS
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm via Corepack (version must match packageManager in package.json)
RUN corepack enable pnpm \
    && corepack prepare pnpm@10.32.1 --activate

COPY . /src

ENV DOCKER_BUILD=true \
    CI=true \
    NODE_OPTIONS=--max-old-space-size=6144 \
    TURBO_CONCURRENCY=2

# DOCKER_BUILD=true skips lefthook install in scripts/prepare.mjs
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm build

# Deploy pruned production bundle into ./compiled
RUN node scripts/docker-deploy-n8n.mjs

# Rebuild native modules for the runtime libc
RUN cd /src/compiled && \
    npm rebuild sqlite3 && \
    rm -rf node_modules/isolated-vm/prebuilds && \
    cd node_modules/isolated-vm && \
    node /usr/local/lib/node_modules/npm/node_modules/node-gyp/bin/node-gyp.js rebuild --release -j max

###############################
# 2) Runtime                  #
###############################
FROM node:${NODE_VERSION}-bookworm-slim

ENV NODE_ENV=production \
    N8N_RELEASE_TYPE=stable \
    N8N_DIAGNOSTICS_ENABLED=false \
    GENERIC_TIMEZONE=Asia/Tehran \
    TZ=Asia/Tehran

# Chromium + runtime deps (Debian/bookworm)
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    libnss3 \
    libfreetype6 \
    libharfbuzz0b \
    ca-certificates \
    fonts-freefont-ttf \
    tini \
    gosu \
    git \
    graphicsmagick \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
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