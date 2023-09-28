#!/bin/sh

# PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
# CHARGING=$(pmset -g batt | grep 'AC Power')
#
# if [ $PERCENTAGE = "" ]; then
#   exit 0
# fi
#
# case ${PERCENTAGE} in
#   9[0-9]|100) ICON=""
#   ;;
#   [6-8][0-9]) ICON=""
#   ;;
#   [3-5][0-9]) ICON=""
#   ;;
#   [1-2][0-9]) ICON=""
#   ;;
#   *) ICON=""
# esac
#
# if [[ $CHARGING != "" ]]; then
#   ICON=""
# fi
#
# # The item invoking this script (name $NAME) will get its icon and label
# # updated with the current battery status
# sketchybar --set $NAME icon="$ICON" label="${PERCENTAGE}%"

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(echo "$BATTERY_INFO" | grep 'AC Power')

if [ $PERCENTAGE = "" ]; then
  exit 0
fi

DRAWING=on
COLOR=$WHITE
case ${PERCENTAGE} in
  9[0-9]|100) ICON=$BATTERY_100; DRAWING=off
  ;;
  [6-8][0-9]) ICON=$BATTERY_75; DRAWING=off
  ;;
  [3-5][0-9]) ICON=$BATTERY_50
  ;;
  [1-2][0-9]) ICON=$BATTERY_25; COLOR=$ORANGE
  ;;
  *) ICON=$BATTERY_0; COLOR=$RED
esac

if [[ $CHARGING != "" ]]; then
  ICON=$BATTERY_CHARGING
  DRAWING=off
fi

# sketchybar --set $NAME drawing=$DRAWING icon="$ICON" icon.color=$COLOR
sketchybar --set $NAME drawing=$DRAWING icon="$ICON" icon.color=$COLOR label="${PERCENTAGE}%" label.color=$COLOR
