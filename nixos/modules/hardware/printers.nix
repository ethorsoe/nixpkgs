{ config, lib, pkgs, utils, ... }:
with lib;
let
  cfg = config.hardware.printers;
  ppdOptionsString = options: optionalString (options != {})
    (concatStringsSep " "
      (mapAttrsToList (name: value: "-o '${name}'='${value}'") options)
    );
  ensurePrinter = p: ''
    ${pkgs.cups}/bin/lpadmin -p '${p.name}' -E \
      ${optionalString (p.location != null) "-L '${p.location}'"} \
      ${optionalString (p.description != null) "-D '${p.description}'"} \
      -v '${p.deviceUri}' \
      -m '${p.model}' \
      ${ppdOptionsString p.ppdOptions}
  '';
  ensureDefaultPrinter = name: ''
    ${pkgs.cups}/bin/lpadmin -d '${name}'
  '';

  # "graph but not # or /" can't be implemented as regex alone due to missing lookahead support
  noInvalidChars = str: all (c: c != "#" && c != "/") (stringToCharacters str);
  printerName = (types.addCheck (types.strMatching "[[:graph:]]+") noInvalidChars)
    // { description = "printable string without spaces, # and /"; };


in {
  options = {
    hardware.printers = {
      ensureDefaultPrinter = mkOption {
        type = types.nullOr printerName;
        default = null;
        description = lib.mdDoc ''
          Ensures the named printer is the default CUPS printer / printer queue.
        '';
      };
      ensurePrinters = mkOption {
        description = lib.mdDoc ''
          Will regularly ensure that the given CUPS printers are configured as declared here.
          If a printer's options are manually changed afterwards, they will be overwritten eventually.
          This option will never delete any printer, even if removed from this list.
          You can check existing printers with {command}`lpstat -s`
          and remove printers with {command}`lpadmin -x <printer-name>`.
          Printers not listed here can still be manually configured.
        '';
        default = [];
        type = types.listOf (types.submodule {
          options = {
            name = mkOption {
              type = printerName;
              example = "BrotherHL_Workroom";
              description = lib.mdDoc ''
                Name of the printer / printer queue.
                May contain any printable characters except "/", "#", and space.
              '';
            };
            location = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "Workroom";
              description = lib.mdDoc ''
                Optional human-readable location.
              '';
            };
            description = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "Brother HL-5140";
              description = lib.mdDoc ''
                Optional human-readable description.
              '';
            };
            deviceUri = mkOption {
              type = types.str;
              example = literalExpression ''
                "ipp://printserver.local/printers/BrotherHL_Workroom"
                "usb://HP/DESKJET%20940C?serial=CN16E6C364BH"
              '';
              description = lib.mdDoc ''
                How to reach the printer.
                {command}`lpinfo -v` shows a list of supported device URIs and schemes.
              '';
            };
            model = mkOption {
              type = types.str;
              example = literalExpression ''
                "gutenprint.''${lib.versions.majorMinor (lib.getVersion pkgs.gutenprint)}://brother-hl-5140/expert"
              '';
              description = lib.mdDoc ''
                Location of the ppd driver file for the printer.
                {command}`lpinfo -m` shows a list of supported models.
              '';
            };
            ppdOptions = mkOption {
              type = types.attrsOf types.str;
              example = {
                PageSize = "A4";
                Duplex = "DuplexNoTumble";
              };
              default = {};
              description = lib.mdDoc ''
                Sets PPD options for the printer.
                {command}`lpoptions [-p printername] -l` shows suported PPD options for the given printer.
              '';
            };
            udevTrigger = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = ''SUBSYSTEM=="usb", ACTION=="add", ATTRS{idVendor}=="04e8", ATTRS{idProduct}=="342e"'';
              description = lib.mdDoc ''
                Optional trigger to add the printer, as the default service may fail, if the device is not connected.
              '';
            };
          };
        });
      };
    };
  };

  config =
    let
      cupsUnit = if config.services.printing.startWhenNeeded then "cups.socket" else "cups.service";
      baseService = {
        description = "Ensure NixOS-configured CUPS printers";
        requires = [ cupsUnit ];
        after = [ cupsUnit ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
      multiUserPrinters = builtins.filter (x: x.udevTrigger == null) cfg.ensurePrinters;
      triggeredPrinters = builtins.filter (x: x.udevTrigger != null) cfg.ensurePrinters;
      multiUserDefaultPrinter = builtins.any
        (x: cfg.ensureDefaultPrinter == x.name)
        multiUserPrinters;
      mapTriggeredPrinter = s: {
        name = "ensure-printer-${utils.systemdUtils.escapeSystemdPath s.name}";
        value = baseService // {
          script = ensurePrinter s + "\n" + lib.optionalString
            (s: cfg.ensureDefaultPrinter == s.name) (ensureDefaultPrinter cfg.ensureDefaultPrinter);
        };
      };
    in
      mkIf (cfg.ensurePrinters != [] && config.services.printing.enable) {
        systemd.services. = {
          ensure-printers = mkIf (multiUserPrinters != [ ]) (baseService // {
            script = concatMapStringsSep "\n" ensurePrinter multiUserPrinters
              + optionalString multiUserDefaultPrinter (ensureDefaultPrinter cfg.ensureDefaultPrinter);
            wantedBy = [ "multi-user.target" ];
          });
        } // listToAttrs (map mapTriggeredPrinter triggeredPrinters);
        services.udev.extraRules = concatMapStringsSep "\n" (s:
          ''${s.udevTrigger}, TAG+="systemd", ENV{SYSTEMD_WANTS}="ensure-printer-${utils.systemdUtils.escapeSystemdPath s.name}.service"'')
          triggeredPrinters;
      };
}
