#!/usr/bin/env bash
# Garden Pi WiFi onboarding.
#
# On boot, if the Pi is NOT connected to a network, start a setup hotspot +
# captive portal ("GardenPi-Setup") so the user can pick their WiFi and type the
# password from their phone. Once they submit, NetworkManager saves the network
# and reconnects to it automatically on every future boot — the portal only
# reappears when there's no known network in range.
set -euo pipefail

PORTAL_SSID="GardenPi-Setup"

# Give NetworkManager a chance to join a remembered network first.
sleep 20

# CONNECTIVITY is "full" (internet) or "limited" (LAN only) when connected.
if nmcli -t -f CONNECTIVITY general status | grep -qE 'full|limited'; then
    echo "[wifi] already connected — setup portal not needed"
    exit 0
fi

echo "[wifi] offline — starting setup portal '$PORTAL_SSID'"
# wifi-connect blocks until the user submits credentials, then exits.
exec wifi-connect --portal-ssid "$PORTAL_SSID"
