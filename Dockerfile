FROM node:14-alpine AS base

ENV CHROME_BIN="/usr/bin/chromium-browser"
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD="true"
#ENV CXXFLAGS="-Wno-ignored-qualifiers -Wno-stringop-truncation -Wno-cast-function-type"

WORKDIR /usr/src/app

RUN \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories && \
  apk --no-cache upgrade && \
  apk add --no-cache udev ttf-opensans unifont chromium ca-certificates dumb-init bash tzdata pango-dev && \
  rm -rf /tmp/*

FROM base as build

RUN apk add git && \
    git clone --depth 1 https://github.com/grafana/grafana-image-renderer.git && \
    cd grafana-image-renderer/ && \
    cd .. && \
    mv grafana-image-renderer/* /usr/src/app/ && \
    rm -rf grafana-image-renderer

RUN yarn install --pure-lockfile
RUN yarn run build

EXPOSE 8081

CMD [ "yarn", "run", "dev" ]

FROM base

ARG GF_UID="472"
ARG GF_GID="472"
ENV GF_PATHS_HOME="/usr/src/app"

WORKDIR $GF_PATHS_HOME

RUN addgroup -S -g $GF_GID grafana && \
    adduser -S -u $GF_UID -G grafana grafana && \
    mkdir -p "$GF_PATHS_HOME" && \
    chown -R grafana:grafana "$GF_PATHS_HOME"

ENV NODE_ENV=production

COPY --from=build /usr/src/app/node_modules node_modules
COPY --from=build /usr/src/app/build build
COPY --from=build /usr/src/app/proto proto
COPY --from=build /usr/src/app/default.json config.json
COPY --from=build /usr/src/app/plugin.json plugin.json

EXPOSE 8081

ENTRYPOINT ["dumb-init", "--"]

CMD ["node", "build/app.js", "server", "--config=config.json"]
