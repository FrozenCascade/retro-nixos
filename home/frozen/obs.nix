{ pkgs, ... }:

# OBS Studio. Screen capture on Hyprland: add a "Screen Capture (PipeWire)" source, or "Window Capture (PipeWire)".
# The plugins add capturing a single app's audio and the wlroots screen source.
{
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-pipewire-audio-capture
      wlrobs
    ];
  };
}
