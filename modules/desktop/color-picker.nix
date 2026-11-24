{ pkgs, ... }:

# The screen color picker behind the PICK button in Studio's CAPTURE tab
# (quickshell/components/bar/studio/ColorPickRow.qml). hyprpicker lets you click any pixel and puts
# its hex code on the clipboard, through wl-clipboard.
{
  environment.systemPackages = [ pkgs.hyprpicker ];
}
