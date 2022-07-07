{ # The files would be going to ~/.config/doom (~/.doom.d)
  doomPrivateDir
/* Extra packages to install

   Useful for non-emacs packages containing emacs bindings (e.g.
   mu4e).

   Example:
     extraPackages = epkgs: [ pkgs.mu ];
*/
, extraPackages ? epkgs: [ ]
  /* Extra configuration to source during initialization

     Use this to refer other nix derivations.

     Example:
       extraConfig = ''
         (setq mu4e-mu-binary = "${pkgs.mu}/bin/mu")
       '';
  */
, extraConfig ? ""
  /* Package set to install emacs and dependent packages from

     Only used to get emacs package, if `bundledPackages` is set.
  */
, emacsPackages
/* Overlay to customize emacs (elisp) dependencies

   See overrides.nix for addition examples.

   Example:
     emacsPackagesOverlay = self: super: {
       magit-delta = super.magit-delta.overrideAttrs (esuper: {
         buildInputs = esuper.buildInputs ++ [ pkgs.git ];
       });
     };
*/
, emacsPackagesOverlay ? self: super: { }
  /* Use bundled revision of github.com/nix-community/emacs-overlay
     as `emacsPackages`.
  */
, bundledPackages ? true
  /* Override dependency versions

     Handy for testing out updated dependencies without publishing
     a new version of them.

     Type: dependencyOverrides :: attrset -> either path derivation

     Example:
       dependencyOverrides = {
         "emacs-overlay" = fetchFromGitHub { owner = /* ...*\/; };
       };
  */
, dependencyOverrides ? { }
, lib, pkgs, stdenv, buildEnv, makeWrapper
, runCommand, fetchFromGitHub, substituteAll, writeShellScript
, writeShellScriptBin, writeTextDir }:

assert (lib.assertMsg ((builtins.isPath doomPrivateDir)
  || (lib.isDerivation doomPrivateDir) || (lib.isStorePath doomPrivateDir))
  "doomPrivateDir must be either a path, a derivation or a stringified store path");

let
  isEmacs29 = lib.versionAtLeast emacsPackages.emacs.version "29";
  flake =
    (import
      (let lock = with builtins; fromJSON (readFile ./flake.lock); in
       builtins.fetchTarball {
         url = "https://github.com/edolstra/flake-compat/archive/${lock.nodes.flake-compat.locked.rev}.tar.gz";
         sha256 = lock.nodes.flake-compat.locked.narHash;
       })
      { src = ./.; }).defaultNix;
  lock = p:
    if dependencyOverrides ? ${p} then
      dependencyOverrides.${p}
    else
      flake.inputs.${p};
  # Packages we need to get the default doom configuration run
  overrides = self: super:
    (pkgs.callPackage ./overrides.nix { inherit lock; } self super)
    // (emacsPackagesOverlay self super);

  # Stage 1: prepare source for byte-compilation
  doomSrc = stdenv.mkDerivation {
    name = "doom-src";
    src = lock "doom-emacs";
    phases = [ "unpackPhase" "patchPhase" "installPhase" ];
    patches = [
      (substituteAll {
        src = ./patches/fix-paths.patch;
        private = builtins.toString doomPrivateDir;
      })
    ];
    installPhase = ''
      mkdir -p $out
      cp -r * $out
    '';
  };

  fmt = {
    reset = "\\\\033[0m";
    bold = "\\\\033[1m";
    red = "\\\\033[31m";
    green = "\\\\033[32m";
  };

  # Bundled version of `emacs-overlay`
  emacs-overlay = import (lock "emacs-overlay") pkgs pkgs;

  # Stage 2: install dependencies and byte-compile prepared source
  doomLocal = let
    straight-env = pkgs.callPackage (lock "nix-straight") {
      emacsPackages = if bundledPackages then
        let epkgs = emacs-overlay.emacsPackagesFor emacsPackages.emacs;
        in epkgs.overrideScope' overrides
      else
        emacsPackages.overrideScope' overrides;
      emacs = emacsPackages.emacsWithPackages extraPackages;
      emacsLoadFiles = [ ./advice.el ];
      emacsArgs = [ "--" "install" ];

      # Need to reference a store path here, as byte-compilation will bake-in
      # absolute path to source files.
      emacsInitFile = "${doomSrc}/bin/doom";
    };

    packages = straight-env.packageList (super: {
      phases = [ "installPhase" ];
      nativeBuildInputs = [ git ];
      preInstall = ''
        export DOOMDIR=${doomPrivateDir}
        export DOOMLOCALDIR=$(mktemp -d)/local/
      '';
    });

    # I don't know why but byte-compilation somehow triggers Emacs to look for
    # the git executable. It does not seem to be executed though...
    git = writeShellScriptBin "git" ''
      >&2 echo "Executing git is not allowed; command line:" "$@"
      exit 127
    '';
  in (straight-env.emacsEnv {
    inherit packages;
    straightDir = "$DOOMLOCALDIR/straight";
  }).overrideAttrs (super: {
    phases = [ "installPhase" ];
    nativeBuildInputs = [ git ];
    preInstall = ''
      export DOOMDIR=${doomPrivateDir}
      export DOOMLOCALDIR=$out/

      # Create a bogus $HOME directory because gccEmacs is known to require
      # an existing home directory because the async worker process don't
      # fully respect the value of 'comp-eln-load-path'.
      export HOME=$(mktemp -d)
    '';
    postInstall = ''
      # If gccEmacs or anything would write in $HOME, fail the build.
      if [[ -z "$(find $HOME -maxdepth 0 -empty)" ]]; then
        printf "${fmt.red}${fmt.bold}ERROR:${fmt.reset} "
        printf "${fmt.red}doom-emacs build resulted in files being written in "'$HOME'" of the build sandbox.\n"
        printf "Contents of "'$HOME'":\n"
        find $HOME
        printf ${fmt.reset}
        exit 33
      fi
    '';
  });

  # Stage 3: do additional fixups to refer compiled files in the store
  # and additional files in the users' home
  doom-emacs = stdenv.mkDerivation rec {
    name = "doom-emacs";
    src = doomSrc;

    patches = [
      (substituteAll {
        src = ./patches/nix-integration.patch;
        local = doomLocal;
      })
    ];

    buildPhase = ''
      patchShebangs bin
      # Remove the windows wrapper for the CLI so the build doesn't fail
      rm bin/doom.cmd
    '';
    installPhase = ''
      mkdir -p $out
      cp -r * $out
    '';
  };

  # Stage 4: `extraConfig` is merged into private configuration
  doomDir = runCommand "doom-private" {
    inherit extraConfig;
    passAsFile = [ "extraConfig" ];
  } ''
    mkdir -p $out
    cp -rL ${doomPrivateDir}/* $out
    chmod u+w $out/config.el
    cat $extraConfigPath > $out/config.extra.el
    cat > $out/config.el << EOF
    (load "${doomPrivateDir}/config.el")
    (load "$out/config.extra.el")
    EOF
  '';

  # Stage 5: catch-all wrapper capable to run doom-emacs even
  # without installing ~/.emacs.d
  # TODO: remove once Emacs 29+ is released and commonly available
  emacs = let
    load-config-from-site = writeTextDir "share/emacs/site-lisp/default.el" ''
      (message "doom-emacs is not placed in `doom-private-dir',
      loading from `site-lisp'")
      ${lib.optionalString (!isEmacs29) ''
        (load "${doom-emacs}/early-init.el")
        (load "${doom-emacs}/core/core-start.el")
      ''}
    '';
  in (emacsPackages.emacsWithPackages (epkgs: [ load-config-from-site ]));

  # create a `emacs.d` dir to be loaded using `--init-directory` flag from Emacs 29+
  # this will allow proper usage of `early-init.el`, fixing FOUC issues and improving
  # startup performance
  emacs-dir = runCommand "emacs-dir" { } ''
    mkdir -p $out
    cat > $out/early-init.el << EOF
    (load "${doom-emacs}/early-init.el")
    EOF
    cat > $out/init.el << EOF
    (load "${doom-emacs}/core/core-start.el")
    EOF
  '';

  build-summary = writeShellScript "build-summary" ''
    printf "\n${fmt.green}Successfully built nix-doom-emacs!${fmt.reset}\n"
    printf "${fmt.bold}  ==> doom-emacs is installed to ${doom-emacs}${fmt.reset}\n"
    printf "${fmt.bold}  ==> private configuration is installed to ${doomDir}${fmt.reset}\n"
    printf "${fmt.bold}  ==> Dependencies are installed to ${doomLocal}${fmt.reset}\n"
  '';
in emacs.overrideAttrs (esuper:
  let
    # `--init-directory` is supported by Emacs 29+ only
    initDirArgs = lib.optionalString isEmacs29 ''
      if [[ $(basename $1) == emacs ]] || [[ $(basename $1) == emacs-* ]]; then
        wrapArgs+=(--add-flags '--init-directory ${emacs-dir}')
      fi
    '';
    cmd = ''
      wrapEmacs() {
          local -a wrapArgs=(
              --set DOOMDIR ${doomDir}
              --set NIX_DOOM_EMACS_BINARY $1
              --set __DEBUG_doom_emacs_DIR ${doom-emacs}
              --set __DEBUG_doomLocal_DIR ${doomLocal}
          )
          ${initDirArgs}

          wrapProgram $1 "''${wrapArgs[@]}"
      }

      for prog in $out/bin/*; do
          wrapEmacs $prog
      done

      # Doom comes with some CLIs (org-tangle, org-capture, doom)
      for prog in ${doom-emacs}/bin/*; do
          makeWrapper $prog $out/bin/"$(basename $prog)" --prefix PATH : $out/bin
      done

      if [[ -e $out/Applications ]]; then
        wrapEmacs "$out/Applications/Emacs.app/Contents/MacOS/Emacs"
      fi
      # emacsWithPackages assumes share/emacs/site-lisp/subdirs.el
      # exists, but doesn't pass it along.  When home-manager calls
      # emacsWithPackages again on this derivation, it fails due to
      # a dangling link to subdirs.el.
      # https://github.com/NixOS/nixpkgs/issues/66706
      rm -rf $out/share
      ln -s ${esuper.emacs}/share $out
      ${build-summary}
    '';
  in if esuper ? buildCommand then {
    buildCommand = esuper.buildCommand + cmd;
  } else if esuper ? installPhase then {
    installPhase = esuper.installPhase + cmd;
  } else
    abort "emacsWithPackages uses unknown derivation type")
