# Green Curve: VF-curve undervolt, overclock and fan control through a root daemon
{ cixPkgs, ... }:
{
  environment.systemPackages = [ cixPkgs.greencurve ];
  systemd.packages = [ cixPkgs.greencurve ];

  # NixOS ignores the [Install] sections of packaged units
  systemd.services.greencurve.wantedBy = [ "multi-user.target" ];
  systemd.services.greencurve-resume.wantedBy = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];

  # The daemon socket's group; members tune clocks, voltage and fans, not CUDA access
  users.groups.greencurve = { };
  users.users.cardaria.extraGroups = [ "greencurve" ];
}
