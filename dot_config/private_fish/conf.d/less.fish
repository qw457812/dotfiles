status is-interactive; or exit

set -x LESS '--RAW-CONTROL-CHARS --ignore-case --LONG-PROMPT --chop-long-lines --incsearch --use-color --tabs=4 --intr=c$ --save-marks --status-line'

# set -x LESSOPEN "|/opt/homebrew/bin/lesspipe.sh %s"
type -q batpipe; and eval (batpipe)
