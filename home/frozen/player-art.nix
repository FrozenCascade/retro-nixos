{ pkgs, ... }:

# yt-dlp on the normal PATH. The shell's ArtLookup singleton uses it to find the thumbnail of a YouTube
# tab that the browser reports without artwork.
{
  home.packages = [ pkgs.yt-dlp ];
}
