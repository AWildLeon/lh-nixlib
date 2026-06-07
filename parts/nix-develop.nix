_: {
  perSystem =
    { pkgs, pkgsUnstable, ... }:
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixd
          nixfmt-rfc-style
          ripgrep
          pkgsUnstable.mcp-nixos
        ];
      };
    };
}
