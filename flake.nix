{
  description = "javacafe's site";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Import theme
    congo-src = {
      url = "github:jpanther/congo";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      git = pkgs.git;
      go = pkgs.go;
      hugo = pkgs.hugo;
      nativeBuildInputs = [go hugo];

      site = pkgs.stdenv.mkDerivation (finalAttrs: {
        inherit nativeBuildInputs;

        name = "site";

        # Exclude themes and public folder from build sources
        src =
          builtins.filterSource
          (path: type:
            !(type
              == "directory"
              && (baseNameOf path
                == "themes"
                || baseNameOf path == "public")))
          self;

        buildPhase = let
          hugoVendor = pkgs.stdenv.mkDerivation {
            inherit (finalAttrs) src;

            name = "${finalAttrs.name}-hugoVendor";
            nativeBuildInputs = finalAttrs.nativeBuildInputs ++ [git];

            buildPhase = ''
              mkdir -p themes
              ln -s ${inputs.congo-src} themes/congo
              hugo mod vendor
            '';

            installPhase = ''
              cp -r _vendor $out
            '';

            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            # To get a new hash:
            # 1. Replace the existing hash with `pkgs.lib.fakeHash`
            # 2. Run `nix build`
            # 3. Substitute the new hash
            outputHash = "sha256-pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo=";
          };
        in ''
          mkdir -p themes
          ln -s ${inputs.congo-src} themes/congo
          ln -s ${hugoVendor} _vendor
          hugo --minify
        '';

        installPhase = ''
          cp -r public $out
        '';

        meta = with pkgs.lib; {
          description = "site";
          platforms = platforms.all;
        };
      });
    in {
      packages = {
        inherit site;
        default = site;
      };

      devShells.default = pkgs.mkShell {
        buildInputs = nativeBuildInputs;

        shellHook = ''
          mkdir -p themes
          ln -sf ${inputs.congo-src} themes/congo
        '';
      };
    });
}
