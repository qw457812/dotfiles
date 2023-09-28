#!/bin/bash

# # https://github.com/FelixKratz/SketchyBar/discussions/12?sort=new#discussioncomment-5297228
# # super simple but still quite useful: an homebrew package update tracker. shows the number of outdated packages.
# outdated=$(brew outdated --quiet | wc -l | tr -d " ")
# # threshold=30
# threshold=0
#
# # only show menubar item above threshold
# if [[ $outdated -gt $threshold ]] ; then
# 	label="$outdated" 
# 	icon="🍺 "	
# fi
#
# sketchybar --set "$NAME" icon="$icon" label="$label"

source "$CONFIG_DIR/colors.sh"

COUNT="$(brew outdated | wc -l | tr -d ' ')"

DRAWING=on

COLOR=$RED

case "$COUNT" in
  [3-5][0-9]) COLOR=$ORANGE
  ;;
  [1-2][0-9]) COLOR=$YELLOW
  ;;
  [1-9]) COLOR=$WHITE
  ;;
  0) COLOR=$GREEN
     COUNT=􀆅
     DRAWING=off
  ;;
esac

sketchybar --set $NAME drawing=$DRAWING label=$COUNT icon.color=$COLOR
