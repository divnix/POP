{
  inputs.nixlib.url = "github:nix-community/nixpkgs.lib";

  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };

  # Development Dependencies
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixlib,
    nixpkgs,
    ...
  }: let
    lib = nixlib.lib.extend (self: super: import ./attrsets.nix {lib = self;});

    supportedSystems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin"];
    # Pass this flake(self) as "POP"
    polyfillInputs = self.inputs // {POP = self;};
    polyfillOutput = loc:
      nixlib.lib.genAttrs supportedSystems (system:
        import loc {
          inherit system;
          inputs = polyfillInputs;
        });
  in {
    lib = import ./POP.nix {inherit lib;};
    checks = polyfillOutput ./checks.nix;
    formatter = nixlib.lib.genAttrs supportedSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
