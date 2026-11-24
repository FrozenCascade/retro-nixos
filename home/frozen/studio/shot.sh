# studio-shot: screenshots for the Studio window and the Print keys
#   studio-shot capture <region|window|screen|monitor|MONITOR NAME> [delay in seconds] [x,y wxh]
#                       the Studio window chooses the area and passes it as the last argument
#   studio-shot window  prints the geometry of a window you point at (slurp)
#   studio-shot save | saveas | annotate   act on the last capture (saveas asks where; annotate opens the editor)
#   studio-shot import [file]         makes an image the last capture (asks which when no file is given)
#   studio-shot backup                keeps an untouched copy of the last capture for the editor's REVERT
# A capture is copied to the clipboard and kept in $XDG_RUNTIME_DIR/studio/last.png until it is saved.
# Exit codes: 0 done, 1 cancelled in slurp, 2 bad arguments, 3 a tool failed (the reason is on stderr).
# The tools it needs are put on PATH by studio.nix.
set -u

dir="${XDG_RUNTIME_DIR:-/tmp}/studio"
last="$dir/last.png"
orig="$dir/original.png"                    # the untouched copy the editor can revert to
shots="$HOME/Pictures/Screenshots"          # where SAVE puts things
mkdir -p "$dir"

# the windows you can see right now, as "x,y wxh" lines for slurp to pick from
windows() {
  local shown
  shown=$(hyprctl -j monitors | jq -c '[.[].activeWorkspace.id]')
  hyprctl -j clients | jq -r --argjson shown "$shown" \
    '.[] | select(.mapped and (.hidden | not) and (.workspace.id as $w | $shown | index($w)))
         | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
}

save() {
  [ -f "$last" ] || exit 1
  mkdir -p "$shots"
  local out
  out="$shots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
  cp "$last" "$out"
  notify-send --app-name=Screenshot --icon="$out" "Screenshot saved" "$out"
  echo "$out"
}

# SAVE, but you choose where
saveas() {
  [ -f "$last" ] || exit 1
  mkdir -p "$shots"
  local out
  out=$(kdialog --getsavefilename "$shots/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png" "*.png|PNG image") || exit 1
  case $out in *.png) ;; *) out="$out.png" ;; esac
  cp "$last" "$out"
  notify-send --app-name=Screenshot --icon="$out" "Screenshot saved" "$out"
  echo "$out"
}

# the editor is part of the Studio window's shell: ask it to open
annotate() {
  [ -f "$last" ] || exit 1
  exec qs ipc call studio annotate
}

# the editor keeps the first version of a capture, so REVERT can come back to it
backup() {
  [ -f "$last" ] || exit 1
  [ -f "$orig" ] || cp "$last" "$orig"
}

# any image (png, jpg, webp, ...) becomes the last capture, as a png
import_image() {
  local src=${1:-}
  if [ -z "$src" ]; then
    # patterns, not "image/*": kdialog takes that as a file name filter and shows nothing
    src=$(kdialog --getopenfilename "$HOME/Pictures" $'*.png *.jpg *.jpeg *.webp *.bmp *.gif *.tif *.tiff *.avif|Images\n*|All files') || exit 1
  fi
  magick "${src}[0]" "$last" || { echo "could not read $src" >&2; exit 3; }
  rm -f "$orig"
  echo "$last"
}

# the notification after a capture: SAVE and ANNOTATE are buttons on it (it runs on its own, so the
# caller is not kept waiting)
offer_actions() {
  local action
  action=$(notify-send --app-name=Screenshot --icon="$last" --wait \
    --action=save=SAVE --action=annotate=ANNOTATE \
    "Screenshot copied" "It is on the clipboard.") || return 0
  case $action in
    save) save ;;
    annotate) annotate ;;
  esac
}

capture() {
  local mode=${1:-region} delay=${2:-0} geom=${3:-} output=""
  case $mode in
    region)  [ -n "$geom" ] || geom=$(slurp </dev/null) || exit 1 ;;     # slurp only when no area was passed; Escape cancels
    window)  [ -n "$geom" ] || geom=$(windows | slurp -r) || exit 1 ;;
    monitor) output=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name') ;;
    screen)  geom="" ;;
    *)       output=$mode ;;                                              # anything else is a monitor's name
  esac

  rm -f "$orig"                       # a new capture: the old untouched copy no longer applies

  # the delay starts after you have chosen the area
  if [ "$delay" -gt 0 ]; then sleep "$delay"; fi

  if [ -n "$geom" ]; then
    grim -g "$geom" "$last"
  elif [ -n "$output" ]; then
    grim -o "$output" "$last"
  else
    grim "$last"
  fi || { echo "grim could not capture" >&2; exit 3; }

  # wl-copy stays running in the background to serve the clipboard. It must not keep our output open,
  # or the caller never sees this script finish.
  wl-copy < "$last" >/dev/null 2>&1 || { echo "wl-copy failed" >&2; exit 3; }
  echo "$last"
  offer_actions >/dev/null 2>&1 &
  disown
}

case ${1:-} in
  capture)  capture "${2:-region}" "${3:-0}" "${4:-}" ;;
  window)   windows | slurp -r ;;
  save)     save ;;
  saveas)   saveas ;;
  annotate) annotate ;;
  backup)   backup ;;
  import)   import_image "${2:-}" ;;
  *) echo "usage: studio-shot capture <region|window|screen|monitor|name> [delay] [x,y wxh] | window | save | annotate" >&2; exit 2 ;;
esac
