#!/usr/bin/env zsh

# https://github.com/zegervdv/homebrew-zathura/issues/62#issuecomment-1413968157

function last_window_id() {
  local app=$1
  id=$(yabai -m query --windows | jq -e "map(select(.app==\"$app\")) | .[0] | .id") && echo $id
}

function focus_last_window_id() {
  local app=$1
  id=$(last_window_id $app) && yabai -m window --focus $id
}

focus_last_window_id $@
