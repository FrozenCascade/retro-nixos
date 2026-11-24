{ pkgs, ... }:
let
  # Exact tool paths for hypr/keys.lua, so the key binds never depend on PATH
  toolsLua = ''
    -- Generated from Nix: tool paths used by the key binds
    local tools = {
      brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl",
      wpctl         = "${pkgs.wireplumber}/bin/wpctl",
      playerctl     = "${pkgs.playerctl}/bin/playerctl",
      rfkill        = "${pkgs.util-linux}/bin/rfkill",
    }

  '';
in
{
  # loaded by hypr/hardware-keys.lua
  xdg.configFile."hypr/keys.lua".text = toolsLua + builtins.readFile ./hypr/keys.lua;
}
