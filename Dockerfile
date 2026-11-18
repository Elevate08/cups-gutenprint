# CUPS print server with the Gutenprint drivers and Avahi (mDNS/DNS-SD), for
# sharing older printers as driverless IPP/AirPrint queues, plus AirSane to
# share their SANE scanners as eSCL/AirScan scanners.

ARG AIRSANE_VERSION=v0.4.16

FROM debian:trixie-slim AS airsane
ARG AIRSANE_VERSION
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates git cmake make g++ \
      libsane-dev libjpeg-dev libpng-dev libavahi-client-dev libusb-1.0-0-dev \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "${AIRSANE_VERSION}" https://github.com/SimulPiscator/AirSane.git /src \
 && cmake -S /src -B /build -DCMAKE_BUILD_TYPE=Release \
 && cmake --build /build -j"$(nproc)" \
 && install -D -m0755 /build/airsaned /out/usr/sbin/airsaned \
 && install -d /out/etc/airsane \
 && cp /src/etc/access.conf /src/etc/ignore.conf /src/etc/options.conf /src/etc/Gnome-scanner.png /out/etc/airsane/

FROM debian:trixie-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cups cups-bsd cups-client cups-filters printer-driver-gutenprint \
      avahi-daemon dbus iproute2 tini ca-certificates curl \
      libsane1 sane-utils libjpeg62-turbo libpng16-16t64 libavahi-client3 libusb-1.0-0 \
 && (DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cups-backend-bjnp || true) \
 && rm -rf /var/lib/apt/lists/*

COPY --from=airsane /out/ /
COPY cupsd.conf /etc/cups/cupsd.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

EXPOSE 631 8090
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
