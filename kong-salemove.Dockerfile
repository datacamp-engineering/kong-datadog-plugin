FROM kong:0.11-alpine

RUN luarocks install kong-plugin-datadog-tags

CMD ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/usr/local/kong/nginx.conf", "-p", "/usr/local/kong/"]
