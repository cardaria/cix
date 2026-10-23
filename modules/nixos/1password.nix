{
  # System wrappers for browser and CLI integration
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "cardaria" ];
  };
}
