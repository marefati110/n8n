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
    pnpm install --frozen-lockfile

RUN pnpm build

# Slim down: keep only production node_modules
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm prune --prod --no-optional \
    && find . -name '*.ts' ! -name '*.d.ts' -delete \
    && find . -name '*.map'                 -delete \
    && find . -name '*.tsbuildinfo'         -delete \
    && rm -rf .turbo

###############################
# 2) Runtime                  #
###############################
FROM node:${NODE_VERSION}-alpine

ENV NODE_ENV=production \
    N8N_RELEASE_TYPE=custom \
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
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

WORKDIR /home/node

# Copy built files
COPY --from=builder /src /home/node

# Install external community nodes
RUN cd /home/node && \
    NODE_PATH=/home/node/node_modules node -e " \
      const fs = require('fs'); \
      const pkg = JSON.parse(fs.readFileSync('package.json','utf8')); \
      const extras = [ \
        'n8n-nodes-text-manipulation', \
        '@nicholasgasior/n8n-nodes-gpt', \
        'n8n-nodes-globals', \
        'n8n-nodes-document-generator', \
        'n8n-nodes-mattermost-app', \
        'n8n-nodes-puppeteer-extended', \
        '@neverlosecc/n8n-nodes-phonenumber-parser' \
      ]; \
      extras.forEach(function(p){ pkg.dependencies[p] = 'latest'; }); \
      fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n'); \
    "

# Install the external modules
RUN corepack enable pnpm \
    && corepack prepare pnpm@10.22.0 --activate \
    && pnpm install --no-frozen-lockfile

# Use docker-entrypoint from upstream if available
COPY docker/images/n8n/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 5678

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
