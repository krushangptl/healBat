#!/bin/bash

# --- to display things via zenity with the help of X ---
export DISPLAY=:0
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

# Directory & log file setup
LOG_DIR="$HOME/.battery_health"
LOG_FILE="$LOG_DIR/battery_health.log"

TODAY="$(date +"%Y-%m-%d")"
YESTERDAY="$(date -d "yesterday" +"%Y-%m-%d")"
BAT_INFO=$(upower -i $(upower -e | grep BAT))

mkdir -p "$LOG_DIR"

# --- Data extraction ---
CHARGE_PER=$(echo "$BAT_INFO" | grep "percentage" | awk '{print $2}' | tr -d '%')
ENERGY_FULL=$(echo "$BAT_INFO" | grep "energy-full:" | awk '{print $2}' | tr -d '[:alpha:]')
ENERGY_DESIGN=$(echo "$BAT_INFO" | grep "energy-full-design" | awk '{print $2}' | tr -d '[:alpha:]')
BAT_STATE=$(echo "$BAT_INFO" | awk -F: '/state/ {gsub(/ /,"",$2); print $2}')

# --- Validate numeric values ---
if [[ -z "$ENERGY_FULL" || -z "$ENERGY_DESIGN" ]]; then
    echo "Error: Unable to read energy values from upower output"
    exit 1
fi

HEALTH=$(echo "scale=2; ($ENERGY_FULL/$ENERGY_DESIGN)*100" | bc)

# --- Alerts for charge based on state ---
# Low battery: only if discharging
if (( $(echo "$CHARGE_PER < 20" | bc -l) )) && [[ "$BAT_STATE" == "discharging" ]]; then
  zenity --warning --title="Battery Low" --text="Charge is at ${CHARGE_PER}% — please plug in!"
  paplay /usr/share/sounds/freedesktop/stereo/complete.oga
fi

# High battery: only if charging
if (( $(echo "$CHARGE_PER > 80" | bc -l) )) && [[ "$BAT_STATE" == "charging" ]]; then
  zenity --info --title="Battery High" --text="Charge is at ${CHARGE_PER}% — consider unplugging to preserve health."
  paplay /usr/share/sounds/freedesktop/stereo/complete.oga
fi

# --- Log today's data ---
echo "$TODAY | Charge: ${CHARGE_PER}% | Full: ${ENERGY_FULL} Wh | Design: ${ENERGY_DESIGN} Wh | Health: ${HEALTH}%" >> "$LOG_FILE"

# --- Compare with yesterday ---
YESTERDAY_LINE=$(grep "$YESTERDAY" "$LOG_FILE" 2>/dev/null | tail -n 1)

if [ -n "$YESTERDAY_LINE" ]; then
  YESTERDAY_HEALTH=$(echo "$YESTERDAY_LINE" | awk -F'|' '{print $5}' | grep -o "[0-9.]*")
  if [[ -n "$YESTERDAY_HEALTH" && $(echo "$HEALTH < $YESTERDAY_HEALTH" | bc -l) -eq 1 ]]; then
    LOSS=$(echo "scale=2; $YESTERDAY_HEALTH - $HEALTH" | bc)
    zenity --warning --title="Battery Health Drop" --text="Health decreased by ${LOSS}% since yesterday (Now: ${HEALTH}%)"
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga
  fi
fi

