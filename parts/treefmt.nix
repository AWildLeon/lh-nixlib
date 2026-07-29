_: {
  perSystem.treefmt = _: {
    programs = {
      shellcheck = {
        enable = true;
      };
      shfmt = {
        enable = true;
      };
      nixfmt = {
        enable = true;
      };
      prettier = {
        enable = true;
      };
      statix = {
        enable = true;
      };
      deadnix = {
        enable = true;
        no-lambda-pattern-names = true;
      };
    };
  };
}
