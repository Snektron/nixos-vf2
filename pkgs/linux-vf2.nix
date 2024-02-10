{ lib , fetchFromGitHub , buildLinux, fetchpatch, ... } @ args:
buildLinux (args // rec {
  modDirVersion = "6.6.0";
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "linux";
    rev = "076ede06c00a4069cd9f90d609eaf35bf1bdc68a";
    hash = "sha256-oI048iCkvghEIiuDHbxNHtJz/krPwXPB/HB85YUaxL8=";
  };

  structuredExtraConfig = with lib.kernel; {
    # According to starfive-tech/linux readme
    CPU_FREQ = yes;
    CPUFREQ_DT = yes;
    CPUFREQ_DT_PLATDEV = yes;
    DMADEVICES = yes;
    GPIO_SYSFS = yes;
    HIBERNATION = yes;
    NO_HZ_IDLE = yes;
    POWER_RESET_GPIO_RESTART = yes;
    PROC_KCORE = yes;
    PWM = yes;
    PWM_STARFIVE_PTC = yes;
    RD_GZIP = yes;
    SENSORS_SFCTEMP = yes;
    SERIAL_8250_DW = yes;
    SIFIVE_CCACHE = yes;
    SIFIVE_PLIC = yes;

    RTC_DRV_STARFIVE = yes;
    SPI_PL022 = yes;
    SPI_PL022_STARFIVE = yes;

    I2C = yes;
    MFD_AXP20X = yes;
    MFD_AXP20X_I2C = yes;
    REGULATOR_AXP20X = yes;

    DRM = yes;
    DRM_VERISILICON = yes;
    STARFIVE_HDMI = yes;

    PL330_DMA = no;

    # Disable some drivers that we don't need to make the build leaner
    NET_VENDOR_MELLANOX = no;
    NET_VENDOR_MARVELL = no;
    DRM_NOUVEAU = no;
    DRM_INTEL = no;
  };

  preferBuiltin = true;

  extraMeta = {
    branch = "JH7110_VisionFive2_upstream";
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
