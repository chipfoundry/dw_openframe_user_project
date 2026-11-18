{
  description = "Double Wide Openframe user project - sky130 user-area design hardened with LibreLane 2";

  nixConfig = {
    extra-substituters = [
      "https://nix-cache.fossi-foundation.org"
    ];
    extra-trusted-public-keys = [
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs="
    ];
  };

  inputs = {
    # The same LibreLane 2 release (2.4.6) that hardens openframe_user_project
    # and every other ChipFoundry project type. `cf harden` enters this
    # flake's default devShell to run it.
    librelane.url = "github:chipfoundry/openlane-2/CI2511";
  };

  outputs =
    { librelane, ... }:
    {
      devShells = librelane.devShells;
    };
}
