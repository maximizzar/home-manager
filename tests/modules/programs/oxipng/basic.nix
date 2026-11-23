# SPDX-FileCopyrightText: 2026 maximizzar <mail@maximizzar.de>
#
# SPDX-License-Identifier: MIT
{
  test.stubs.oxipng = {
    buildScript = ''
      mkdir -p $out/bin
      touch $out/bin/oxipng
      chmod +x $out/bin/oxipng
    '';
  };

  programs.oxipng = {
    enable = true;
    threads = 4;
    settings.strip = "safe";
  };

  nmt.script = ''
    assertFileContains "home-path/bin/oxipng" "--opt 2"
    assertFileContains "home-path/bin/oxipng" "--threads 4"
    assertFileContains "home-path/bin/oxipng" "--strip safe"
  '';
}
