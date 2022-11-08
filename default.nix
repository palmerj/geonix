# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage

{ pkgs ? import <nixpkgs> { } }:

with pkgs;

rec {
  # The `lib`, `modules`, and `overlay` names are special
  lib = import ./lib { inherit pkgs; }; # functions
  modules = import ./modules; # NixOS modules
  overlays = import ./overlays; # nixpkgs overlays

  geos = pkgs.callPackage ./pkgs/geos { };
  proj = pkgs.callPackage ./pkgs/proj { };

  libgeotiff = pkgs.callPackage ./pkgs/libgeotiff {
    inherit proj;
  };

  gdal = pkgs.callPackage ./pkgs/gdal {
    inherit proj;
    pythonPackages = python3Packages;
    autoreconfHook = buildPackages.autoreconfHook269;
  };
}
