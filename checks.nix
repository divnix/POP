{
  system ? builtins.currentSystem,
  inputs ? (import ./.).inputs,
}: let
  inherit (inputs) POP nixlib nixpkgs;
  lib = nixlib.lib // POP.lib;
  inherit (lib) pop unpop isEmpty isNonEmpty removeEmpties removeNext c3selectNext PopInstantiator;
  inherit (PopInstantiator) getName getPrecedenceList;
  pkgs = nixpkgs.legacyPackages.${system};
  tests = lib.runTests {
    testFields = {
      expr = builtins.attrNames (pop {
        defaults = {
          a = 5;
          b = 2;
        };
        extension = self: super: {
          a = super.a + 1;
          c = 3;
        };
      });
      expected = ["__meta__" "a" "b" "c"];
    };
    testInstantiation = {
      expr = unpop (pop {
        defaults.a = 5;
        extension = self: super: {a = super.a + 1;};
      });
      expected = {
        a = 6;
      };
    };
    testHelpers = {
      expr = {
        emptyIsEmpty = isEmpty [];
        singletonIsEmpty = isEmpty [1];
        list4IsEmpty = isEmpty [1 2 3 4];
        emptyIsNonEmpty = isNonEmpty [];
        singletonIsNonEmpty = isNonEmpty [1];
        list4IsNonEmpty = isNonEmpty [1 2 3 4];
        testRemoveEmpties = removeEmpties [[] [1] [2 3] [] [4 [] 5] [6] [] []];
        testRemoveNext = removeNext 1 [[2 3 4] [1 2 5] [1] [1 6 7] [3 6] [1 8] [1]];
      };
      expected = {
        emptyIsEmpty = true;
        singletonIsEmpty = false;
        list4IsEmpty = false;
        emptyIsNonEmpty = false;
        singletonIsNonEmpty = true;
        list4IsNonEmpty = true;
        testRemoveEmpties = [[1] [2 3] [4 [] 5] [6]];
        testRemoveNext = [[2 3 4] [2 5] [6 7] [3 6] [8]];
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
    testMultipleInheritance = let
      O = pop {
        name = "O";
        supers = [];
      };
      A = pop {
        name = "A";
        supers = [O];
      };
      B = pop {
        name = "B";
        supers = [O];
      };
      C = pop {
        name = "C";
        supers = [O];
      };
      D = pop {
        name = "D";
        supers = [O];
      };
      E = pop {
        name = "E";
        supers = [O];
      };
      K1 = pop {
        name = "K1";
        supers = [A B C];
      };
      K2 = pop {
        name = "K2";
        supers = [D B E];
      };
      K3 = pop {
        name = "K3";
        supers = [D A];
      };
      Z = pop {
        name = "Z";
        supers = [K1 K2 K3];
      };
      precedenceListNames = self: map getName ([self] ++ getPrecedenceList self);
    in {
      expr = {
        precedence = map precedenceListNames [O A B C D E K1 K2 K3 Z];
      };
      expected = {
        precedence = [
          ["O"]
          ["A" "O"]
          ["B" "O"]
          ["C" "O"]
          ["D" "O"]
          ["E" "O"]
          ["K1" "A" "B" "C" "O"]
          ["K2" "D" "B" "E" "O"]
          ["K3" "D" "A" "O"]
          ["Z" "K1" "K2" "K3" "D" "A" "B" "C" "E" "O"]
        ];
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
          else
            throw (
              "Failed tests:\n" +
              nixlib.lib.concatStringsSep
              "\n-------------------\n"
              (
                map
                (nixlib.lib.generators.toPretty {})
                tests
              )
            )
        )
      ];
    } ''
      touch $out
    '';
}
