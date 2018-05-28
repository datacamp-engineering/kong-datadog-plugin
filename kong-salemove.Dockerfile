FROM kong:0.11-alpine

RUN luarocks install kong-plugin-datadog-tags 0.2.3

# Create symlinks to redirect nginx logs to stdout and stderr docker log collector
RUN mkdir -p /usr/local/kong/logs \
  && ln -sf /dev/stdout /usr/local/kong/logs/access.log \
  && ln -sf /dev/stdout /usr/local/kong/logs/admin_access.log \
  && ln -sf /dev/stderr /usr/local/kong/logs/error.log

CMD ["/usr/local/openresty/nginx/sbin/nginx", "-c", "/usr/local/kong/nginx.conf", "-p", "/usr/local/kong/"]
