FROM kong:0.11-alpine

RUN luarocks install kong-plugin-datadog-tags 0.2.0

CMD ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/usr/local/kong/nginx.conf", "-p", "/usr/local/kong/"]
