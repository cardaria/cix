let
  draba = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./draba.pub);
in
{
  "codex-lb.age" = {
    publicKeys = [ draba ];
    armor = true;
  };
}
