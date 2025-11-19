# flake.nix (excerpt)
{
  description = "nixify kadcom/pphc";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      perSystem =
        {
          self',
          pkgs,
          system,
          ...
        }:
        {
          packages = {
            default = self'.packages.pphc;
            pphc = pkgs.stdenv.mkDerivation {
              pname = "pphc";
              version = "0.1a";
              src = pkgs.fetchFromGitHub {
                owner = "kadcom";
                repo = "pphc";
                rev = "87acf4583acd3eeeaf1f347992a42d92efb88b08";
                sha256 = "sha256-pBx4Hy2X7+MRnrOP0FNBDapohyxiGQhU32tZOjwkQ04=";
              };

              nativeBuildInputs = [
                pkgs.cmake
                pkgs.ninja
                pkgs.pkg-config
              ];

              buildInputs = [ ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.gcc ];

              postPatch = pkgs.lib.optional pkgs.stdenv.isDarwin ''
                substituteInPlace libpph/CMakeLists.txt \
                  --replace 'FRAMEWORK TRUE' 'FRAMEWORK FALSE'

                substituteInPlace libpph/CMakeLists.txt \
                  --replace 'FRAMEWORK DESTINATION /Library/Frameworks' \
                            '# FRAMEWORK DESTINATION /Library/Frameworks'
              '';

              cmakeFlags =
                [
                  "-G Ninja"
                  "-DCMAKE_BUILD_TYPE=Release"
                  "-DBUILD_SHARED_LIBS=ON"
                  "-DBUILD_STATIC_LIBS=ON"
                  "-DBUILD_CLI=ON"
                  "-DBUILD_TESTS=ON"
                  "-DBUILD_EXAMPLES=ON"
                  "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
                ]
                ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
                  "-DCMAKE_INSTALL_RPATH=${placeholder "out"}/lib"
                ]
                ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
                  "-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0"
                  # Avoid code signing
                  "-DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO"
                ];

              # Help pphc find lib at runtime without env vars
              NIX_LDFLAGS_DARWIN = pkgs.lib.optionalString pkgs.stdenv.isDarwin "-Wl,-rpath,${placeholder "out"}/Library/Frameworks/pph.framework/Versions/A";

              doCheck = false; # ctest reports no tests; enable later if upstream adds add_test()

              meta = with pkgs.lib; {
                description = "PPHC library and CLI built via CMake";
                homepage = "https://github.com/kadcom/pphc";
                license = licenses.mit; # adjust if needed
                platforms = platforms.unix;
              };
            };
          };

          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [  ];
          };
        };
    };
}
