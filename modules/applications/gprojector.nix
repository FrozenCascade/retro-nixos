{ pkgs, ... }:

# NASA's G.Projector (map projections). It is not packaged in nixpkgs, so this runs the program from its own
# folder, the one the .tgz from NASA GISS unpacks to. Put that folder (it holds `jars/` and `sample_maps/`) at `dir`:
#   mkdir -p ~/Applications && tar -xzf ~/Downloads/G.ProjectorJ-*.tgz -C ~/Applications
# It is a Java program and needs X11, which Hyprland provides through XWayland. Its memory limits are the ones from
# the program's own gprojector.sh.
let
  dir = "$HOME/Applications/G.ProjectorJ";                  # change this if you keep the folder elsewhere

  launcher = pkgs.writeShellScriptBin "gprojector" ''
    if [ ! -f "${dir}/jars/G.Projector.jar" ]; then
      ${pkgs.libnotify}/bin/notify-send "G.Projector" "Unpack the program into ${dir}"
      exit 1
    fi
    export _JAVA_AWT_WM_NONREPARENTING=1      # Java windows misbehave on tiling window managers without this
    exec ${pkgs.jre}/bin/java -Xms512m -Xmx2000m -jar "${dir}/jars/G.Projector.jar" "$@"
  '';
in
{
  environment.systemPackages = [
    launcher
    (pkgs.makeDesktopItem {
      name = "gprojector";
      desktopName = "G.Projector";
      comment = "Map projections";
      exec = "gprojector %F";
      icon = "kimagemapeditor";
      categories = [ "Graphics" "Science" ];
    })
  ];
}
