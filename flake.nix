{
  description = "VisionFive 2 test flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";

    uboot-src = {
      flake = false;
      url = "github:u-boot/u-boot";
    };

    starfive-tools-src = {
      flake = false;
      url = "github:starfive-tech/Tools";
    };
  };

  outputs = { self, nixpkgs, uboot-src, starfive-tools-src } @ inputs: rec {
    overlays.default = self: super: {
      # Flaky tests
      coreutils = super.coreutils.overrideAttrs (old: { doCheck = false; });
      coreutils-full = super.coreutils-full.overrideAttrs (old: { doCheck = false; });
      diffutils = super.diffutils.overrideAttrs (old: { doCheck = false; });
      gnugrep = super.gnugrep.overrideAttrs (old: { doCheck = false; });
      libuv = super.libuv.overrideAttrs (old: { doCheck = false; });
      libseccomp = super.libseccomp.overrideAttrs (old: { doCheck = false; });
      bind = super.bind.overrideAttrs (old: { doCheck = false; });
      elfutils = super.elfutils.overrideAttrs (old: { doCheck = false; doInstallCheck = false; });

      nixVersions = super.nixVersions // {
        nix_2_18 = super.nixVersions.nix_2_18.overrideAttrs (old: { doCheck = false; doInstallCheck = false; });
        nix_2_15 = super.nixVersions.nix_2_15.overrideAttrs (old: { doCheck = false; });
      };
      nix = self.nixVersions.nix_2_18;

      python3 = super.python3.override {
        packageOverrides = pyself: pysuper: {
          psutil = pysuper.psutil.overrideAttrs (old: { dontUsePytestCheck = true; });
          sphinx = pysuper.sphinx.overrideAttrs (old: {
            disabledTests = old.disabledTests ++ [
              "test_connect_to_selfsigned_with_tls_cacerts"
              "test_connect_to_selfsigned_fails"
            ];
          });
          mypy = pysuper.mypy.overrideAttrs (old: { dontUsePytestCheck = true; });
        };
      };
      pythonPackages = self.python3.pkgs;

      mypy = with self.pythonPackages; toPythonApplication mypy;

      # https://github.com/systemd/systemd/issues/30448
      systemd = super.systemd.overrideAttrs (old: {
        env.NIX_CFLAGS_COMPILE = toString ([old.env.NIX_CFLAGS_COMPILE "-Wno-error=format-overflow" ]);
      });
      systemdMinimal = super.systemdMinimal.overrideAttrs (old: {
        env.NIX_CFLAGS_COMPILE = toString ([old.env.NIX_CFLAGS_COMPILE "-Wno-error=format-overflow" ]);
      });

      # Im not sure why this fails. The CMake script seems correct... further investigation is needed.
      zeromq = super.zeromq.overrideAttrs (old: {
        postPatch = old.postPatch + ''
          substituteInPlace CMakeLists.txt \
                --replace 'set(ZMQ_CACHELINE_SIZE ''${CACHELINE_SIZE})' 'set(ZMQ_CACHELINE_SIZE 64)'
        '';
      });

      # llvm 16 fails to build. Also, save some work by not compiling llvm 16 at all.
      # This replaces the default llvm toolchain with llvm 17
      inherit (self.llvmPackages_17) libclang clang clang-manpages lld lldb llvm libllvm llvm-manpages libcxx libcxxabiI;
      clang-tools = self.clang-tools_17;

      buildPackages = super.buildPackages // {
        llvmPackages = self.llvmPackages_17;
        inherit (self.llvmPackages_17) libclang clang clang-manpages lld lldb llvm libllvm llvm-manpages libcxx libcxxabiI;
        clang-tools = self.clang-tools_17;
      };

      # We don't want X.
      graphviz = super.graphviz.override { withXorg = false; };
      gd = super.gd.override { withXorg = false; };
      pango = super.pango.override { x11Support = false; withIntrospection = false; };
      gdk-pixbuf = super.gdk-pixbuf.override { withIntrospection = false; };
      cairo = super.cairo.override { x11Support = false; };
    };

    nixosModules = {
      sdImage = import ./modules/sd-image-visionfive2.nix;
    };

    nixosConfigurations.sd = nixpkgs.lib.nixosSystem {
      system = "riscv64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/profiles/minimal.nix"
        ({ lib, config, pkgs, ... }: {
          imports = [
            ./modules/sd-image-visionfive2.nix
          ];

          nixpkgs = {
            overlays = [ self.overlays.default ];
            hostPlatform = "riscv64-linux";
          };

          hardware.deviceTree.name = "starfive/jh7110-starfive-visionfive-2-v1.2a.dtb";

          sdImage = {
            spl.image = "${self.packages.x86_64-linux.firmware}/u-boot-spl.bin.normal.out";
            uboot.image = "${self.packages.x86_64-linux.firmware}/visionfive2_fw_payload.img";
            firmware.populateCmd = ''
              ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./firmware/boot
            '';
          };

          boot = {
            supportedFilesystems = lib.mkForce [ "vfat" "ext4" ];
            kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./pkgs/linux-vf2.nix { kernelPatches = [ ]; });
            kernelParams = [
              "console=tty0"
              "console=ttyS0,115200"
              "earlycon=sbi"
              "boot.shell_on_fail"
              "clk_ignore_unused" # Causes a hang on some kernels
            ];
            consoleLogLevel = 7;
            initrd.availableKernelModules = [
              "dw_mmc-starfive"
              "motorcomm"
              "dwmac-starfive"
              "cdns3-starfive"
              "jh7110-trng"
              "phy-jh7110-usb"
              "clk-starfive-jh7110-aon"
              "clk-starfive-jh7110-stg"
              "clk-starfive-jh7110-vout"
              "clk-starfive-jh7110-isp"
              "clk-starfive-jh7100-audio"
              "phy-jh7110-pcie"
              "pcie-starfive"
              "nvme"
            ];
            blacklistedKernelModules = [
              "jh7110-crypto" # Crashes
            ];

            loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
          };

          systemd.services."serial-getty@hvc0".enable = false;

          # If getty is not explicitly enabled, it will not start automatically.
          # https://github.com/NixOS/nixpkgs/issues/84105
          systemd.services."serial-getty@ttyS0" = {
            enable = true;
            wantedBy = [ "getty.target" ];
            serviceConfig.Restart = "always";
          };

          services.openssh = {
            enable = true;
            settings.PermitRootLogin = "yes";
          };

          networking.firewall.allowedTCPPorts = [ 22 ];

          users = {
            mutableUsers = false;
            users.root.password = "secret";
          };

          system.stateVersion = "23.11";

          environment = {
              systemPackages = with pkgs; [
              neofetch
              lshw
              pciutils
              parted
              git
              nixos-install-tools
              lm_sensors
            ];

            etc."nixos/source".source = ./.;
          };
        })
        ({lib, ...}: {
          nix.nixPath = [ "/etc/nix/inputs" ];

          environment.etc = lib.mapAttrs' (name: value: {
            name = "nix/inputs/${name}";
            value.source = value.outPath;
          }) inputs;

          nix.registry = builtins.mapAttrs (name: value: {
            flake = value;
          }) inputs;

          nix.extraOptions = ''
              experimental-features = nix-command flakes
            '';
        })
      ];
    };

    packages.riscv64-linux = let
      pkgs = nixpkgs.legacyPackages.riscv64-linux.extend self.overlays.default;
    in rec {
      uboot = (pkgs.buildUBoot {
        version = uboot-src.shortRev;
        src = uboot-src;
        defconfig = "starfive_visionfive2_defconfig";
        filesToInstall = [
          "u-boot.itb"
          "spl/u-boot-spl.bin"
        ];
        makeFlags = [
          "OPENSBI=${pkgs.opensbi}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin"
        ];
      }).overrideAttrs (old: {
        # some RPI patch doesn't work
        patches = [];
      });

      opensbi = pkgs.opensbi.overrideAttrs (old: {
        makeFlags = old.makeFlags ++ [ "FW_TEXT_START=0x40000000" ];
      });

      firmware = pkgs.stdenvNoCC.mkDerivation {
        name = "firmware-vf2";
        dontUnpack = true;
        nativeBuildInputs = [ spl-tool pkgs.dtc pkgs.ubootTools ];
        installPhase = ''
          runHook preInstall

          mkdir -p "$out/"

          cp ${uboot}/u-boot-spl.bin u-boot-spl.bin
          spl_tool -c -f ./u-boot-spl.bin

          install -Dm444 ./u-boot-spl.bin.normal.out $out/u-boot-spl.bin.normal.out
          install -Dm444 ${uboot}/u-boot.itb $out/visionfive2_fw_payload.img

          runHook postInstall
        '';
      };

      kernel = pkgs.callPackage ./pkgs/linux-vf2.nix { kernelPatches = [ ]; };

      spl-tool = pkgs.callPackage
        ({ lib, stdenv, fetchFromGitHub }: stdenv.mkDerivation rec {
          pname = "spl-tool";
          version = "1.0";

          src = starfive-tools-src;

          installPhase = ''
            mkdir -p "$out/bin/"
            cp spl_tool "$out/bin/"
          '';

          sourceRoot = "source/spl_tool";
        })
        {};

      sd = nixosConfigurations.sd.config.system.build.sdImage;
      sd-system = nixosConfigurations.sd.config.system.build.toplevel;
    };
    # For ease of building.
    packages.x86_64-linux = packages.riscv64-linux;

    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
   in pkgs.stdenv.mkDerivation {
      name = "VisionFive 2 Test";

      nativeBuildInputs = with pkgs; [ picocom zstd pv ];
    };
  };
}
