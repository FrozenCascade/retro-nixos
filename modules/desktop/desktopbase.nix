{ ... }:

{
  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "us,qalbagutic";
    variant = ",qa";
    options = "compose:rctrl";

    extraLayouts.qalbagutic = {
      description = "English with Qalbagutic on Right Alt";
      languages = [ "eng" ];
      symbolsFile = ./keyboard/qalbagutic;
    };
  };

  services.displayManager.sddm.enable = true;
  services.upower.enable = true;
}
