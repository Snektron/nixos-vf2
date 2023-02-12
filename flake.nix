{
  description = "VisionFive 2 test flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
  };

  outputs = { self, nixpkgs }: rec {
    nixosConfigurations.rattlesnake = nixpkgs.lib.nixosSystem {
      system = "riscv64-linux";
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image.nix"
        "${nixpkgs}/nixos/modules/profiles/minimal.nix"

        ({ lib, config, pkgs, ... }: {
          nixpkgs = {
            localSystem.config = "x86_64-linux";
            crossSystem.config = "riscv64-linux";
          };

          hardware.deviceTree.name = "starfive/jh7110-starfive-visionfive-v2.dtb";

          sdImage = {
            populateFirmwareCommands = "";
            populateRootCommands = ''
              mkdir -p ./files/boot
              ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
            '';
          };

          boot = {
            supportedFilesystems = lib.mkForce [ "vfat" ];
            kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./linux-vf2.nix { kernelPatches = [ ]; });
            kernelParams = [
              "console=tty0"
              "console=ttyS0,115200"
              "earlycon=sbi"
              "boot.shell_on_fail"
            ];

            loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
          };

          services = {
            getty.autologinUser = "root";
            openssh = {
              enable = true;
              permitRootLogin = "yes";
            };
          };

          users = {
            mutableUsers = false;
            users.root.password = "secret";
          };

          system.stateVersion = "22.11";

          environment.systemPackages = with pkgs; [ neofetch ];
        })
      ];
    };
    packages.x86_64-linux.rattlesnake-sd = nixosConfigurations.rattlesnake.config.system.build.sdImage;
    devShells.x86_64-linux.default = let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
   in pkgs.stdenv.mkDerivation {
      name = "VisionFive 2 Test";
    };
  };
}
