{ dotfile, ... }:
{
  # Pages are saved by rename, so link the directory; only overview.page is tracked
  xdg.dataFile."plasma-systemmonitor".source = dotfile "plasma-systemmonitor";
}
