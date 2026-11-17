#!/bin/sh
# Start D-Bus, Avahi and CUPS, then run the queue setup script.
#
# Environment:
#   AVAHI_HOSTNAME    mDNS host name to announce (default: the container's).
#   AVAHI_INTERFACES  Interfaces Avahi may use. Default: the interface that
#                     holds the default route, so a host-network pod doesn't
#                     announce on CNI bridges or veths.
#   SETUP_SCRIPT      Run once cupsd is up (default /config/setup.sh); it
#                     creates the queues with lpadmin.
set -eu

iface="${AVAHI_INTERFACES:-$(ip -4 route show default | awk '{for (i=1;i<NF;i++) if ($i=="dev") {print $(i+1); exit}}')}"

mkdir -p /run/dbus /run/avahi-daemon /run/cups
rm -f /run/dbus/pid /run/avahi-daemon/pid
dbus-daemon --system --fork

cat > /etc/avahi/avahi-daemon.conf <<CONF
[server]
${AVAHI_HOSTNAME:+host-name=${AVAHI_HOSTNAME}}
use-ipv4=yes
use-ipv6=no
allow-interfaces=${iface}
ratelimit-interval-usec=1000000
ratelimit-burst=1000
[wide-area]
enable-wide-area=no
[publish]
publish-hinfo=no
publish-workstation=no
[reflector]
enable-reflector=no
CONF
avahi-daemon --daemonize --no-drop-root 2>/dev/null || avahi-daemon --daemonize
echo "avahi on ${iface} as ${AVAHI_HOSTNAME:-$(hostname)}.local"

cupsd -f &
cups_pid=$!
trap 'kill -TERM "$cups_pid" 2>/dev/null; avahi-daemon --kill 2>/dev/null || true' TERM INT

i=0
until lpstat -r >/dev/null 2>&1; do
  i=$((i + 1)); [ "$i" -gt 30 ] && { echo "cupsd did not start" >&2; exit 1; }
  sleep 1
done

setup="${SETUP_SCRIPT:-/config/setup.sh}"
if [ -f "$setup" ]; then
  echo "running $setup"
  sh "$setup"
fi
lpstat -v || true

wait "$cups_pid"
