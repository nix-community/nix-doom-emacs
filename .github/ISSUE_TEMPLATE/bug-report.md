---
name: Bug report
about: Something is broken and you want help fixing it
title: ''
labels: bug
assignees: ''

---

<!--
If you want your issue to be replied to, writing a detailed thought-out issue makes it more appealing to respond to. Otherwise, your issue will only serve as a forum for other users experiencing the issue to comment on. Replies are not to be expected by default.

To help with debugging your issue, you can try to replicate it using a minimal example with the following `flake.nix` file:

{
  description = "Test";

  inputs = {
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nix-doom-emacs, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system: {
        packages.default = nix-doom-emacs.package.${system} {
          doomPrivateDir = ./doom.d;
        };
      }
    );
}

Make sure to also send the flake.lock!
-->
