{ ... }:
{
  # A tap on the power button does nothing, holding it powers off.
  # Hyprland binds the tap to the lock screen (home/frozen/hypr/keys.lua).
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
  };
}
