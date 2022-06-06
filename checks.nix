{
  system ? builtins.currentSystem,
  inputs ? (import ./.).inputs,
}: let
  inherit (inputs) POP nixlib nixpkgs;
  lib = nixlib.lib // POP.lib;
  pkgs = nixpkgs.legacyPackages.${system};
  tests = lib.runTests {
    testInstantiation = {
      expr = lib.unpop (lib.pop {
        defaults.a = 5;
        extension = self: super: {a = super.a + 1;};
      });
      expected = {
        a = 6;
      };
    };
    testInheritence = {
      expr = let
        a = lib.pop {defaults.package = pkgs.vim;};
        b = lib.pop {
          extension = self: super: {
            nvim = pkgs.neovim;
            package = self.nvim;
          };
        };
      in
        lib.unpop (lib.pop {supers = [a b];});
      expected = {
        nvim = pkgs.neovim;
        package = pkgs.neovim;
      };
    };
  };
in {
  libTests =
    pkgs.runCommandNoCC "POP-lib-tests"
    {
      buildInputs = [
        (
          if tests == []
          then null
          else throw (builtins.toJSON tests)
        )
      ];
    } ''
      touch $out
    '';
}
