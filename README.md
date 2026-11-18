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

- With `AIRSANE=true`, [AirSane](https://github.com/SimulPiscator/AirSane)
  shares the SANE scanners as eSCL/AirScan scanners on port 8090 (Apple Image
  Capture, Windows 10/11, the Mopria Scan app on Android, sane-airscan on
  Linux), with a web page at `http://host:8090/`. Write the SANE config
  (`/etc/sane.d/dll.conf`, backend files) from `setup.sh`. A watchdog sends
  airsaned SIGHUP to search again while no scanner is exported
  (`AIRSANE_WATCHDOG`, seconds).

Example `setup.sh`:

```sh
# lpinfo -m can fail right after cupsd starts (driver cache still building),
# so build the PPD from the Gutenprint driver program directly.
/usr/lib/cups/driver/gutenprint.5.3 cat gutenprint.5.3://bjc-MULTIPASS-MP495/expert > /tmp/mp495.ppd
lpadmin -p mp495 -E -v lpd://printer.example/lp -P /tmp/mp495.ppd \
  -D "Canon PIXMA MP495" -o printer-is-shared=true
lpadmin -d mp495

# Canon PIXMA network scanner (BJNP), for AirSane
echo pixma > /etc/sane.d/dll.conf
printf 'auto_detection=no\nbjnp://printer.example\n' > /etc/sane.d/pixma.conf
```

Images: `ghcr.io/elevate08/cups-gutenprint:1.<build>` and `:latest`, rebuilt
weekly.
