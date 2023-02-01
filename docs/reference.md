| index |     |     |
| --- | --- | --- |
|[readme](../README.md)|**reference**|[faq](./faq.md)|

# nix-doom-emacs reference

nix-doom-emacs uses [`nix-straight.el`](https://github.com/nix-community/nix-straight.el) under the hood to install dependencies. It's a low level wrapper to integrate Nix with [`straight.el`](https://github.com/radian-software/straight.el). It is maintained by the same people as this project.

Currently, `nix-straight.el` only extracts package names and uses [`emacs-overlay`](https://github.com/nix-community/emacs-overlay) to obtain the package sources. This works most of the time but occasionally results in obscure issues with recently updated packages.

# Getting Started

In all of these methods, you'll need your Doom Emacs configuration. It should contain the following three files: 
`config.el`, `init.el` and `packages.el`. If you don't already have an existing `doom-emacs` configuration, you can use the contents of `test/doom.d` as a template.

## Home-Manager

### With Flakes

`File: flake.nix`
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-doom-emacs,
    ...
  }: {
    nixosConfigurations.exampleHost = nixpkgs.lib.nixosSystem {
      system  = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        nix-doom-emacs.hmModule
        {
          home-manager.users.exampleUser = { ... }: {
            programs.doom-emacs = {
              enable = true;
              doomPrivateDir = ./doom.d; # Directory containing your config.el, init.el
                                         # and packages.el files
            };
          };
        }
      ];
    };
  };
}
```

### Without Flakes

```nix
{ pkgs, ... }:

let
  doom-emacs = pkgs.callPackage (builtins.fetchTarball {
    url = https://github.com/nix-community/nix-doom-emacs/archive/master.tar.gz;
  }) {
    doomPrivateDir = ./doom.d;  # Directory containing your config.el, init.el
                                # and packages.el files
  };
in {
  home.packages = [ doom-emacs ];
}
```


## NixOS

`File: flake.nix`
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
  };
  
  outputs = {
    self,
    nixpkgs,
    nix-doom-emacs,
    ...
  }: {
    nixosConfigurations.exampleHost = nixpkgs.lib.nixosSystem rec {
      system  = "x86_64-linux";
      modules = [
        { 
          environment.systemPackages = 
            let
              doom-emacs = nix-doom-emacs.packages.${system}.default.override {
                doomPrivateDir = ./doom.d;
              };
            in [
              doom-emacs
            ];
        }
        # ...
      ];
    };
  };
}
```

You can see all overridable parameters of nix-doom-emacs in [default.nix](../default.nix).

## Standalone

### Flake

```nix
{
  description = "nix-doom-emacs shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
  };

  outputs = { self, nixpkgs, nix-doom-emacs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    doom-emacs = nix-doom-emacs.packages.${system}.default.override {
      doomPrivateDir = ./doom.d;
    };
  in
  {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [ doom-emacs ];
    };
  };
}
```

### Non-Flake
```nix
{ pkgs ? import <nixpkgs> { } }:

let
  repo = pkgs.fetchFromGitHub {
    owner = "nix-community";
    repo = "nix-doom-emacs";
    rev = "<commit>";
    sha256 = "<hash>";
  };
  nix-doom-emacs = pkgs.callPackage (import repo) {
    doomPrivateDir = ./doom.d;
  };
in
pkgs.mkShell {
  buildInputs = [ nix-doom-emacs ];
}
```

# Setup

## Emacs daemon

If you use the Home-Manager module, you can enable it via `services.emacs.enable = true;`. The Home-Manager module will do the rest for you.

If you're not, and you're using a standalone method (NixOS/nix-darwin without Home-Manager) instead, you'll need:

```nix
services.emacs = {
  enable = true;
  package = inputs.doom-emacs.packages.${system}.doom-emacs.override {
    doomPrivateDir = ./doom.d;
  };
};
```

You can now run `emacsclient -c` to connect to the daemon.

## Custom Emacs derivations (i.e., PGTK, NativeComp)

If you're using the Home-Manager module, you can use the `emacsPackage` attribute after applying `emacs-overlay` to your nixpkgs:

```nix
programs.doom-emacs = {
  enable = true;
  doomPrivateDir = ./doom.d;
  emacsPackage = pkgs.emacsPgtk;
}
```

For standalone usage with Flakes:

```nix
let
  # ...
  doom-emacs = nix-doom-emacs.packages.${system}.default.override {
    doomPrivateDir = ./doom.d;
    emacsPackage = pkgs.emacsPgtkNativeComp;
  };
in {
  # ...
}
```

And for non-Flakes usage:

```nix
let
  # ...
  nix-doom-emacs = pkgs.callPackage (import repo) {
    doomPrivateDir = ./doom.d;
    emacsPackage = pkgs.emacsPgtkNativeComp
  };
in {
  # ...
}
```

## Updating configuration

Note that, unlike imperative `Doom Emacs`, we do not have a `doom sync`. Our project builds an Emacs with your Doom configuration embedded in it. `doom sync` just updates packages.
This doesn't mean that you can't update your packages and configuration, obviously:

To update your Doom Emacs config, you simply rebuild your configuration. For example, in NixOS you can use `nixos-rebuild switch` (or `home-manager switch` if you use Home-Manager standalone). nix-doom-emacs will do everything else for you.

In an imperative environment, Doom updates can break Emacs with no easy way to roll back.
nix-doom-emacs moves the moving parts of your Emacs installation into the Nix build sandbox.

## Building third-party Emacs packages

Though beyond the scope of this document, [`trivialBuild`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/emacs/trivial.nix) is a nixpkgs function to trivially build Emacs packages. You can use it to build e.g. local packages or packages hosted on Git repositories. There is also a family of functions in nixpkgs which are made to build Emacs packages, such as:

- [`generic`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/emacs/generic.nix): This is the "base" function which all the other build functions are derived from
- [`elpaBuild`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/emacs/elpa.nix): For ELPA packages
- [`melpaBuild`](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/emacs/elpa.nix): For MELPA packages

To find examples of how they're used, try to [search nixpkgs](https://github.com/NixOS/nixpkgs/search) for usages of them.

# Support

If you encounter any issues while using nix-doom-emacs, you can find some of us in the [Matrix room](https://matrix.to/#/#doom-emacs:nixos.org).
