# image is based on https://docs.konghq.com/gateway/latest/plugin-development/distribution/#via-a-dockerfile-or-docker-run-install-and-load
FROM kong/kong-gateway:3.7.0.0

# Ensure any patching steps are executed as root user
USER root

# Add custom plugin to the image
COPY kong-plugin-inigo-0.1.0-1.all.rock .
RUN apt-get update; apt-get install unzip
RUN luarocks install kong-plugin-inigo-0.1.0-1.all.rock
ENV KONG_PLUGINS=bundled,inigo

# add inigo lib
COPY libs /kong/plugins/inigo

# Ensure kong user is selected for image execution
USER kong

# Run kong
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD kong health
CMD ["kong", "docker-start"]
