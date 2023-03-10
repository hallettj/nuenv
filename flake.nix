{
  description = "nuenv: a Nushell environment for Nix";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; overlays = [ self.overlays.nuenv ]; };
        inherit system;
      });
    in
    {
      overlays = {
        nuenv = (final: prev: {
          nuenv.mkDerivation = self.lib.mkNushellDerivation;
        });
      };

      lib = {
        # A derivation wrapper that calls a Nushell builder rather than the standard environment's
        # Bash builder.
        mkNushellDerivation =
          { nushell           # Nushell package
          , name              # The name of the derivation
          , src ? ./.         # The derivation's sources
          , system            # The build system
          , buildInputs ? [ ] # Same as buildInputs in stdenv
          , buildPhase ? ""   # Same as buildPhase in stdenv
          , installPhase ? "" # Same as installPhase in stdenv
          }:

          derivation {
            inherit name src system buildPhase installPhase;
            builder = "${nushell}/bin/nu";
            args = [ ./builder.nu ];

            # Attributes passed to the environment (prefaced with __ to avoid naming collisions)
            __nu_nushell_version = nushell.version;
            __nu_envFile = ./env.nu;
            __nu_buildInputs = buildInputs ++ [ nushell ];
          };
      };

      devShells = forAllSystems ({ pkgs, system }: {
        default = pkgs.mkShell {
          packages = with pkgs; [ go nushell ];
        };
      });

      packages = forAllSystems ({ pkgs, system }: {
        default =
          pkgs.nuenv.mkDerivation {
            name = "just-experimenting";
            inherit system;
	    nushell = pkgs.nushell;
            buildInputs = with pkgs; [ curl ];
            buildPhase = ''
              let versionFile = "curl-version.txt"
              echo $"Writing version info to ($versionFile)"
              curl --version | save $versionFile

              let helpFile = "curl-help.txt"
              echo $"Writing help info to ($helpFile)"
              curl --help | save $helpFile


              [$versionFile $helpFile] | each {|f|
                substituteInPlace $f --replace curl --with CURL
              }
            '';
            installPhase = ''
              let share = $"($env.out)/share"
              mkdir $share
              [curl-help.txt curl-version.txt] | each { |file| mv $file $share }
            '';
          };

        # Derivation that relies on the Nushell derivation
        other = pkgs.stdenv.mkDerivation {
          name = "other";
          src = ./.;
          installPhase = ''
            mkdir -p $out/share
            cp ${self.packages.${system}.default}/share/go-version.txt $out/share/version.txt
          '';
        };
      });
    };
}
