{ dotfile, ... }:
{
  fonts.fontconfig.enable = true;
  # Consistent spacing metadata for every Berkeley Mono face
  xdg.configFile."fontconfig/conf.d/90-berkeley-mono.conf".source =
    dotfile "fontconfig/berkeley-mono.conf";
}
