# sd-image.nix specialized for the VisionFive 2.

{ config, lib, pkgs, modulesPath, ... }:
with lib;
let
  rootfsImage = pkgs.callPackage (pkgs.path + "/nixos/lib/make-ext4-fs.nix") {
    inherit (config.sdImage.root) storePaths;
    compressImage = true;
    volumeLabel = config.sdImage.root.name;
  };
in {
  imports = [
    (modulesPath + "/profiles/all-hardware.nix")
  ];

  options.sdImage = let
    partitionOptions = { name, defaultOffset ? null, defaultSize ? null, defaultTypeUUID }: {
      name = mkOption {
        type = types.str;
        default = name;
        description = "Partition name";
      };

      offset = mkOption {
        type = types.nullOr types.int;
        default = defaultOffset;
        description = "Partition start offset, in MiB";
      };

      # TODO: Optional only for root.
      size = mkOption {
        type = types.nullOr types.int;
        default = defaultSize;
        description = "Partition size, in MiB";
      };

      partitionTypeUUID = mkOption {
        type = types.str;
        default = defaultTypeUUID;
        description = "Partition type UUID";
      };
    };

    imagePartitionOptions = {
      image = mkOption {
        type = types.path;
        description = "Partition main image";
      };
    };

    mkSubmodule = opts: types.submodule { options = opts; };
  in {
    imageName = mkOption {
      default = "${config.sdImage.imageBaseName}-${config.system.nixos.label}-${pkgs.stdenv.hostPlatform.system}.img";
      description = ''
        Name of the generated image file.
      '';
    };

    imageBaseName = mkOption {
      default = "nixos-sd-image";
      description = ''
        Prefix of the name of the generated image file.
      '';
    };

    compressImage = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether the SD image should be compressed using
        <command>zstd</command>.
      '';
    };

    spl = mkOption {
      description = "SPL partition options";
      type = mkSubmodule ((partitionOptions {
        name = "spl";
        defaultOffset = 2;
        defaultSize = 2;
        defaultTypeUUID = "2E54B353-1271-4842-806F-E436D6AF6985";
      }) // imagePartitionOptions);
    };

    uboot = mkOption {
      description = "u-boot partition options";
      type = mkSubmodule ((partitionOptions {
        name = "uboot";
        defaultSize = 4;
        defaultTypeUUID = "5B193300-FC78-40CD-8002-E86C45580B47";
      }) // imagePartitionOptions);
    };

    firmware = mkOption {
      description = "firmware partition options";
      type = mkSubmodule ((partitionOptions {
        name = "FIRMWARE";
        defaultSize = 58;
        defaultTypeUUID = "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7";
      }) // {
        populateCmd = mkOption {
          type = types.str;
          description = ''
            Shell commands to populate the boot directory. All
             files in the current directory are copied to the boot (/boot)
             partition of the SD image.
          '';
        };
      });
    };

    root = mkOption {
      description = "root partition options";
      type = mkSubmodule ((partitionOptions {
        name = "NIXOS_SD";
        defaultTypeUUID = "0FC63DAF-8483-4772-8E79-3D69D8477DE4";
      }) // {
        expandOnBoot = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether to configure the sd image to expand it's partition on boot.
          '';
        };

        storePaths = mkOption {
          type = types.listOf types.package;
          example = literalExpression "[ pkgs.stdenv ]";
          description = ''
            Derivations to be included in the Nix store in the generated SD image.
          '';
        };
      });
    };
  };

  config = {
    fileSystems = {
      "/boot/firmware" = {
        device = "/dev/disk/by-label/${config.sdImage.firmware.name}";
        fsType = "vfat";
        options = [ "nofail" "noauto" ];
      };
      "/" = {
        device = "/dev/disk/by-label/${config.sdImage.root.name}";
        fsType = "ext4";
      };
    };

    sdImage.root.storePaths = [ config.system.build.toplevel ];

    system.build.sdImage = pkgs.callPackage (
      { stdenvNoCC, genimage, dosfstools, mtools, zstd, libfaketime }:
      stdenvNoCC.mkDerivation {
        name = config.sdImage.imageName;
        nativeBuildInputs = [ genimage dosfstools mtools zstd libfaketime ];

        inherit (config.sdImage) compressImage;

        buildCommand = ''
          # TODO: Hydra build products?
          img=$out/sd-image/${config.sdImage.imageName}
          mkdir -p "$out/sd-image"

          echo "Decompressing rootfs image"
          zstd -d --no-progress "${rootfsImage}" -o ./root-fs.img

          # Generate a FAT32 firmware filesystem.
          truncate -s ${assert config.sdImage.firmware.size != null; toString config.sdImage.firmware.size}M firmware-fs.img
          faketime "1970-01-01 00:00:00" mkfs.vfat -n ${config.sdImage.firmware.name} firmware-fs.img

          mkdir firmware
          ${config.sdImage.firmware.populateCmd}

          # Copy the populated files to the image.
          (cd firmware; mcopy -psvm -i ../firmware-fs.img ./* ::)
          # Verify the FAT partition.
          fsck.vfat -vn firmware-fs.img

          # Generate the genfs config.
          cat > genimage.cfg <<EOF
          image sdcard.img {
            hdimage {
              partition-table-type = "gpt"
            }

            partition ${config.sdImage.spl.name} {
              image = ${config.sdImage.spl.image}
              partition-type-uuid = ${config.sdImage.spl.partitionTypeUUID}
              ${optionalString (config.sdImage.spl.offset != null) "offset = ${toString config.sdImage.spl.offset}M"}
              ${optionalString (config.sdImage.spl.size != null) "size = ${toString config.sdImage.spl.size}M"}
            }

            partition ${config.sdImage.uboot.name} {
              image = ${config.sdImage.uboot.image}
              partition-type-uuid = ${config.sdImage.uboot.partitionTypeUUID}
              ${optionalString (config.sdImage.uboot.offset != null) "offset = ${toString config.sdImage.uboot.offset}M"}
              ${optionalString (config.sdImage.uboot.size != null) "size = ${toString config.sdImage.uboot.size}M"}
            }

            partition ${config.sdImage.firmware.name} {
              image = ./firmware-fs.img
              partition-type-uuid = ${config.sdImage.firmware.partitionTypeUUID}
              ${optionalString (config.sdImage.firmware.offset != null) "offset = ${toString config.sdImage.firmware.offset}M"}
              ${optionalString (config.sdImage.firmware.size != null) "size = ${toString config.sdImage.firmware.size}M"}
            }

            partition ${config.sdImage.root.name} {
              image = ./root-fs.img
              partition-type-uuid = ${config.sdImage.root.partitionTypeUUID}
              ${optionalString (config.sdImage.root.offset != null) "offset = ${toString config.sdImage.root.offset}M"}
              ${optionalString (config.sdImage.root.size != null) "size = ${toString config.sdImage.root.size}M"}
            }
          }
          EOF

          # Generate the image.
          genimage --inputpath . --outputpath . --config ./genimage.cfg
          mv sdcard.img "$img"

          if test -n "$compressImage"; then
            zstd -T$NIX_BUILD_CORES --rm "$img"
          fi
        '';
      }
    ) {};

    boot.postBootCommands = lib.mkIf config.sdImage.root.expandOnBoot ''
      # On the first boot do some maintenance tasks
      if [ -f /nix-path-registration ]; then
        set -euo pipefail
        set -x
        # Figure out device names for the boot device and root filesystem.
        rootPart=$(${pkgs.util-linux}/bin/findmnt -n -o SOURCE /)
        bootDevice=$(lsblk -npo PKNAME $rootPart)
        partNum=$(lsblk -npo MAJ:MIN $rootPart | ${pkgs.gawk}/bin/awk -F: '{print $2}')

        # Resize the root partition and the filesystem to fit the disk
        echo ",+," | sfdisk -N$partNum --no-reread $bootDevice
        ${pkgs.parted}/bin/partprobe
        ${pkgs.e2fsprogs}/bin/resize2fs $rootPart

        # Register the contents of the initial Nix store
        ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

        # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
        touch /etc/NIXOS
        ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

        # Prevents this from running on later boots.
        rm -f /nix-path-registration
      fi
    '';
  };
}
