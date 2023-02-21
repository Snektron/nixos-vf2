{ lib , fetchFromGitHub , buildLinux , ... } @ args:
let
  modDirVersion = "5.15.0";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "linux";
    rev = "JH7110_VisionFive2_devel";
    sha256 = "sha256-o1k1UDUXUsRb4200zZ5ozVL15g7wsheet8O5UhX2HWY=";
  };

  kernelPatches = [
    { name = "crypto-dh"; patch = ../patches/0001-security-keys-dh-dh_data_from_key-takes-const-void-d.patch; }
    { name = "pl022-remove-module-platform-driver"; patch = ../patches/0002-pl022-remove-module-platform-driver.patch; }
    { name = "sound-soc-starfive"; patch = ../patches/0003-sound-soc-starfive-remove-starfive_pwmdac_transmitter.patch; }
    { name = "disable-sm4"; patch = ../patches/0004-disable-sm4.patch; }
    { name = "starfive-media"; patch = ../patches/0006-media-starfive-kill-some-modules.patch; }
  ];

  defconfig = "starfive_visionfive2_defconfig";

  structuredExtraConfig = with lib.kernel; {
    SOC_STARFIVE = yes;
    SOC_STARFIVE_JH7110 = yes;
    CLK_STARFIVE_JH7110_SYS = yes;
    RESET_STARFIVE_JH7110 = yes;
    PINCTRL_STARFIVE_JH7110 = yes;
    SERIAL_8250_DW = yes;
    RTC_DRV_STARFIVE = yes;
    MMC_DW_STARFIVE = yes;
    MMC_DW_PLTFM = yes;
    MMC_DW = yes;
    MMC = yes;

    SOC_STARFIVE_VIC7100 = no;
    SOC_MICROCHIP_POLARFIRE = no;

    # Broken stuff.
    PL330_DMA = no;
    DRM_I2C_CH7006 = no;
    DRM_I2C_SIL164 = no;
    DRM_I2C_NXP_TDA998X = no;
    DRM_I2C_NXP_TDA9950 = no;
    DRM_NOUVEAU = no;
    DRM_VERISILICON = no;
    CRYPTO_RMD128 = no;
    CRYPTO_RMD256 = no;
    CRYPTO_RMD320 = no;
    CRYPTO_TGR192 = no;
    CRYPTO_SALSA20 = no;
    SND_SOC_WM8960 = no;
    USB_WIFI_ECR6600U = no;

    DEBUG_INFO_BTF = lib.mkForce no;
    DEBUG_INFO_BTF_MODULES = lib.mkForce no;

    DRM_IMG_ROGUE = no; # We're going to need this one

    VIRTIO_MENU = yes;
    VIRTIO = module;
    VIRTIO_PCI_LIB = module;
    VIRTIO_PCI = module;
  };

  extraMeta = {
    branch = "visionfive2";
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
