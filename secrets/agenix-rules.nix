let
  draba = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./draba.pub);
in
{
  "smb-cloud.age" = {
    publicKeys = [ draba ];
    armor = true;
  };
}
