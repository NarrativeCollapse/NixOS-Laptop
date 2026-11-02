# The whole system, in one file on purpose. Read it top to bottom.
# Every option is documented offline: `man configuration.nix`.
{ lib, pkgs, ... }:

let
  user = "user"; # CHANGE ME: your login name
in
{
  imports = [ ./hardware-configuration.nix ];

  # The release this machine was first installed with. It is not the
  # version you run. Leave it alone when you upgrade.
  system.stateVersion = "26.05";

  # ---------------------------------------------------------------- boot
  # The kernel is left at the NixOS default, which is the newest
  # upstream LTS kernel.
  boot.loader.systemd-boot = {
    enable = true;
    editor = false; # no editing the kernel command line at boot (init=/bin/sh)
    configurationLimit = 10; # keeps /boot from filling up
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 2;
  boot.tmp.cleanOnBoot = true;

  # ------------------------------------------------------------ hardware
  hardware.enableRedistributableFirmware = true; # wifi and GPU firmware
  zramSwap.enable = true; # compressed swap in RAM, no swap partition

  # ------------------------------------------------------------- network
  # iwd joins wifi and systemd-networkd runs DHCP on wired and wifi.
  # iwd only reconnects to networks you have joined before. To join one:
  #   iwctl station wlan0 connect <SSID>
  # To turn the radio off: `rfkill block wifi`.
  # The firewall is on by default and nothing listens (no sshd).
  networking.hostName = "laptop"; # matches nixosConfigurations.laptop
  networking.useNetworkd = true;
  networking.wireless.iwd.enable = true;

  # -------------------------------------------------------------- locale
  # time.timeZone is left unset so it can follow you around:
  #   timedatectl set-timezone Europe/Berlin
  i18n.defaultLocale = "en_US.UTF-8";

  # --------------------------------------------------------------- users
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  # doas instead of sudo: a much smaller program. Members of wheel may
  # run anything as root after typing their password.
  security.sudo.enable = false;
  security.doas.enable = true;

  # This repo lives in /etc/nixos, owned by you, so you can edit and
  # commit without root. `doas nixos-rebuild switch` runs Nix as root,
  # and Nix refuses a git repo owned by someone else unless git is told
  # the directory is safe.
  programs.git = {
    enable = true;
    package = pkgs.gitMinimal; # no perl, python or docs
    config.safe.directory = "/etc/nixos";
  };

  # ------------------------------------------------- desktop: sway only
  # Wayland only. Sway is built without XWayland, so X11 programs will
  # not run at all.
  programs.sway = {
    enable = true;
    xwayland.enable = false;
    extraPackages = with pkgs; [
      foot # terminal
      wmenu # launcher
      swaylock
      swayidle
      brightnessctl
      grim # screenshots
    ];
  };
  environment.etc."sway/config".source = ./sway/config;
  environment.etc."sway/status.sh".source = pkgs.writeShellScript "sway-status" (
    builtins.readFile ./sway/status.sh
  );

  # No display manager. Log in on tty1 and sway starts; tty2-6 stay
  # plain consoles for when something breaks. Sway's log is in the
  # journal: `journalctl -t sway`.
  environment.loginShellInit = ''
    if [ "$(tty)" = /dev/tty1 ] && [ -z "$WAYLAND_DISPLAY" ] && [ "$(id -u)" != 0 ]; then
      exec systemd-cat --identifier=sway sway
    fi
  '';

  # Turning on sway also turns on things this machine does not use.
  # Switch them back off.
  services.speechd.enable = false; # text-to-speech daemon (espeak, python)
  programs.dconf.enable = false; # GNOME settings store
  xdg.portal.wlr.enable = lib.mkForce false; # portals: screen sharing, sandboxed file pickers (pulls in GTK)
  fonts.enableDefaultPackages = false; # nine font families
  fonts.packages = [ pkgs.dejavu_fonts ]; # one is enough

  # Sound. The pulse layer lets most programs play audio without
  # knowing about PipeWire. Volume: `wpctl`.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ------------------------------------------------- trim the base system
  environment.defaultPackages = [ ]; # drops perl, rsync, strace
  documentation.info.enable = false;
  documentation.doc.enable = false; # /share/doc; man pages stay
  boot.enableContainers = false;
  services.journald.extraConfig = "SystemMaxUse=200M";

  # ---------------------------------------------------- nix, for offline
  nix.channel.enable = false; # flakes only
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # Never fetch the global flake registry. `nixpkgs#foo` resolves to
    # the nixpkgs this system was built from, so it works offline when
    # foo is already in the store.
    flake-registry = "";
    # Keep the build-time dependencies of the running system. Without
    # these, editing the sway config while offline can fail because the
    # tools to build the new /etc were garbage collected.
    keep-outputs = true;
    keep-derivations = true;
    connect-timeout = 5; # give up fast on the binary cache when offline
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
}
