#!/bin/bash
set -e

if [ "$1" = 'aria2c' ]; then
  shift
  if [ "$USE_HTTPD" = "true" ]; then
    echo 'Launch aria2 and httpd.'
    {
      echo "web: busybox httpd -f -p ${HTTPD_PORT} -h /app/www"
      echo "backend: aria2c $@"
    } | tee Procfile
    exec goreman start
  else
    echo 'Only launch aria2.'
    exec aria2c "$@"
  fi
fi

exec "$@"