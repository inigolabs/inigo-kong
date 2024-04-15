FROM kong/kong-gateway:latest

# Ensure any patching steps are executed as root user
USER root

RUN apt update
RUN apt install unzip

# Add custom plugin to the image
COPY kong-plugin-inigo-0.1.0-1.all.rock .

COPY kong/plugins/inigo/inigo_linux_amd64 /kong/plugins/inigo/inigo_linux_amd64

COPY kong.yml .

ENV KONG_DECLARATIVE_CONFIG=kong.yml

ENV KONG_PLUGINS=bundled,inigo

ENV LOG_LEVEL=DEBUG
ENV KONG_DATABASE=off

RUN luarocks install kong-plugin-inigo-0.1.0-1.all.rock

# Ensure kong user is selected for image execution
USER kong

# Run kong
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 8000 8443 8001 8444
STOPSIGNAL SIGQUIT
HEALTHCHECK --interval=10s --timeout=10s --retries=10 CMD kong health
CMD ["kong", "docker-start"]
