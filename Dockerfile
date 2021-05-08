FROM golang:1.16-buster as build

RUN set -eux; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git \
      curl \
    ; \
    rm -rf /var/lib/apt/lists/*

# goreman supervisor build latest
WORKDIR /work
RUN set -eux; \
    \
    export GOPATH=/work; \
    export CGO_ENABLED=0; \
    go get github.com/mattn/goreman

FROM debian:buster-slim

# customizable values
ENV RPC_PORT 6800
ENV HTTPD_PORT 8080

# persistent / runtime deps
RUN set -eux; \
    \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      busybox-static \
      ca-certificates \
      curl \
    ; \
    rm -rf /var/lib/apt/lists/*

# build aria2
ENV ARIA2_URL=https://github.com/aria2/aria2/releases/download/release-1.35.0/aria2-1.35.0.tar.xz
RUN set -eux; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      xz-utils \
      dpkg-dev \
      autoconf \
      automake \
      autopoint \
      libtool \
      g++ \
      gcc \
      libc-dev \
      make \
      libssl-dev \
      libssh2-1-dev \
      libc-ares-dev \
      libxml2-dev \
      zlib1g-dev \
      libsqlite3-dev \
      pkg-config \
    ; \
    \
    mkdir -p /usr/src; \
    cd /usr/src; \
    \
    curl -fsSL -o aria2.tar.xz "$ARIA2_URL"; \
    mkdir -p /usr/src/aria2; \
    tar -Jxf aria2.tar.xz -C aria2 --strip-components=1; \
    cd /usr/src/aria2; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    autoreconf -i; \
    ./configure \
		  --build="$gnuArch" \
      --with-ca-bundle='/etc/ssl/certs/ca-certificates.crt'; \
    make -j "$(nproc)"; \
    make install; \
    find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; \
    \
    cd /; \
    rm -rf /usr/src/aria2; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
    find /usr/local -type f -executable -exec ldd '{}' ';' \
      | awk '/=>/ { print $(NF-1) }' \
      | sort -u \
      | xargs -r dpkg-query --search \
      | cut -d: -f1 \
      | sort -u \
      | xargs -r apt-mark manual \
    ; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    \
# somake test
    aria2c --version

# AriaNg install latest
RUN set -eux; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      unzip \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    mkdir -p /usr/src; \
    cd /usr/src; \
    \
    GITHUB_REPO="https://github.com/mayswind/AriaNg"; \
    LATEST=`curl -s  $GITHUB_REPO"/releases/latest" | grep -Eo "[0-9]*\.[0-9]*\.[0-9]*"`; \
    curl -fsSL -o ariang.zip "${GITHUB_REPO}/releases/download/${LATEST}/AriaNg-${LATEST}-AllInOne.zip"; \
    unzip ariang.zip -d ariang; \
    \
    mkdir -p /app/www; \
    mkdir -p /app/cache; \
    cp -p /usr/src/ariang/index.html /app/www/index.html; \
    \
    cd /; \
    rm -rf /usr/src/ariang; \
    \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark > /dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# copy built goreman
COPY --from=build /work/bin/goreman /usr/local/bin/goreman

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod 755 /docker-entrypoint.sh

# aria2 downloads directory
VOLUME [ "/data" ]

ENTRYPOINT ["/docker-entrypoint.sh"]
WORKDIR /app

RUN set -eux;\
    { \
      echo 'enable-rpc'; \
      echo 'rpc-listen-all'; \
      echo 'rpc-allow-origin-all'; \
      echo "rpc-listen-port=${RPC_PORT}"; \
      echo 'dir=/data'; \
      echo 'dht-file-path=/app/cache/dht.dat'; \
      echo 'dht-file-path6=/app/cache/dht6.dat'; \
    } | tee /app/aria2.conf

EXPOSE ${RPC_PORT}/tcp ${HTTPD_PORT}/tcp
CMD ["aria2c" "--conf-path=/app/aria2.conf"]