{ pkgs, ... }:

# Drawing, vector graphics and video editing.
{
  environment.systemPackages = with pkgs; [
    krita
    inkscape-with-extensions    # Inkscape plus its import/export extensions
    kdePackages.kdenlive
  ];
}
