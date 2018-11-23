{ stdenv
, substituteAll
, libstartup_notification
, fetchFromGitHub
# runtime dependencies
, python36Packages # pygments
, harfbuzz
, zlib
, libpng
, freetype ? null
, fontconfig ? null
, imagemagick
# all build dependencies
, pkgconfig
# linux build dependencies
, dbus ? null
, libXcursor ? null
, libXrandr ? null
, libXi ? null
, libXinerama ? null
, libGL ? null
, libxkbcommon ? null
# darwin build dependencies
, darwin
# not documented dependencies
, ncurses
}:

with python36Packages;
buildPythonApplication rec {
  version = "0.12.3";
  name = "kitty-${version}";
  format = "other";

  src = fetchFromGitHub {
    owner = "kovidgoyal";
    repo = "kitty";
    rev = "v${version}";
    sha256 = "1nhk8pbwr673gw9qjgca4lzjgp8rw7sf99ra4wsh8jplf3kvgq5c";
  };

  OVERRIDE_CFLAGS = [ "-Wno-error=four-char-constants" ];
  NIX_CFLAGS_COMPILE = [ "-Wno-error=unused-command-line-argument" ];

  buildInputs = with darwin.apple_sdk.frameworks; [
    harfbuzz zlib libpng python36Packages.pygments imagemagick
    ncurses
  ] ++ stdenv.lib.optionals stdenv.isLinux [
    freetype fontconfig dbus libXcursor libXrandr libXi
    libXinerama libGL libxkbcommon
  ] ++ stdenv.lib.optionals stdenv.isDarwin [
    Cocoa CoreText CoreGraphics IOKit CoreFoundation CoreVideo OpenGL
  ];

  nativeBuildInputs = [ pkgconfig ];

  outputs = [ "out" "terminfo" ];

  patches = [
    (substituteAll {
      src = ./fix-paths.patch;
      libstartup_notification = "${libstartup_notification}/lib/libstartup-notification-1.so";
    })
  ];

  buildPhase = ''
    python3 setup.py linux-package
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r linux-package/{bin,share,lib} $out
    wrapProgram "$out/bin/kitty" --prefix PATH : "$out/bin:${stdenv.lib.makeBinPath [ harfbuzz zlib libpng python36Packages.pygments imagemagick ]}"
    runHook postInstall
  '';

  postInstall = ''
    mkdir -p $terminfo/share
    mv $out/share/terminfo $terminfo/share/terminfo

    mkdir -p $out/nix-support
    echo "$terminfo" >> $out/nix-support/propagated-user-env-packages
  '';

  meta = with stdenv.lib; {
    homepage = https://github.com/kovidgoyal/kitty;
    description = "A modern, hackable, featureful, OpenGL based terminal emulator";
    license = licenses.gpl3;
    platforms = platforms.unix;
    maintainers = with maintainers; [ tex rvolosatovs ];
  };
}
