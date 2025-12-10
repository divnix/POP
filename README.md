# POP: Pure Object Prototypes

POP is a prototype object system for Nix with multiple inheritance.
POP is intended as an upgrade to the various "extension systems" of Nix.
Indeed, the extension systems of Nix are actually equivalent to each other and
to Jsonnet's builtin prototype object system,
that have mixin inheritance but in practice are used mostly or only for single inheritance.

See [POP.md](POP.md) for an explanation of this object system's design.
The [source code](POP.nix) is also heavily commented.
The concepts are also explained in the Scheme and Functional Programming Workshop 2021 article
[Prototype Object Orientation Functionally](https://github.com/metareflection/poof)
[(PDF)](http://fare.tunes.org/files/cs/poof.pdf).
Regarding the non-adoption of POP in nixpkgs, see discussion on
[PR #116275](https://github.com/NixOS/nixpkgs/pull/116275).

This code was initially lifted from the
[MuKn.io nixpkgs fork](https://github.com/MuKnIO/nixpkgs/blob/devel/lib/pop.nix),
where it is used for
[Gerbil support](https://github.com/MuKnIO/nixpkgs/blob/devel/pkgs/development/compilers/gerbil/gerbil-support.nix)
and the [packaging of Glow](https://gitlab.com/mukn/glow/-/blob/master/pkgs.nix).
It was since reformatted with [alejandra](https://github.com/kamadorueda/alejandra).

To run the tests:
```bash
nix flake check
```
