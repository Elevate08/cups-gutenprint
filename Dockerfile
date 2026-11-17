# CUPS print server with the Gutenprint drivers and Avahi (mDNS/DNS-SD), for
# sharing older printers as driverless IPP/AirPrint queues.
FROM debian:trixie-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      cups cups-bsd cups-client cups-filters printer-driver-gutenprint \
      avahi-daemon dbus iproute2 tini ca-certificates \
 && (DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends cups-backend-bjnp || true) \
 && rm -rf /var/lib/apt/lists/*

COPY cupsd.conf /etc/cups/cupsd.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

EXPOSE 631
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
