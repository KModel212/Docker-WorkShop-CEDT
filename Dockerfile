# syntax=docker/dockerfile:1.7

# Stage 1: Install production dependencies
FROM node:24-alpine AS builder
WORKDIR /app
COPY app/ ./

# Update the vulnerable transitive dependency without editing workshop app sources.
RUN npm pkg set "overrides.proxy-addr=2.0.8" \
    && npm install --package-lock-only --ignore-scripts \
    && npm ci --omit=dev \
    && node -p "require('proxy-addr/package.json').version"

# Stage 2: Runtime
FROM node:24-alpine
WORKDIR /app

# Update OS packages, and remove npm from runtime (the old npm bundle contained vulnerable tar).
RUN apk upgrade --no-cache \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

COPY --from=builder /app /app
ENV NODE_ENV=production
EXPOSE 3000

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=5 \
    CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode===200?0:1)).on('error', () => process.exit(1))"

CMD ["node", "src/index.js"]
