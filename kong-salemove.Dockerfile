FROM kong:0.11-alpine

RUN RUN apk add --no-cache tini \
  && luarocks install kong-plugin-datadog-tags 0.2.3

ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint.sh"]

CMD ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/usr/local/kong/nginx.conf", "-p", "/usr/local/kong/"]
