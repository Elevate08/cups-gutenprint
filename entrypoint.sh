#!/bin/bash
# Start D-Bus, Avahi and CUPS, run the setup script, then (optionally) AirSane.
# Exits when cupsd or airsaned dies, so the orchestrator restarts the container.
#
# Environment:
#   AVAHI_HOSTNAME    mDNS host name to announce (default: the container's).
#   AVAHI_INTERFACES  Interfaces Avahi may use. Default: the interface that
#                     holds the default route, so a host-network pod doesn't
#                     announce on CNI bridges or veths.
#   SETUP_SCRIPT      Run once cupsd is up (default /config/setup.sh); it
#                     creates the queues with lpadmin and can write the SANE
#                     config (/etc/sane.d) before AirSane starts.
#   AIRSANE           "true" to run airsaned (eSCL/AirScan on port 8090).
#   AIRSANE_ARGS      Extra airsaned options. Default turns off USB and network
#                     hotplug (a host-network pod sees constant interface churn).
#   AIRSANE_WATCHDOG  Seconds between checks that a scanner is exported; if
#                     none is (e.g. the scanner was off at start), airsaned
#                     gets SIGHUP to search again. Default 300; 0 disables.
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

pids=()
cupsd -f &
pids+=($!)
trap 'kill -TERM "${pids[@]}" 2>/dev/null; avahi-daemon --kill 2>/dev/null || true' TERM INT

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

if [ "${AIRSANE:-false}" = "true" ]; then
  # shellcheck disable=SC2086
  airsaned ${AIRSANE_ARGS:---hotplug=false --network-hotplug=false} &
  airsane_pid=$!
  pids+=($airsane_pid)
  echo "airsaned started"
  interval="${AIRSANE_WATCHDOG:-300}"
  if [ "$interval" -gt 0 ]; then
    (
      while sleep "$interval"; do
        if ! curl -sf -o /dev/null http://127.0.0.1:8090/eSCL/ScannerCapabilities; then
          echo "no scanner exported, asking airsaned to search again"
          kill -HUP "$airsane_pid" 2>/dev/null || exit 0
        fi
      done
    ) &
  fi
fi

# Stop as soon as any supervised daemon exits.
wait -n "${pids[@]}"
echo "a daemon exited; stopping" >&2
kill -TERM "${pids[@]}" 2>/dev/null || true
exit 1
