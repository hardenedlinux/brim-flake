{
  description = "Desktop application to efficiently search large packet captures and Zeek logs.";

  inputs = {
    nixpkgs.url = "nixpkgs/7ff5e241a2b96fff7912b7d793a06b4374bd846c";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "i686-linux" "aarch64-linux" ];
      nixpkgsFor = forAllSystems (system:
        import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        });

    in
    {
      overlay = final: prev: {
        brim = with final;
          (stdenv.mkDerivation {
            pname = "brim";
            version = "0.24.0";

            # fetching a .deb because there's no easy way to package this Electron app
            src = fetchurl {
              url = "https://github.com/brimsec/brim/releases/download/v${self.outputs.defaultPackage.x86_64-linux.version}/brim_amd64.deb";
              hash = "sha256-9HaxdBNwUPXHMGg7Kv0EjH2u5xp5t5LdzIl6zNobQuo=";
            };

            buildInputs = [
              gnome3.gsettings_desktop_schemas
              glib
              gtk3
              cairo
              gnome2.pango
              atk
              gdk-pixbuf
              at-spi2-atk
              dbus
              dconf
              xorg.libX11
              xorg.libxcb
              xorg.libXi
              xorg.libXcursor
              xorg.libXdamage
              xorg.libXrandr
              xorg.libXcomposite
              xorg.libXext
              xorg.libXfixes
              xorg.libXrender
              xorg.libXtst
              xorg.libXScrnSaver
              nss
              nspr
              alsaLib
              cups
              fontconfig
              expat
            ];

            nativeBuildInputs = [
              wrapGAppsHook
              autoPatchelfHook
              makeWrapper
              dpkg
            ];


            runtimeLibs = lib.makeLibraryPath [ libudev0-shim glibc curl openssl libnghttp2 ];

            unpackPhase = "dpkg-deb --fsys-tarfile $src | tar -x --no-same-permissions --no-same-owner";

            installPhase = ''
              mkdir -p $out/share/brim
              mkdir -p $out/bin
              mkdir -p $out/lib

              mv usr/lib/brim/* $out/share/brim
              mv $out/share/brim/*.so $out/lib/
              mv usr/share/* $out/share/
              ln -s $out/share/brim/Brim $out/bin/brim

              substituteInPlace $out/share/applications/brim.desktop  \
                --replace "brim %U" "$out/bin/brim $U"
            '';

            preFixup = ''
              gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${self.outputs.defaultPackage.x86_64-linux.runtimeLibs}" )
            '';

            enableParallelBuilding = true;
          });
      };

      packages = forAllSystems (system: { inherit (nixpkgsFor.${system}) brim; });

      defaultPackage = forAllSystems (system: self.packages.${system}.brim);

      checks = forAllSystems (system: {
        build = self.defaultPackage."${system}";
      });
    };
}
