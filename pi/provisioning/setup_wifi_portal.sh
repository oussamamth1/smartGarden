#!/usr/bin/env bash
# Run this ONCE on the Raspberry Pi to install the WiFi onboarding portal.
#   cd ~/garden/pi/provisioning && bash setup_wifi_portal.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Checking NetworkManager (required by wifi-connect)"
if ! systemctl is-active --quiet NetworkManager; then
    echo "!! NetworkManager is not active."
    echo "   On Raspberry Pi OS Bookworm it's the default. If you're on an older"
    echo "   image, enable it: sudo raspi-config -> Advanced -> Network Config ->"
    echo "   NetworkManager, then reboot and re-run this script."
    exit 1
fi

echo "==> Installing balena wifi-connect (if missing)"
if ! command -v wifi-connect >/dev/null 2>&1; then
    bash <(curl -sL https://raw.githubusercontent.com/balena-os/wifi-connect/master/scripts/raspbian-install.sh)
else
    echo "    wifi-connect already installed: $(command -v wifi-connect)"
fi

echo "==> Installing the boot service"
chmod +x "$DIR/start-wifi-connect.sh"
sudo cp "$DIR/garden-wifi.service" /etc/systemd/system/garden-wifi.service
sudo systemctl daemon-reload
sudo systemctl enable garden-wifi.service

echo
echo "Done. Reboot the Pi. If it has no known WiFi, it will broadcast the"
echo "'GardenPi-Setup' network — connect a phone to it and a page will open to"
echo "choose your WiFi and enter the password."
