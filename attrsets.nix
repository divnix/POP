{lib}: {
  /*
    Override the attrset a with the name-value bindings from attrset b,
   or just return b if a isn't an attrset.
   Example:
     overrideAttr 1 {b = 3; y = 4;}
     => {b = 3; y = 4;}
     overrideAttr { b = 2; z = 5;} {b = 3; y = 4;}
     => {b = 3; y = 4; z = 5;}
   */
  overrideAttr = a: b:
    if isAttrs a
    then a // b
    else b;

  /*
   Augment an attrset with a single name-value binding, overriding any previous binding for that name.
   if the third argument is not an attrset, it is ignored and a new singleton attrset is returned.
   Example:
     consAttr "a" 1 {b = 2; c = 3;}
     => {a = 1; b = 2; c = 3;}
     consAttr "a" 10 {a = 1; b = 2;}
     => {a = 10; b = 2;}
     consAttr "a" 10 30
     => {a = 10;}
   */
  consAttr = n: v: a: overrideAttr a {"${n}" = v;};

  /*
   Is `as' an attrset that furthermore has `a' as an attribute?
   */
  isAttrsHasAttr = a: as: isAttrs as && hasAttr a as;

  /*
   Update an attribute at a given path `attrPath' in object `x' to have value `v'.
   If along the path some intermediate attrsets missing, or a value is found that isn't an attrset,
   it will be overwritteny an otherwise empty attrset.
   Example:
     updateAttrByPath [] 42 "foo"
     => 42
     updateAttrByPath ["a"] 99 {a = 1; b = 2;}
     => { a = 99; b = 2;}
     updateAttrByPath ["a"] 99 "foo"
     => { a = 99;}
     updateAttrByPath ["a"] 99 {b = 2; c = 3;}
     => { a = 99; b = 2; c = 3;}
     updateAttrByPath ["b" "c"] 1 {b = 3; y = 4;}
     => { b = { c = 1;}; y = 4; };}
     updateAttrByPath ["a" "b" "c"] 1 { x = 2; a = { b = 3; y = 4; };}
     => { x = 2; a = { b = { c = 1;}; y = 4; };}
   */
  updateAttrByPath = attrPath: v: x:
    if attrPath == []
    then v
    else let
      attr = head attrPath;
    in
      if isAttrsHasAttr attr x
      then (consAttr attr (updateAttrByPath (tail attrPath) v (getAttr attr x)) x)
      else overrideAttr x (setAttrByPath attrPath v);

  /*
   Modify an attribute at a given path `p' in object `x' to have value `f v'
   where `v' is the previous value at that path, or update the value to the default `d'
   as per updateAttrByPath if no such value existed.
   Example:
     modifyAttrByPath [] (x: x + 1) 0 41
     => 42
     modifyAttrByPath ["a"] (x: x + 1) 0 {a = 10; b = 20;}
     => {a = 11; b = 20;}
     modifyAttrByPath ["a"] (x: x + 1) 0 {b = 20;}
     => {a = 0; b = 20;}
     modifyAttrByPath ["b" "c"] (x: x + 1) 0 {b = 3; y = 4;}
     => { b = { c = 0;}; y = 4; };}
     modifyAttrByPath ["a" "b" "c"] (x: x + 1) 0 { x = 2; a = { b = 3; y = 4; };}
     => { x = 2; a = { b = { c = 0;}; y = 4; };}
   */
  modifyAttrByPath = attrPath: f: d: x:
    if attrPath == []
    then f x
    else let
      attr = head attrPath;
    in
      if isAttrsHasAttr attr x
      then consAttr attr (modifyAttrByPath (tail attrPath) f d (getAttr attr x)) x
      else overrideAttr x (setAttrByPath attrPath d);
}
