{

  /* This function creates a derivation that injects a `modules` folder (containing the
     directories in the `src` parameter) into a doom.d configuration folder.
  */
  mkDoomModules = pkgs: {
    name,
    version,
    src,
    meta ? {},

    literateCode ? false
  } @ args: pkgs.stdenvNoCC.mkDerivation {
    inherit name version meta;

    src = pkgs.lib.sourceFilesBySuffices src [ ".el" ".org" ];

    buildInputs =
      if literateCode then
        [ pkgs.emacs pkgs.coreutils ]
      else
        [];

    buildPhase =
      # transform literate code into .el files
      if literateCode then
        ''
          cp -R $src/* .
          chmod -R 700 .

          # Traverse the directory and execute the command on each '.org' file
          find . -type f -name "*.org" -print0 | while IFS= read -r -d "" file; do
            echo "tangle file $file"
            emacs --batch -Q -l org \
              --eval "(org-babel-tangle-file \"$file\" \"''${file%.*}.el\")"
          done

          chmod -R 700 .
        ''
      else
        "";

    installPhase = ''
        mkdir -p $out/modules
        ${pkgs.rsync}/bin/rsync -av . $out/modules
    '';
  };

}
