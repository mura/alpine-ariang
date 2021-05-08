#!/bin/bash
set -e

if [ "$1" = 'aria2c' ]; then
  shift
  echo 'Create Procfile.'
  {
    echo "web: busybox httpd -f -p ${HTTPD_PORT} -h /app/www"
    echo "backend: aria2c $@"
  } | tee Procfile

  exec goreman start
fi

exec "$@"