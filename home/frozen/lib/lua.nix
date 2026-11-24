# Turns a Nix value into Lua source: attrsets and lists become tables, strings are quoted,
# booleans and numbers stay as they are. Used to hand Nix data to hyprland.lua.
#
#   toLua { float = true; size = [ "900" "600" ]; }   ->   { ["float"] = true, ["size"] = { "900", "600" } }
#
# Strings go through toJSON, which is valid Lua for everything except non-printing control characters.
{ lib }:
let
  toLua =
    value:
    if builtins.isBool value then
      (if value then "true" else "false")
    else if builtins.isInt value || builtins.isFloat value then
      toString value
    else if builtins.isString value then
      builtins.toJSON value
    else if builtins.isList value then
      "{ ${lib.concatMapStringsSep ", " toLua value} }"
    else if builtins.isAttrs value then
      "{ ${lib.concatStringsSep ", " (lib.mapAttrsToList (k: v: "[${builtins.toJSON k}] = ${toLua v}") value)} }"
    else
      throw "toLua: cannot convert a value of type ${builtins.typeOf value}";
in
toLua
