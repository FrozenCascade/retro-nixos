{ lib, ... }:

# fastfetch: the layout is the file fastfetch/config.json (edit the rows there), the logo is
# fastfetch/saturn.txt. Without the logo file it shows fastfetch's built-in logo instead.
let
  layout = builtins.fromJSON (builtins.readFile ./fastfetch/config.json);
  logoFile = ./fastfetch/saturn.txt;
in
{
  programs.fastfetch = {
    enable = true;
    settings = layout // {
      logo =
        if builtins.pathExists logoFile
        then layout.logo // { source = "${logoFile}"; }
        else { type = "builtin"; };
    };
  };
}
