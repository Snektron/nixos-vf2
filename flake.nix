{
  description = "VisionFive 2 test flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    ubootSrc = {
      flake = false;
      url = "github:Snektron/u-boot-vf2";
    };
  };

  outputs = { self, nixpkgs, ubootSrc }: rec {
    overlays.default = self: super: {
      # glib is broken
      util-linux = super.util-linux.override { translateManpages = false; };
    };

    nixosConfigurations.rattlesnake = nixpkgs.lib.nixosSystem {
      system = "riscv64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/profiles/minimal.nix"
        ({ lib, config, pkgs, ... }: {
          imports = [
            ./modules/sd-image-visionfive2.nix
          ];

          nixpkgs = {
            overlays = [ self.overlays.default ];

            localSystem.config = "x86_64-linux";
            crossSystem.config = "riscv64-linux";
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
            ];

            initrd.includeDefaultModules = false;
            initrd.availableKernelModules = [
              "dw_mmc-pltfm"
              "dw_mmc-starfive"
              "dwmac-starfive"
              "spi-dw-mmio"
              "mmc_block"
              "nvme"
              "sdhci"
              "sdhci-pci"
              "sdhci-of-dwcmshc"
            ];

            loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
          };

          systemd.services."serial-getty@hvc0".enable = false;

          services = {
            getty.autologinUser = "root";
            # openssh = {
            #   enable = true;
            #   permitRootLogin = "yes";
            # };
          };

          users = {
            mutableUsers = false;
            users.root.password = "secret";
          };

          system.stateVersion = "22.11";

          environment.systemPackages = with pkgs; [ neofetch lshw pciutils ];
        })
      ];
    };

    packages.x86_64-linux = let
      pkgs-cross = import nixpkgs {
        localSystem.config = "x86_64-linux";
        crossSystem.config = "riscv64-linux";
      };
      pkgs = import nixpkgs {
        system = "x86_64-linux";
      };
    in rec {
      rattlesnake-sd = nixosConfigurations.rattlesnake.config.system.build.sdImage;
      kernel = pkgs-cross.linuxPackagesFor (pkgs-cross.callPackage ./pkgs/linux-vf2.nix { kernelPatches = [ ]; });
      splTool = pkgs.callPackage ./pkgs/spl_tool.nix { };

      uboot = pkgs-cross.buildUBoot {
        version = "2021.10";
        src = ubootSrc;
        defconfig = "starfive_visionfive2_defconfig";
        filesToInstall = [
          "u-boot.bin"
          "spl/u-boot-spl.bin"
          "arch/riscv/dts/starfive_visionfive2.dtb"
        ];
      };

      opensbi = (pkgs-cross.opensbi.override {
        withPayload = "${uboot}/u-boot.bin";
        withFDT = "${uboot}/starfive_visionfive2.dtb";
      }).overrideAttrs (old: {
        makeFlags = old.makeFlags ++ [ "FW_TEXT_START=0x40000000" ];
      });

      firmware = pkgs-cross.stdenvNoCC.mkDerivation {
        name = "firmware-vf2";
        dontUnpack = true;
        nativeBuildInputs = [ splTool pkgs.dtc pkgs.ubootTools ];
        installPhase = ''
          runHook preInstall

          mkdir -p "$out/"
          cp ${uboot}/u-boot-spl.bin u-boot-spl.bin
          spl_tool -c -f ./u-boot-spl.bin -v 0x01010101
          mv ./u-boot-spl.bin.normal.out "$out/"
          rm ./u-boot-spl.bin

          # TODO: Maybe we can fetch this image directly from github too.
          substitute ${./visionfive2-uboot-fit-image.its} visionfive2-uboot-fit-image.its \
            --replace fw_payload.bin ${opensbi}/share/opensbi/lp64/generic/firmware/fw_payload.bin
          mkimage -f visionfive2-uboot-fit-image.its -A riscv -O u-boot -T firmware $out/visionfive2_fw_payload.img

          runHook postInstall
        '';
      };
    };

    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
   in pkgs.stdenv.mkDerivation {
      name = "VisionFive 2 Test";

      nativeBuildInputs = [ pkgs.picocom ];
    };
  };
}
