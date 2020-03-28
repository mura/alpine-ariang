#!/bin/sh
# setup goreman
echo "web: su-exec dummy:dummy /bin/busybox-extras httpd -f -p ${HTTPD_PORT} -h /ariang/www" > Procfile && \
echo "backend: su-exec dummy:dummy /usr/bin/aria2c --enable-rpc --rpc-listen-all --rpc-allow-origin-all --rpc-listen-port=${RPC_PORT} ${EXTRA_OPTS} --dir=/data" >> Procfile
# start goreman
/usr/local/bin/goreman start