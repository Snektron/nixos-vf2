{ lib, stdenv, fetchFromGitHub }:
stdenv.mkDerivation rec {
  pname = "splTool";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "Tools";
    rev = "1656fda1fbf79b7d15a654e34be6e0058407b017";
    sha256 = "sha256-U3wZLE3yBzTnGn6aO3M1YzNAjQGbxU1YQT5hT4gqwiY=";
  };

  installPhase = ''
    mkdir -p "$out/bin/"
    cp spl_tool "$out/bin/"
  '';

  sourceRoot = "${src.name}/spl_tool";
}
