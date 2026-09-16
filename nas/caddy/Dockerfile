ARG CADDY_VERSION=2.11.4
ARG CLOUDFLARE_PLUGIN_VERSION=v0.2.4

FROM caddy:${CADDY_VERSION}-builder-alpine AS builder
ARG CLOUDFLARE_PLUGIN_VERSION
RUN xcaddy build --with github.com/caddy-dns/cloudflare@${CLOUDFLARE_PLUGIN_VERSION}

FROM caddy:${CADDY_VERSION}-alpine
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
