{
  system ? builtins.currentSystem,
  inputs ? (import ./.).inputs,
}: let
  inherit (inputs) POP nixlib nixpkgs;
  lib = nixlib.lib // POP.lib;
  inherit (lib) pop unpop;
  pkgs = nixpkgs.legacyPackages.${system};
  tests = lib.runTests {
    testInstantiation = {
      expr = unpop (pop {
        defaults.a = 5;
        extension = self: super: {a = super.a + 1;};
      });
      expected = {
        a = 6;
      };
    };
    testInheritance = {
      expr = let
        a = pop {defaults.package = pkgs.vim;};
        b = pop {
          extension = self: super: {
            nvim = pkgs.neovim;
            package = self.nvim;
          };
        };
      in
        unpop (pop {supers = [a b];});
      expected = {
        nvim = pkgs.neovim;
        package = pkgs.neovim;
      };
    };
    testMultipleInheritance =
      let O = pop {name="O"; supers=[];};
          A = pop {name="A"; supers=[O];};
          B = pop {name="B"; supers=[O];};
          C = pop {name="C"; supers=[O];};
          D = pop {name="D"; supers=[O];};
          E = pop {name="E"; supers=[O];};
          K1 = pop {name="K1"; supers=[A B C];};
          K2 = pop {name="K2"; supers=[D B E];};
          K3 = pop {name="K3"; supers=[D A];};
          Z = pop {name="Z"; supers=[K1 K2 K3];};
          precedenceListNames = self: map (super: super.name) self.__meta__.precedenceList;
          in
    { expr = map precedenceListNames [O A B C D E K1 K2 K3 Z];
      expected = [ ["O"] ["A" "O"] ["B" "O"] ["C" "O"] ["D" "O"] ["E" "O"]
                   ["K1" "A" "B" "C" "O"] ["K2" "D" "B" "E" "O"] ["K3" "D" "A" "O"]
                   ["Z" "D" "A" "B" "C" "E" "O"] ];
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
