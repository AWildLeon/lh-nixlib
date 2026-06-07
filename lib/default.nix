{ lib }:
{
  modules = import ./modules { inherit lib; };
}
