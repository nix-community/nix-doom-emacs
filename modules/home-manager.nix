{ self, ... }@inputs:
{ options, config, lib, pkgs, ... }:
let
  cfg = config.programs.doom-emacs;
  inherit (lib) literalExample mkEnableOption mkIf mkMerge mkOption optional types;
  overlayType = lib.mkOptionType {
    name = "overlay";
    description = "Emacs packages overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };
in
{
  options.programs.doom-emacs = {
    enable = mkEnableOption "Doom Emacs configuration";
    doomPrivateDir = mkOption {
      description = ''
        Path to your `.doom.d` directory.

        The specified directory should  contain yoour `init.el`, `config.el` and
        `packages.el` files.
      '';
      apply = path: if lib.isStorePath path then path else builtins.path { inherit path; };
    };
    extraConfig = mkOption {
      description = ''
        Extra configuration options to pass to doom-emacs.

        Elisp code set here will be appended at the end of `config.el`. This
        option is useful for refering `nixpkgs` derivation in Emacs without the
        need to install them globally.
      '';
      type = with types; lines;
      default = "";
      example = literalExample ''
        (setq mu4e-mu-binary = "''${pkgs.mu}/bin/mu")
      '';
    };
    extraPackages = mkOption {
      description = ''
        Extra packages to install.

        List addition non-emacs packages here that ship elisp emacs bindings.
      '';
      type = with types; listOf package;
      default = [ ];
      example = literalExample "[ pkgs.mu ]";
    };
    emacsPackage = mkOption {
      description = ''
        Emacs package to use.

        Override this if you want to use a custom emacs derivation to base
        `doom-emacs` on.
      '';
      type = with types; package;
      default = pkgs.emacs;
      example = literalExample "pkgs.emacs";
    };
    emacsPackagesOverlay = mkOption {
      description = ''
        Overlay to customize emacs (elisp) dependencies.

        As inputs are gathered dynamically, this is the only way to hook into
        package customization.
      '';
      type = with types; overlayType;
      default = self: super: {  };
      defaultText = "self: super {  }";
      example = literalExample ''
        self: super: {
          magit-delta = super.magit-delta.overrideAttrs (esuper: {
            buildInputs = esuper.buildInputs ++ [ pkgs.git ];
          });
        };
      '';
    };
    package = mkOption {
      internal = true;
    };
  };

  config = mkIf cfg.enable (
    let
      emacs = pkgs.callPackage self {
        extraPackages = (epkgs: cfg.extraPackages);
        emacsPackages = pkgs.emacsPackagesFor cfg.emacsPackage;
        inherit (cfg) doomPrivateDir extraConfig emacsPackagesOverlay;
        dependencyOverrides = inputs;
      };
    in
    mkMerge ([
      {
        # TODO: remove once Emacs 29+ is released and commonly available
        home.file.".emacs.d/init.el".text = ''
          (load "default.el")
        '';
        home.packages = with pkgs; [
          emacs-all-the-icons-fonts
        ];
        programs.emacs.package = emacs;
        programs.emacs.enable = true;

        programs.doom-emacs.package = emacs;
      }
    ]
    # this option is not available on darwin platform.
    ++ optional (options.services ? emacs) {
      # Set the service's package but don't enable. Leave that up to the user
      services.emacs.package = emacs;
    })
  );
}
