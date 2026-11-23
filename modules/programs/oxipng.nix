# SPDX-FileCopyrightText: 2026 maximizzar <mail@maximizzar.de>
#
# SPDX-License-Identifier: MIT
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.oxipng;
  toArgs =
    opts:
    lib.concatLists (
      lib.mapAttrsToList (
        name: value:
        let
          flag = if builtins.stringLength name == 1 then "-${name}" else "--${name}";
        in
        if value == null || value == false then
          [ ]
        else if value == true then
          [ flag ]
        else if lib.isList value then
          [
            flag
            (lib.concatMapStringsSep "," toString value)
          ]
        else
          [
            flag
            (toString value)
          ]
      ) opts
    );

  cliOptions = {
    opt = cfg.optimizationLevel;
  }
  // lib.optionalAttrs cfg.preserve { preserve = true; }
  // lib.optionalAttrs (cfg.threads != null) { inherit (cfg) threads; };

  allOptions = cfg.settings // cliOptions;
  shellArgs = lib.escapeShellArgs (toArgs allOptions);

  finalPackage = pkgs.symlinkJoin {
    name = "oxipng-wrapped";
    paths = [ cfg.package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/oxipng \
      --add-flags ${lib.escapeShellArg shellArgs}
    '';
  };
in
{
  meta.maintainers = with lib.maintainers; [ maximizzar ];
  options.programs.oxipng = {
    enable = lib.mkEnableOption "oxipng, a Multithreaded PNG optimizer written in Rust";
    package = lib.mkPackageOption pkgs "oxipng" { };

    optimizationLevel = lib.mkOption {
      type = lib.types.either (lib.types.enum [ "max" ]) (lib.types.ints.between 0 6);
      default = 2;
      description = ''
        Set the optimization level preset. The default level 2 is quite fast and provides
        good compression. Lower levels are faster, higher levels provide better compression,
        though with increasingly diminishing returns.

            0   => --zc 5  --fast              (filter chosen heuristically)
            1   => --zc 10 --fast              (filter chosen heuristically)
            2   => --zc 11 -f 0,1,6,7 --fast
            3   => --zc 11 -f 0,7,8,9         --brute-level 1 --brute-lines 3
            4   => --zc 12 -f 0,7,8,9         --brute-level 1 --brute-lines 4
            5   => --zc 12 -f 0,1,2,5,6,7,8,9 --brute-level 4 --brute-lines 4
            6   => --zc 12 -f 0-9             --brute-level 5 --brute-lines 8
            true => (allways use the maximum lvl)

        Manually specifying a compression option (zc, f, etc.) will override the optimization
        preset, regardless of the order you write the arguments.
      '';
    };

    preserve = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Preserve file permissions and timestamps if possible.";
    };

    threads = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Maximum number of threads to use. Defaults to the number of logical CPUs.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Configuration options passed to oxipng as cli argument.
        This makes an option a default, that can't be changed at command runtime.
      '';
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      default = finalPackage;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions =
      let
        duplicateOptions = builtins.attrNames (lib.intersectAttrs cliOptions cfg.settings);
      in
      [
        {
          assertion = duplicateOptions == [ ];
          message = ''
            programs.oxipng: The following options must not be
            specified in both dedicated options and settings:
            ${lib.concatStringsSep ", " duplicateOptions}
          '';
        }
      ];
    home.packages = [ cfg.finalPackage ];
  };
}
