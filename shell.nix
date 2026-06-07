# Woraround for Legacy nix-shell
(builtins.getFlake (toString ./.)).devShells.${builtins.currentSystem}.default
