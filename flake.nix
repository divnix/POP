{
  inputs.nixlib.url = "github:nix-community/nixpkgs.lib";
  outputs = {
    self,
    nixlib,
  }: let
    lib = nixlib.lib.extend (self: super: import ./attrsets.nix {lib = self;});
  in
    import ./POP.nix {inherit lib;};
}
