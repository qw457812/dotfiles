#!/bin/sh

PERCENTAGE=$(memory_pressure | grep "System-wide memory free percentage:" | awk '{ printf("%02.0f\n", 100-$5"%") }')

DRAWING=on
case ${PERCENTAGE} in
  9[0-9]|100)
  ;;
  [6-8][0-9])
  ;;
  [3-5][0-9])
  ;;
  [1-2][0-9])
  ;;
  *) DRAWING=off
esac

sketchybar --set "$NAME" drawing=$DRAWING label="${PERCENTAGE}%"
