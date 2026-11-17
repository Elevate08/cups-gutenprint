# cups-gutenprint

A CUPS print server image (Debian trixie) with the Gutenprint drivers and Avahi,
for sharing an older printer on the network as a driverless IPP/AirPrint queue:
clients print to CUPS, and CUPS runs the printer's driver.

- Queues are created at start-up by `/config/setup.sh` (mount it, e.g. from a
  ConfigMap) using `lpadmin`; nothing is stored in the image.
- Administration is limited to localhost, so there are no admin credentials.
- Avahi announces shared queues over DNS-SD on the default-route interface
  (`AVAHI_INTERFACES` overrides it; `AVAHI_HOSTNAME` sets the mDNS host name).
  For mDNS on a LAN from Kubernetes, run the pod with `hostNetwork: true`.

Example `setup.sh`:

```sh
model=$(lpinfo -m | awk '/MP495/ && /expert/ {print $1; exit}')
lpadmin -p mp495 -E -v lpd://printer.example/lp -m "$model" \
  -D "Canon PIXMA MP495" -o printer-is-shared=true
lpadmin -d mp495
```

Images: `ghcr.io/elevate08/cups-gutenprint:1.<build>` and `:latest`, rebuilt
weekly.
