# POP: Pure Object Prototypes
# See pop.md for an explanation of this object system's design.
#
# Previous versions of this code were used by pkgs/development/compilers/gerbil/gerbil-support.nix
# and the extensions at https://gitlab.com/mukn/glow/-/blob/master/pkgs.nix but no more due to
# lib.POP having been rejected from the nixpkgs standard library:
# https://github.com/NixOS/nixpkgs/pull/116275
# https://github.com/NixOS/rfcs/pull/91
# https://github.com/NixOS/rfcs/pull/82
#
{lib, ...}: rec {
  /*
  First, let's define, name and type the basic notions involved in
  single, mixin and multiple inheritance:
  - Given a type M for module context and V for a target value,
    a *modular definition* is a function M → V.
    This is the type of specifications in single inheritance,
    as seen in Nixpkgs's `fixed-points.nix` and `customization.nix`.
  - A *closed modular definition* is one in which M=V, at which point you can extract
    a module value via the fixed-point operator `lib.fixedPoints.fix`.
  - Given a type M for module context, V for input target value and W for output target value,
    a *modular extension* is a function M → V → W.
    This is the type of specifications in mixin inheritance,
    only slightly more general than the extensions of `lib.fixedPoints`.
    You also need a modular extension to extend a modular definition in single inheritance,
    so single inheritance is actually more complex than multiple inheritance
    (at least once you express them in terms of higher-order functions).
  - a *strict modular extension* is a modular extension such that W ⊂ V (a subtype).
    Obviously any partial function is strict with respect to the Any type,
    and no non-identity function is strict with respect to a singleton type,
    therefore being strict or not depends on what type declaration you have for V.
  - a *closed modular extension* is one in which M=V=W, at which point you can extract
    a module value via `fixMExt` below, starting from an initial value
    (rather than an initial modular definition).
  - a *multiple inheritance specification* (MISpec) is the data of
    a modular extension,
    a list of parent specifications,
    an identity for the specification as a node in the inheritance DAG of specification.
    This is the type of specifications in multiple inheritance.
    You can extract an attrset from a multiple inheritance specification with `fixMISpec`.
  - a *prototype* is an attrset that contains both a target and its specification.
    As an optimization, the regular attributes are those of the target,
    and the attribute for "__spec__" contains the specification
    (lib.fixedPoints.fix' uses "__unfix__" instead).

  Beyond the conceptual clarification, putting a focus
  on values rather than initial functions as the "start" of the extension
  enables a new feature: default field values, that can themselves be
  incrementally specified, like "slot defaults" and "default methods" in CLOS.
  By contrast, the `lib.fixedPoints` approach is isomorphic to requiring a
  "base" extension that ignores its super, and/or equivalently declaring that
  the "base case" is the bottom value the evaluation of which never returns.
  */

  # Type for open modular extension (lenses may stab, but extensions rip!)
  # type MExt r i p = ∀ s, t : Type . s ⊂ r s, t ⊂ i s ⇒ s → t → p s∩t
  # (r required, i inherited, p provided, s self, t super)

  # Instantiate a (closed) modular extension from Top to M. A trivial fixed-point function.
  # instantiateMExt :: top → (r → top → r) → r
  # instantiateMExt :: top → (Mext r top r) → r
  instantiateMExt = base: spec: let instance = spec instance base; in instance;

  # Compose two (open) modular prototypes by inheritance
  # composeMExt :: (M → B → C) → (M → A → B) → M → A → C
  composeMExt = child: parent: self: super:
    child self (parent self super);
  /*
  Note that in `composeMExt` above takes arguments in *reverse* order of
  `fixedPoints.composeExtensions`. `composeMext` takes a `child` prototype
  first (computed later, closer to the fixed-point), and a `parent` prototype
  second (computed earlier, closer to the base case),
  in an order co-variant with that of the `self` and `super` arguments,
  whereas `composeExtensions` has a contra-variant order.
  */

  # The identity (open) modular extension, that does nothing.
  # identityMExt :: M → V → V
  identityMExt = self: super: super;
  /*
  Obviously, computing its fixed-point bottoms away indefinitely, but since
  evaluation is lazy, you can still define and carry around its fixed-point
  as long as you never try to look *inside* it.
  */

  # Compose a list of prototypes in order.
  # composeMExts :: (IndexedList I i: (M → A_ i → A_ (i+1) → M → A_ 0 → A_ (Card I)
  composeMExts = lib.foldr composeMExt identityMExt;
  /*
  foldr works much better in a lazy setting, by providing short-cut behavior
  when child behavior shadows parent behavior without calling super.
    https://www.well-typed.com/blog/2014/04/fixing-foldl/
  */

  /*
  Now for multiply-inheritance specification. Like modular extensions,
  this notion is useful on its own, even to produce values other than prototypes
  that carry this extensible specification together with the target
  containing values from the fixed point.
  */

  # instantiateMISpec :: Instantiator → MISpec r Instantiator.Top r → r
  instantiateMeta = {
    computePrecedenceList,
    mergeInstance,
    bottomInstance,
    topMExt,
    getParents,
    getDefaults,
    getMExt,
    getId,
    ...
  } @ instantiator: meta: let
    precedenceList = computePrecedenceList instantiator meta.parents;
    defaults = lib.foldr mergeInstance bottomInstance ([meta.defaults] ++ map getDefaults precedenceList);
    __meta__ = meta // {inherit precedenceList;};
    proto = composeMExts ([(topMExt __meta__) (extensionMExt meta.extension)] ++ (map getMExt precedenceList));
  in
    instantiateMExt defaults proto;
  /*
  foldr works much better in a lazy setting, by providing short-cut behavior
  when child behavior shadows parent behavior without calling super.
  However, this won't make much change in the usual case that deals with extensions,
  because // is stricter than it could be and thus calls super anyway.
  */

  /*
  Below we use the C3 linearization to topological sort the inheritance DAG
  into a precedenceList, as do all modern languages with multiple inheritance:
  Dylan, Python, Raku, Parrot, Solidity, PGF/TikZ.
     https://en.wikipedia.org/wiki/C3_linearization
     https://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.19.3910
  */
  # isEmpty :: (List X) → Bool
  isEmpty = l: builtins.length l == 0;

  # isNonEmpty :: (List X) → Bool
  isNonEmpty = l: builtins.length l > 0;

  # remove_empties :: (List (List X)) → (List (NonEmptyList X))
  removeEmpties = builtins.filter isNonEmpty;

  # removeNext :: X (List (NonEmptyList X)) → (List (NonEmptyList X))
  removeNext = getId: next: tails:
    removeEmpties (map (l:
      if (getId (builtins.elemAt l 0) == getId next)
      then builtins.tail l
      else l)
    tails);

  # every :: (X → Bool) (List X) → Bool
  every = pred: l: let
    loop = i: i == 0 || (let j = i - 1; in pred (builtins.elemAt l j) && loop j);
  in
    loop (builtins.length l);

  # Given a getParents function, compute the precedence list without any caching.
  # getPrecedenceList_of_getParents :: (X → (List X)) → (X → (NonEmptyList X))
  getPrecedenceList_of_getParents = getParents: let
    getPrecedenceList = x: c3ComputePrecedenceList {inherit getParents getPrecedenceList;} (getParents x);
  in
    getPrecedenceList;

  # c3SelectNext :: (NonEmptyList (NonEmptyList X)) → X
  c3SelectNext = tails: err: let
    isCandidate = c: every (tail: !(builtins.elem c (builtins.tail tail))) tails;
    loop = ts:
      if isEmpty ts
      then err
      else let
        c = builtins.elemAt (builtins.elemAt ts 0) 0;
      in
        if isCandidate c
        then c
        else loop (builtins.tail ts);
  in
    loop tails;

  # c3computePrecedenceList ::
  #   { getParents: (A → (List A)); getPrecedenceList: ?(A → (NonEmptyList A)); } (List A) → (NonEmptyList A)
  c3ComputePrecedenceList = {
    getParents,
    getPrecedenceList ? (getPrecedenceList_of_getParents getParents),
    getId,
    ...
  }: parents: let
    # superPrecedenceLists :: (List (NonEmptyList A))
    superPrecedenceLists = map (super: [super] ++ getPrecedenceList super) parents;
    # loop :: (NonEmptyList X) (List (NonEmptyList X)) → (NonEmptyList X)
    err = throw ["Inconsistent precedence graph"];
    loop = head: tails:
      if isEmpty tails
      then head
      else if builtins.length tails == 1
      then head ++ (builtins.elemAt tails 0)
      else let
        next = c3SelectNext tails err;
      in
        loop (head ++ [next]) (removeNext getId next tails);
  in
    loop [] (removeEmpties (superPrecedenceLists ++ [parents]));

  /*
  Extensions as prototypes to be merged into attrsets.
  This is the same notion of extensions as in `lib.fixedPoints`,
  with the exact same calling convention.
  */
  # mergeAttrset :: A B → B // A | A ⊂ Attrset, B ⊂ Attrset
  mergeAttrset = a: b: b // a; # NB: bindings from `a` override those from `b`

  # mergeAttrsets :: IndexedList I A → Union I A | forall I i: (A i) ⊂ Attrset
  mergeAttrsets = builtins.foldl' mergeAttrset {}; # NB: leftmost bindings win.
  /*
  Note that lib.foldr would be better if // weren't so strict that you can't
   (throw "foo" // {a=1;}).a  without throwing.
  */

  # extensionMExt :: (M → A → B) → M → A → B
  extensionMExt = extension: self: super: (super // extension self super);
  /*
  Note how, as explained previously, we have the equation:
      fixedPoints.composeExtensions f g ==
          composeMExt (extensionMExt g) (extensionMExt f)
  */

  # identityExtension :: Extension A {} A
  identityExtension = self: super: {};
  /*
  Note how the fixed-point for this extension as pop prototype is not
  bottom, but the empty object `{}` (plus an appropriate `__meta__` field).
  */

  /*
  From a name (any type that can be compared with ==, use 0 or anything if not feeling creative),
  generate a unique identification tag that can be compared with == and only returns true on itself.
  For how this enables checking identity of nodes, see:
  https://code.tvl.fyi/tree/tvix/docs/src/value-pointer-equality.md
  */
  genId = name: [(_: name) name];

  /*
  Finally, here are our objects with both CLOS-style multiple inheritance and
  the winning Jsonnet-style combination of instance and meta information into
  a same entity, the object.
  */
  # Parameter to specialize `instantiateMeta` above.
  PopInstantiator = rec {
    computePrecedenceList = c3ComputePrecedenceList;
    mergeInstance = mergeAttrset;
    bottomInstance = {};
    topMExt = __meta__: self: super: super // {inherit __meta__;};
    getParents = {parents ? [], ...}: parents;
    getPrecedenceList = p:
      if p ? __meta__
      then p.__meta__.precedenceList
      else [];
    getDefaults = p:
      if p ? __meta__
      then p.__meta__.defaults
      else {};
    getMExt = p:
      if p ? __meta__
      then extensionMExt p.__meta__.extension
      else _self: super: super // p;
    getId = p:
      if p ? __meta__
      then p.__meta__.__id__
      else p;
    getName = p:
      if p ? __meta__
      then p.__meta__.name
      else "attrs";
  };
  /*
  TODO: make that an object too, put it in the `__meta__` of `__meta__`, and
  bootstrap an entire meta-object protocol in the style of the CLOS MOP.
  */

  # Instantiate a `Pop` from a `Meta`
  # instantiatePop :: Meta A B → Pop A B
  instantiatePop = instantiateMeta PopInstantiator;

  # Extract the `Meta` information from an instantiated `Pop` object.
  # If it's an `Attrset` that isn't a `Pop` object, treat it as if it were
  # a `kPop` of its value as instance.
  # getMeta :: Pop A B → Meta A B
  getMeta = p:
    if p ? __meta__
    then p.__meta__
    else {
      __id__ = [p];
      parents = [];
      precedenceList = [];
      extension = _: _: p;
      defaults = {};
      name = "attrs";
    };

  # General purpose constructor for a `pop` object, based on an optional `name`,
  # an optional list `parents` of parent pops, an `extension` as above, and
  # an attrset `defaults` for default bindings.
  # pop :: { name ? :: String, parents ? :: (IndexedList I i: Pop (M_ i) (B_ i)),
  #          extension ? :: MExt r i p, defaults ? :: Defaults A, ... }
  #         → Pop A B | A ⊂ (Union I M_) ⊂ M ⊂ B ⊂ (Union I B_)
  pop = {
    parents ? [],
    extension ? identityExtension,
    defaults ? {},
    name ? "pop",
    ...
  } @ meta:
    instantiatePop (meta
      // {
        inherit extension defaults name parents;
        __id__ = genId name;
      });

  # A base pop, in case you need a shared one.
  # basePop :: (Pop A A)
  basePop = pop {name = "basePop";};
  /*
  Note that you don't usually need a base case: an attrset of default bindings
  will already be computed from the inherited defaults.
  You could also use `(pop {})` or `{}` as an explicit base case if needed.
  */

  # `kPop`, the K combinator for POP, whose extension returns a constant attrset
  # Note how `getMeta` already treats any non-pop attrset as an implicit `kPop`.
  # kPop :: A → (Pop A B)
  kPop = attrs:
    pop {
      name = "kPop";
      extension = _: _: attrs;
    };

  # `selfPop`, for an "extension" that doesn't care about super attributes,
  # just like the initial functions used by `lib.fixedPoints`.
  # selfPop :: (B → A) → (Pop A B)
  selfPop = f:
    pop {
      name = "selfPop";
      extension = self: _: f self;
    };

  # `simplePop` for just an extension without parents, defaults, nor name.
  # simplePop :: (Extension A B) → (Pop A B)
  simplePop = extension:
    pop {
      inherit extension;
      name = "simplePop";
    };

  # `mergePops` combines multiple pops in order by multiple inheritance,
  # without local overrides by prototype extension, without defaults or name.
  # mergePops :: (IndexedList I i: (M → A_ i → B_ i)) → M → Union I A_ → Union I B_
  mergePops = parents:
    pop {
      name = "mergePops";
      inherit parents;
    };

  # `extendPop` for single inheritance case with no defaults and no name.
  # extendPop :: (Pop A B) (Extensions C A) → (Pop C B)
  extendPop = p: extension:
    pop {
      name = "extendPop";
      parents = [p];
      inherit extension;
    };

  # `kxPop` for single inheritance case with just extension by constants.
  # kxPop :: (Pop A B) C → (Pop (A \\ C) B)
  kxPop = p: x:
    pop {
      name = "kxPop";
      parents = [p];
      extension = _: _: x;
    };

  # `defaultsPop` for single inheritance case with just defaults.
  # defaultsPop :: D (Pop A B) → Pop A B | D ⊂ A
  defaultsPop = defaults: p:
    pop {
      name = "defaultsPop";
      parents = [p];
      inherit defaults;
    };

  # `namePop` to override the name of a pop
  # namePop :: String (Pop A B) → Pop A B
  namePop = name: p:
    p
    // {
      __meta__ =
        (getMeta p)
        // {
          __id__ = genId name;
          inherit name;
        };
    };

  # Turn a pop into a normal attrset by erasing its `__meta__` information.
  # unpop :: Pop A B → A
  unpop = p: builtins.removeAttrs p ["__meta__"];
}
