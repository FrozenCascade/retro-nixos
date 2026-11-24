# studio-download: yt-dlp for the DOWNLOAD tab of the Studio window
#   studio-download <yt-dlp arguments>      downloads (the tab builds the arguments, see StudioDownloader.qml)
#   studio-download paste                   prints the clipboard
#   studio-download notify <title> [text]   a notification
#   studio-download open <folder>           opens a folder in the file manager (made if missing)
# The tools it needs are put on PATH by studio.nix.
set -u

case ${1:-} in
  paste)  exec wl-paste --no-newline ;;
  notify) shift; exec notify-send --app-name=Download --icon=folder-download "$@" ;;
  open)   mkdir -p "${2:?}"; exec xdg-open "$2" ;;
esac

exec yt-dlp "$@"
