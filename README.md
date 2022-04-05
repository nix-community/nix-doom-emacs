# nix-doom-emacs

|     | Status |
| --- | --- |
| Build on `master` | [![Build Status on master](https://github.com/nix-community/nix-doom-emacs/workflows/Check%20Build/badge.svg?branch=master&event=push)](https://github.com/nix-community/nix-doom-emacs/actions?query=workflow%3ACheck%20Build+branch%3Amaster+event%3Apush) |
| Build on `develop` | [![Build Status on develop](https://github.com/nix-community/nix-doom-emacs/workflows/Check%20Build/badge.svg?branch=develop&event=push)](https://github.com/nix-community/nix-doom-emacs/actions?query=workflow%3ACheck%20Build+branch%3Adevelop+event%3Apush) |
| Dependency updater | [![Dependency Updater Status](https://github.com/nix-community/nix-doom-emacs/workflows/Update%20Dependencies/badge.svg?branch=master)](https://github.com/nix-community/nix-doom-emacs/actions?query=workflow%3AUpdate%20Dependencies+branch%3Amaster+event%3Apush) |

Nix expression to install and configure
[doom-emacs](https://github.com/hlissner/doom-emacs).

The expression builds a `doom-emacs` distribution with dependencies
pre-installed based on an existing `~/.doom.d` directory.

It is not a fully fledged experience as some dependencies are not installed and
some may not be fully compatible as the version available in NixOS or
[emacs-overlay](https://github.com/nix-community/emacs-overlay) may not be
compatible with the `doom-emacs` requirements.

## Getting started

Using [home-manager](https://github.com/rycee/home-manager):

``` nix
{ pkgs, ... }:

let
  doom-emacs = pkgs.callPackage (builtins.fetchTarball {
    url = https://github.com/nix-community/nix-doom-emacs/archive/master.tar.gz;
  }) {
    doomPrivateDir = ./doom.d;  # Directory containing your config.el init.el
                                # and packages.el files
  };
in {
  home.packages = [ doom-emacs ];
}
```

`./doom.d` should contain the following three files: `config.el`, `init.el` and
`packages.el`. If you don't already have an existing `doom-emacs` configuration,
you can use the contents of `test/doom.d` as a template.

Using `flake.nix`:

``` nix
{
  inputs = {
    home-manager.url = "github:rycee/home-manager";
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
  };

  outputs = {
    self,
    nixpkgs,
    lib,
    home-manager,
    nix-doom-emacs,
    ...
  }: {
    nixosConfigurations.exampleHost = lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.exampleUser = lib.mkMerge [
            nix-doom-emacs.hmModule
            { ... }: {
              programs.doom-emacs = {
                enable = true;
                doomPrivateDir = ./doom.d;
              };
            }
          ];
        }
      ];
    };
  };
}
```

## Under the hood

This expression leverages
[nix-straight.el](https://github.com/nix-community/nix-straight.el) under the hood for
installing dependencies. The restrictions of that package apply here too.

## Usage

instead of running emacs.d/bin/doom, once you have update your config files (packages.el, init.el, config.el), rebuild doom-emacs with nix. If you are using home-manager, simply run `home-manager switch`

## Troubleshooting

On macOS on a fresh install, you might run into the error `Too many files open`. running `ulimit -S -n 2048` will only work for the duration of your shell and will fix the error

## Installing emacs packages

In the initial packages.el instructions for how to install packages can be
found. However some packages might require a particular software dependency to
be installed. Trying to install those would give you an error of the type:
`Searching for program: No such file or directory, git` (Missing git dependency)
Here is how you would go installing
[magit-delta](https://github.com/dandavison/magit-delta) for example (which
requires git).

Under the line:
`doomPrivateDir = ./doom.d;`
in your configuration, you would add the following:

```Nix
  emacsPackagesOverlay = self: super: {
     magit-delta = super.magit-delta.overrideAttrs (esuper: {
       buildInputs = esuper.buildInputs ++ [ pkgs.git ];
     });
  };
```

To make the git dependency available. trying to rebuild doom-emacs with
`home-manager switch` should work correctly now.

## Using the daemon

To use the daemon, simply enable the emacs service (with `NixOS`, `home-manager`
or `nix-darwin`) and use the doom emacs package. `doom-emacs` will need to be
referenced at the top of your config file.

```nix
services.emacs = {
  enable = true;
  package = doom-emacs;  # use programs.emacs.package instead if using home-manager
}
```

to connect to the daemon you can now run `emacsclient -c`
