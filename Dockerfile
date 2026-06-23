# syntax=docker/dockerfile:1.5

###############################
# 1) Builder – compile n8n   #
###############################
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-alpine AS builder

#–––– Context & Caching ––––#
WORKDIR /src

# Install pnpm via Corepack
RUN corepack enable pnpm \
    && corepack prepare pnpm@10.22.0 --activate

COPY . /src

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    DOCKER_BUILD=true pnpm install --frozen-lockfile

RUN pnpm build

# Slim down: keep only production node_modules
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    CI=true pnpm prune --prod --no-optional \
    && find . -name '*.ts' ! -name '*.d.ts' -delete \
    && find . -name '*.map'                 -delete \
    && find . -name '*.tsbuildinfo'         -delete \
    && rm -rf .turbo \
    && rm -rf packages/editor-ui/node_modules \
    && rm -rf .git

###############################
# 2) Runtime                  #
###############################
FROM node:${NODE_VERSION}-alpine

ENV NODE_ENV=production \
    N8N_RELEASE_TYPE=stable \
    N8N_DIAGNOSTICS_ENABLED=false \
    GENERIC_TIMEZONE=Asia/Tehran \
    TZ=Asia/Tehran

# Install chromium for puppeteer (optional, for headless browser nodes)
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

# Copy built files
COPY --from=builder /src /home/node

# Install external community nodes and modules
RUN mkdir -p /home/node/.n8n/custom && \
    cd /home/node/.n8n/custom && \
    npm init -y && \
    npm install n8n-nodes-text-manipulation n8n-nodes-globals n8n-nodes-document-generator n8n-nodes-puppeteer-extended moment-jalaali

# Use docker-entrypoint from upstream if available
COPY docker/images/n8n/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh && \
    echo '#!/bin/sh' > /usr/local/bin/n8n && \
    echo 'exec /home/node/packages/cli/bin/n8n "$@"' >> /usr/local/bin/n8n && \
    chmod +x /usr/local/bin/n8n && \
    mkdir -p /home/node/.n8n && \
    chown -R node:node /home/node

EXPOSE 5678

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
