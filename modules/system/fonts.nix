{ pkgs, ... }:

# Fallback fonts. When a font has no glyph for a character, apps (Vivaldi, Quickshell, kitty) ask fontconfig for
# any installed font that has it, so more installed fonts means fewer empty boxes. Nothing to select anywhere.
# Which installed font covers a character:   fc-list ":charset=10454" family     (10454 = U+10454, hex)
{
  fonts.packages = with pkgs; [
    noto-fonts        # nearly every script, as proper outline fonts (includes Shavian)
    unifont           # the last resort: one plain glyph for almost every character in the Basic Multilingual Plane
    unifont_upper     # the same for the rest of Unicode (Shavian and other scripts above U+FFFF, and symbols)
  ];
}
