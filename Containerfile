FROM ghcr.io/ublue-os/bluefin-dx-nvidia:latest

COPY build.sh /tmp/

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh && \
    ostree container commit
