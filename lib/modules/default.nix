{ lib }:
{
  mkJailTmpfiles = import ./mk-jail-tmpfiles.nix { inherit lib; };
}
