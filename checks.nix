{ system }:
{ self, nixpkgs, emacs-overlay, ... }@inputs:

let
  pkgs = import nixpkgs {
    inherit system;
    # we are not using emacs-overlay's flake.nix here,
    # to avoid unnecessary inputs to be added to flake.lock;
    # this means we need to import the overlay in a hack-ish way
    overlays = [ (import emacs-overlay) ];
  };
  # we are cloning HM here for the same reason as above, to avoid
  # an extra additional input to be added to flake
  home-manager = pkgs.fetchFromGitHub {
    owner = "nix-community";
    repo = "home-manager";
    rev = "8160b3b45b8457d58d2b3af2aeb2eb6f47042e0f";
    sha256 = "sha256-/aN3p2LaRNVXf7w92GWgXq9H5f23YRQPOvsm3BrBqzU=";
  };
in
{
  home-manager-module = (import "${home-manager}/modules" {
    inherit pkgs;
    configuration = {
      imports = [ self.outputs.hmModule ];
      home = {
        username = "nix-doom-emacs";
        homeDirectory = "/tmp";
        stateVersion = "22.11";
      };
      programs.doom-emacs = {
        enable = true;
        doomPrivateDir = ./test/doom.d;
      };
    };
  }).activationPackage;
  init-example-el = self.outputs.package.${system} {
    doomPrivateDir = ./test/doom.d;
    dependencyOverrides = inputs;
    emacsPackages = with pkgs; emacsPackagesFor emacsNativeComp;
  };
  init-example-el-emacsGit = self.outputs.package.${system} {
    doomPrivateDir = ./test/doom.d;
    dependencyOverrides = inputs;
    emacsPackages = with pkgs; emacsPackagesFor emacsGit;
  };
}
