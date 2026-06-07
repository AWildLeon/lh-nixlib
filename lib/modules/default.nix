{ lib }:
{
  mkJailTmpfiles = import ./mkJailTmpfiles.nix { inherit lib; };
}
