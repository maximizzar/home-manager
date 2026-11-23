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
  finalPackage = pkgs.symlinkJoin {
    name = "oxipng-wrapped";
    paths = [ cfg.package ];

    nativeBuildInputs = [ pkgs.makeWrapper ];

    postBuild = ''
      wrapProgram $out/bin/oxipng \
        --opt ${toString cfg.settings.optimizationLevel} \
        ${lib.optionalString cfg.settings.preserve "--preserve"} \
        ${lib.optionalString (cfg.settings.strip != null) "--strip ${cfg.settings.strip}"} \
        ${lib.optionalString cfg.settings.alpha "--alpha"} \
        ${lib.optionalString (cfg.settings.interlace != "off") "--interlace ${cfg.settings.interlace}"} \
        ${lib.optionalString cfg.settings.fast "--fast"} \
        ${lib.optionalString cfg.settings.zopfli.enable "--zopfli"} \
        ${
          lib.optionalString (
            cfg.settings.zopfli.interations != null
          ) "--zi ${toString cfg.settings.zopfli.iterations}"
        } \
        ${lib.optionalString (
          cfg.settings.zopfli.maxIterationsWithoutImprovement != null
        ) "--ziwi ${toString cfg.settings.zopfli.maxIterationsWithoutImprovement}"}
    '';
  };
in
{
  meta.maintainers = with lib.maintainers; [ maximizzar ];
  options.programs.oxipng = {
    enable = lib.mkEnableOption "oxipng, a Multithreaded PNG optimizer written in Rust";
    package = lib.mkPackageOption pkgs "oxipng" { };
    settings = {
      optimizationLevel = lib.mkOption {
        type = lib.types.either lib.types.enum [ "max" ] (lib.types.ints.between 0 6);
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

      preserve = lib.mkEnableOption "Preserve file permissions and timestamps if possible.";
      strip = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Strip metadata chunks, where <mode> is one of:

              safe    =>  Strip all non-critical chunks, except for the following:
                              cICP, iCCP, sRGB, pHYs, acTL, fcTL, fdAT
              all     =>  Strip all non-critical chunks
              <list>  =>  Strip chunks in the comma-separated list, e.g. 'bKGD,cHRM'

          CAUTION: 'all' will convert APNGs to standard PNGs.

          Please note that regardless of any options set, some chunks will necessarily be
          stripped when invalidated by the optimization:
              bKGD, sBIT, hIST: Stripped if the color type or bit depth changes.
              iDOT: Always stripped.
              caBX: Stripped if it contains C2PA metadata. If explicitly retained by `--keep`,
              optimization will be aborted.

          The default is to keep all chunks that remain valid.
        '';

        alpha = lib.mkEnableOption ''
          Perform additional optimization on images with an alpha channel, by altering the
          color values of fully transparent pixels. This is generally recommended for better
          compression, but take care as while this is “visually lossless”, it is technically a
          lossy transformation and may be unsuitable for some applications.
        '';

        interlace = lib.mkOption {
          type = lib.types.enum [
            "off"
            "on"
            "keep"
          ];
          default = "off";
          description = ''
            Set the PNG interlacing mode, where <mode> is one of:

                off   =>  Remove interlacing from all images that are processed
                on    =>  Apply Adam7 interlacing on all images that are processed
                keep  =>  Keep the existing interlacing mode of each image

            Note that interlacing can add 25-50% to the size of an optimized image. Only use it
            if you believe the benefits outweigh the costs for your use case.
          '';

        };

        fast = lib.mkEnableOption ''
          Perform a fast compression evaluation of each enabled filter, followed by a single
          main compression trial of the best result. Recommended if you have more filters
          enabled than CPU cores.
        '';

        zopfli = {
          enable = lib.mkEnableOption ''
            Use the much slower but stronger Zopfli compressor for main compression trials.
            Recommended use is with 'optimizationLevel="max"' and 'fast'.
          '';
          iterations = lib.mkEnableOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = ''
              Set the number of iterations to use for Zopfli compression. Using fewer iterations
              may speed up compression for large files.
            '';
          };

          maxIterationsWithoutImprovement = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = ''
              Stop Zopfli compression after this number of iterations without improvement. Use this
              in conjunction with a high value for '--zi' to achieve better compression in
              reasonable time.
            '';
          };

        };
      };
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      default = finalPackage;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.finalPackage ];
  };
}
