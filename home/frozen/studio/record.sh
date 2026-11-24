# studio-record: screen recording for the Studio window (gpu-screen-recorder)
#   studio-record start <region|screen|monitor name> <fps> [audio devices joined with |] [x,y wxh]
#                       for region the Studio window passes the area as the last argument
#                       records until it gets SIGINT (the Studio window sends it); prints "recording" once going
#   studio-record finished    a notification for the last recording, with SAVE and DISCARD on it
#   studio-record save | saveas | discard      (saveas asks where to put it)
# A recording is kept in ~/.cache/studio/last.mp4 and is NOT saved anywhere until you say so.
# The tools it needs are put on PATH by studio.nix.
set -u

cache="${XDG_CACHE_HOME:-$HOME/.cache}/studio"
last="$cache/last.mp4"
videos="$HOME/Videos/Recordings"            # where SAVE puts things
mkdir -p "$cache"

# "x,y wxh" (how slurp and grim write an area) -> "WxH+X+Y" (how the recorder wants it)
region_arg() {
  local pos=${1% *} size=${1#* }
  echo "${size}+${pos%,*}+${pos#*,}"
}

start() {
  local target=${1:?} fps=${2:-60} audio=${3:-} geom=${4:-}
  local args=()
  if [ "$target" = region ]; then
    [ -n "$geom" ] || geom=$(slurp -f '%x,%y %wx%h') || exit 1   # slurp only when no area was passed; Escape cancels
    args+=(-w region -region "$(region_arg "$geom")")
  else
    args+=(-w "$target")
  fi
  if [ -n "$audio" ]; then args+=(-a "$audio"); fi
  rm -f "$last"

  gpu-screen-recorder "${args[@]}" -f "$fps" -fallback-cpu-encoding yes -c mp4 -o "$last" 2>"$cache/record.err" &
  local pid=$!
  trap 'kill -INT "$pid" 2>/dev/null' INT TERM        # the Studio window stops a recording with SIGINT

  # say "recording" only once the recorder has really started, and pass its error on if it has not
  sleep 1
  if ! kill -0 "$pid" 2>/dev/null; then
    tail -n 3 "$cache/record.err" >&2
    exit 3
  fi
  echo recording
  while kill -0 "$pid" 2>/dev/null; do wait "$pid"; done
}

save() {
  [ -s "$last" ] || exit 1
  mkdir -p "$videos"
  local out
  out="$videos/Recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
  mv "$last" "$out"
  notify-send --app-name=Recorder --icon=video-x-generic "Recording saved" "$out"
  echo "$out"
}

# SAVE, but you choose where
saveas() {
  [ -s "$last" ] || exit 1
  mkdir -p "$videos"
  local out
  out=$(kdialog --getsavefilename "$videos/Recording_$(date +%Y-%m-%d_%H-%M-%S).mp4" "*.mp4|MP4 video") || exit 1
  case $out in *.mp4) ;; *) out="$out.mp4" ;; esac
  mv "$last" "$out"
  notify-send --app-name=Recorder --icon=video-x-generic "Recording saved" "$out"
  echo "$out"
}

preview() {
  local file=${1:-$last}
  [ -s "$file" ] || exit 1
  exec mpv --no-terminal --title=qs-preview --force-window=yes --keep-open=yes --autofit=60% "$file"
}

discard() {
  rm -f "$last"
}

finished() {
  [ -s "$last" ] || exit 1
  local action
  action=$(notify-send --app-name=Recorder --icon=media-record --wait \
    --action=save=SAVE --action=discard=DISCARD \
    "Recording finished" "It is not saved yet.") || exit 0
  case $action in
    save) save ;;
    discard) discard ;;
  esac
}

case ${1:-} in
  start)    start "${2:-}" "${3:-60}" "${4:-}" "${5:-}" ;;
  finished) finished >/dev/null 2>&1 ;;
  save)     save ;;
  saveas)   saveas ;;
  discard)  discard ;;
  preview)  preview "${2:-}" ;;
  *) echo "usage: studio-record start <region|monitor> <fps> [audio] | finished | save | discard" >&2; exit 2 ;;
esac
