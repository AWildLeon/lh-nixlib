_: {
  perSystem =
    { pkgs, pkgsUnstable, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixd
          nixfmt
          ripgrep
          pkgsUnstable.mcp-nixos
        ];
      };
    };
}
