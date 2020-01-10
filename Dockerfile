FROM golang:1.13-alpine3.11 as build

RUN apk add --no-cache git curl unzip

# goreman supervisor build latest
WORKDIR /work
RUN export GOPATH=/work && export CGO_ENABLED=0 && go get github.com/mattn/goreman

# AriaNg install latest
RUN GITHUB_REPO="https://github.com/mayswind/AriaNg" \
  && LATEST=`curl -s  $GITHUB_REPO"/releases/latest" | grep -Eo "[0-9]*\.[0-9]*\.[0-9]*"` \
  && curl -L $GITHUB_REPO"/releases/download/"$LATEST"/AriaNg-"$LATEST"-AllInOne.zip" > ariang.zip \
  && unzip ariang.zip

FROM alpine:3.11

# customizable values
ENV RPC_PORT 6800
ENV HTTPD_PORT 8080
ENV DUMMY_UID 1000

# less priviledge user, the id should map the user the downloaded files belongs to
RUN addgroup -S dummy && adduser -S -G dummy -u ${DUMMY_UID} dummy

# httpd + aria2
RUN apk add --no-cache busybox busybox-extras aria2 su-exec

RUN mkdir -p /ariang/www
WORKDIR /ariang

# copy built goreman
COPY --from=build /work/bin/goreman /usr/local/bin/goreman
COPY --from=build /work/index.html /ariang/www/index.html

# goreman setup
RUN echo "web: su-exec dummy:dummy /bin/busybox-extras httpd -f -p ${HTTPD_PORT} -h /ariang/www" > Procfile && \
  echo "backend: su-exec dummy:dummy /usr/bin/aria2c --enable-rpc --rpc-listen-all --rpc-allow-origin-all --rpc-listen-port=${RPC_PORT} --dir=/data" >> Procfile

# aria2 downloads directory
VOLUME /data

# IP port listing:
EXPOSE ${RPC_PORT}/tcp ${HTTPD_PORT}/tcp

CMD ["start"]
ENTRYPOINT ["/usr/local/bin/goreman"]
