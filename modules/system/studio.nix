{ pkgs, ... }:

# System pieces Studio needs: screen recording and a terminal autoclicker.
{
  # gpu-screen-recorder, with the capability wrapper it needs to capture the screen on Wayland
  programs.gpu-screen-recorder.enable = true;

  # theclicker, a terminal autoclicker (run `theclicker`). It reads your mouse and clicks through /dev/uinput,
  # so your user needs the input and uinput groups (log out and in once after the rebuild).
  hardware.uinput.enable = true;
  users.users.frozen.extraGroups = [ "input" "uinput" ];
  environment.systemPackages = [ pkgs.theclicker ];

  # Intel Iris Xe: the VA-API driver gpu-screen-recorder uses for hardware video encoding
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
}
