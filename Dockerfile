# syntax=docker/dockerfile:1.5

###############################
# 1) Builder – compile n8n   #
###############################
ARG NODE_VERSION=22

FROM n8nio/base:${NODE_VERSION} AS builder

#–––– Context & Caching ––––#
WORKDIR /src

# Install pnpm via Corepack
RUN corepack enable pnpm \
    && corepack prepare pnpm@10.22.0 --activate

COPY . /src

RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    --mount=type=cache,id=pnpm-metadata,target=/root/.cache/pnpm/metadata \
    CI=true pnpm install --shamefully-hoist \
    && pnpm build

#–––– Slim down the tree ––––#
RUN node -e "const pkg=require('./package.json'); if(pkg.pnpm) delete pkg.pnpm.patchedDependencies; require('fs').writeFileSync('package.json', JSON.stringify(pkg,null,2))" \
    && if [ -f .github/scripts/trim-fe-packageJson.js ]; then \
         node .github/scripts/trim-fe-packageJson.js; \
       else \
         echo "trim-fe-packageJson.js not found – skipping"; \
       fi \
    && find . -type f \( -name "*.ts" -o -name "*.js.map" -o -name "*.vue" -o -name "tsconfig.json" -o -name "*.tsbuildinfo" \) -delete

# Deploy only the n8n package (+ its prod deps) into /compiled
RUN mkdir /compiled \
    && NODE_ENV=production DOCKER_BUILD=true pnpm --filter=n8n --prod --no-optional --legacy deploy /compiled

###############################
# 2) Runtime – minimal image  #
###############################
FROM n8nio/base:${NODE_VERSION}

ENV NODE_ENV=production \
    N8N_PORT=5678 \
		N8N_RELEASE_TYPE=stable \
		NODE_FUNCTION_ALLOW_EXTERNAL=moment-jalaali,ejs,axios,bcrypt,bcryptjs \		NODE_PATH=/usr/local/lib/node_modules/n8n-external:/usr/local/lib/node_modules \
		N8N_LICENSE_ENDPOINT=http://localhost:3000
		

WORKDIR /home/node

# Copy the compiled artefacts
COPY --from=builder /compiled /usr/local/lib/node_modules/n8n
# Install moment-jalaali both globally and in a separate directory for Code node access
RUN npm install -g moment-jalaali && \
    mkdir -p /usr/local/lib/node_modules/n8n-external && \
    cd /usr/local/lib/node_modules/n8n-external && \
    npm init -y && \
    npm install moment-jalaali ejs axios bcrypt bcryptjs && \
    cd -
# Install community nodes
RUN mkdir -p /home/node/.n8n/nodes/node_modules && \
    cd /home/node/.n8n/nodes/node_modules && \
    npm install moment-jalaali n8n-nodes-persiandate n8n-nodes-pocketbase @pllusin/n8n-nodes-telepilot && \
    chown -R node:node /home/node/.n8n

# Bundle entrypoint & task‑runner config from repo (paths may vary in forks)
COPY docker/images/n8n/docker-entrypoint.sh /docker-entrypoint.sh
COPY docker/images/runners/n8n-task-runners.json /etc/n8n-task-runners.json

#–––– Task‑runner launcher ––––#
ARG LAUNCHER_VERSION=1.1.2
RUN set -eux; \
    mkdir /launcher-temp && cd /launcher-temp && \
    wget -q https://github.com/n8n-io/task-runner-launcher/releases/download/${LAUNCHER_VERSION}/task-runner-launcher-${LAUNCHER_VERSION}-linux-amd64.tar.gz && \
    wget -q https://github.com/n8n-io/task-runner-launcher/releases/download/${LAUNCHER_VERSION}/task-runner-launcher-${LAUNCHER_VERSION}-linux-amd64.tar.gz.sha256 && \
    echo "$(cat task-runner-launcher-${LAUNCHER_VERSION}-linux-amd64.tar.gz.sha256)  task-runner-launcher-${LAUNCHER_VERSION}-linux-amd64.tar.gz" > checksum.sha256 && \
    sha256sum -c checksum.sha256 && \
    tar xvf task-runner-launcher-${LAUNCHER_VERSION}-linux-amd64.tar.gz --directory=/usr/local/bin && \
    cd - && rm -rf /launcher-temp

    
# Rebuild native bindings (sqlite3) for the final image libc
RUN cd /usr/local/lib/node_modules/n8n && npm rebuild sqlite3 && cd -

# Symlink CLI & prepare data dir
RUN ln -s /usr/local/lib/node_modules/n8n/bin/n8n /usr/local/bin/n8n \
    && mkdir -p /home/node/.n8n \
    && chown node:node /home/node/.n8n

EXPOSE 5678
USER node
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
