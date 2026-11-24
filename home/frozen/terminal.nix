{ config, lib, pkgs, ... }:

# Terminal programs: kitty itself, the programs that run in it (htop, mpv, theclicker) and their launcher
# entries. Colours and the font come from Stylix; this file holds everything else.
# To add a program that opens in the terminal: one line in `apps` below.
let
  # ---- settings (edit here) ----
  fontSize = 11;                  # kitty's text size (the rest of the system keeps its own)
  blinkSeconds = "0.55";           # the cursor appearing and disappearing; bigger = slower
  opacity = 0.9;                  # kitty's background; 1.0 = solid. Text stays fully visible.

  # programs that open in their own kitty window: id (the desktop file name) -> what to show
  apps = {
    theclicker = {
      name = "TheClicker";
      comment = "Autoclicker for the terminal";
      command = "theclicker";
      icon = "input-mouse";
      hold = true;               # keep the window open after it exits, so an error stays readable
    };
    htop = {
      name = "Htop";
      comment = "Watch processes, memory and CPU";
      command = "htop";
      icon = "utilities-system-monitor";
    };
  };

  # one launcher entry: a kitty window named after the app (so the bar and window rules can tell it apart)
  terminalEntry = id: app: {
    name = app.name;
    genericName = "Terminal Program";
    comment = app.comment;
    exec = "kitty ${lib.optionalString (app.hold or false) "--hold "}--class ${id} --title ${app.name} ${app.command}";
    icon = app.icon;
    categories = [ "System" "Utility" ];
    settings.StartupWMClass = id;
  };
in
{
  # ---- kitty ----
  stylix.opacity.terminal = opacity;
  stylix.fonts.sizes.terminal = fontSize;

  programs.kitty = {
    enable = true;
    settings = {
      # cursor: a thin bar that blinks softly for a while and leaves a short trail when it jumps
      cursor_shape = "beam";
      cursor_beam_thickness = "1.5";
      cursor_blink_interval = "${blinkSeconds} ease-in-out";
      cursor_stop_blinking_after = "15.0";
      cursor_trail = 3;                    # needs kitty 0.37 or newer; 0 turns the trail off
      cursor_trail_decay = "0.04 0.2";             # how fast the trail fades: lower is quicker
      cursor_trail_start_threshold = 2;

      # look
      repaint_delay = 6;                   # ms between redraws (default 10): smoother and snappier
      input_delay = 1;
      window_padding_width = 12;
      dynamic_background_opacity = true;   # Ctrl+Shift+A then M or L changes the transparency while running
      url_style = "curly";

      # behaviour
      scrollback_lines = 20000;
      mouse_hide_wait = "2.0";
      copy_on_select = "clipboard";
      enable_audio_bell = false;
      confirm_os_window_close = 0;
    };
  };

  # ---- htop ----
  programs.htop = {
    enable = true;
    settings = {
      tree_view = true;
      hide_kernel_threads = true;
      highlight_base_name = true;
      show_cpu_frequency = true;
      show_program_path = false;
    };
  };

  # ---- mpv ----
  # The MPRIS script makes mpv show up in the Studio window and on the bar like any other player.
  programs.mpv = {
    enable = true;
    scripts = [ pkgs.mpvScripts.mpris ];
    config = {
      vo = "gpu-next";
      gpu-context = "wayland";
      hwdec = "auto-safe";
      keep-open = true;                    # stay on the last frame instead of closing
      save-position-on-quit = true;
      osd-font-size = 28;
    };
  };

  # ---- launcher entries ----
  xdg.desktopEntries =
    (lib.mapAttrs terminalEntry apps)
    // {
      # mpv is a window program, so it needs no kitty; this replaces the package's entry with a plain "MPV"
      mpv = {
        name = "MPV";
        genericName = "Media Player";
        comment = "Play videos and music";
        exec = "mpv --player-operation-mode=pseudo-gui -- %U";
        icon = "mpv";
        categories = [ "AudioVideo" "Audio" "Video" "Player" ];
        mimeType = [ "video/mp4" "video/x-matroska" "video/webm" "audio/mpeg" "audio/flac" "audio/ogg" ];
        settings.StartupWMClass = "mpv";
      };
    };
}
