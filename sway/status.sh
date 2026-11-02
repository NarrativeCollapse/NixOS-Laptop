# swaybar status line: battery, then date and time. Updates every 30s.
while :; do
  bat=""
  for b in /sys/class/power_supply/BAT*; do
    [ -r "$b/capacity" ] && bat="$bat$(cat "$b/capacity")% $(cat "$b/status")  |  "
  done
  printf '%s%s\n' "$bat" "$(date '+%a %d %b  %H:%M')"
  sleep 30
done
