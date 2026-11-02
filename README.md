# NixOS-Laptop

A minimal NixOS for a laptop that is offline most of the time. Sway on
Wayland, no X11 anywhere, and a single input (nixpkgs) pinned in
`flake.lock`, so nothing changes until you decide to update.

| File | What it is |
| --- | --- |
| `flake.nix` | One input: `nixos-26.05`. One machine: `laptop`. |
| `configuration.nix` | The whole system, commented. |
| `hardware-configuration.nix` | Placeholder. Regenerate it on the laptop. |
| `sway/config` | Installed as `/etc/sway/config`. |
| `sway/status.sh` | The bar: battery and clock. |

## What's in it

- **Desktop:** sway built without XWayland, foot (terminal), wmenu
  (launcher), swaylock and swayidle, grim (screenshots), brightnessctl.
  No display manager: log in on tty1 and sway starts.
- **Sound:** PipeWire, with the PulseAudio layer for compatibility.
- **Network:** iwd for wifi, systemd-networkd for DHCP, firewall on,
  nothing listening.
- **Disk:** LUKS full-disk encryption, ext4, systemd-boot, zram swap.
- **Admin:** doas instead of sudo. Minimal git, for this repo.
- **Docs, offline:** `man configuration.nix` lists every NixOS option.

Left out on purpose. Add any of these to `configuration.nix` if you need
them:

- XWayland, so X11-only programs will not run at all
- xdg-desktop-portal, so no screen sharing in browsers
- Bluetooth, printing, sshd
- dconf, speech-dispatcher, and the default font set (only DejaVu is
  installed)
- A web browser

## "LTS"

NixOS has no LTS release. A stable release comes out every May and
November (`YY.05`, `YY.11`) and gets security fixes for about seven
months. 26.05 is supported until the end of December 2026, and 26.11 is
due at the end of November 2026.

So the plan is:

- **Whenever you're online:** take security updates within the release
  (`nix flake update`, see below).
- **Twice a year:** move to the next release on purpose.
- **Nothing updates automatically.**

The kernel is the NixOS default, which is the newest upstream LTS kernel.

## Install

From the NixOS 26.05 minimal ISO, booted in UEFI mode. Get online first:
ethernet or USB tethering just works, and for wifi use `nmtui`.

```bash
sudo -i
```

Partition: a 1 GiB EFI partition, and the rest is LUKS with ext4 inside.
Check the disk name with `lsblk`. NVMe partitions end in `p1` and `p2`,
SATA ones in `1` and `2`.

```bash
DISK=/dev/nvme0n1
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MiB 1GiB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart root 1GiB 100%
mkfs.fat -F 32 -n BOOT "${DISK}p1"
cryptsetup luksFormat --label cryptroot "${DISK}p2"
cryptsetup open "${DISK}p2" cryptroot
mkfs.ext4 -L nixos /dev/mapper/cryptroot
mount /dev/disk/by-label/nixos /mnt
mount --mkdir -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
```

Fetch this repo into `/etc/nixos` and replace the placeholder hardware
file with the real one:

```bash
git clone https://github.com/NarrativeCollapse/NixOS-Laptop /mnt/etc/nixos
nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/nixos/hardware-configuration.nix
```

Set your login name on the `user = ...` line in
`/mnt/etc/nixos/configuration.nix`, then install. It asks for a root
password at the end.

```bash
nano /mnt/etc/nixos/configuration.nix
nixos-install --flake /mnt/etc/nixos#laptop
nixos-enter --root /mnt -c 'passwd YOURNAME'
reboot
```

After the first boot, log in on tty1 and sway starts. Make the repo yours
so you can edit and commit it without root:

```bash
doas chown -R YOURNAME:users /etc/nixos
```

Commit the generated `hardware-configuration.nix`.

## Daily use

Super is the sway modifier. The keys are the standard sway set (see
`sway/config`), plus:

| Key | Action |
| --- | --- |
| Super+Escape | Lock |
| Print | Screenshot |
| Volume and brightness keys | Work, including on the lock screen |

| Task | Command |
| --- | --- |
| Apply config changes | `doas nixos-rebuild switch` |
| Join wifi | `iwctl station wlan0 scan`, then `iwctl station wlan0 get-networks`, then `iwctl station wlan0 connect SSID` |
| Radio off / on | `rfkill block wifi` / `rfkill unblock wifi` |
| Time zone | `timedatectl set-timezone Europe/Berlin` |
| Undo the last change | `doas nixos-rebuild switch --rollback`, or pick an older entry in the boot menu |
| Sway log | `journalctl -t sway` |

`nixos-rebuild` finds `/etc/nixos/flake.nix` on its own and picks the
`laptop` config because that is the hostname.

Flakes only see files that git tracks. If you add a new file, `git add`
it before rebuilding.

## Updating

When you're online:

```bash
cd /etc/nixos
nix flake update
doas nixos-rebuild switch
git commit -am "Update nixpkgs"
```

Because XWayland is disabled, wlroots and sway differ from the copies in
the binary cache. They are compiled on the laptop whenever an update
changes them, which takes a few minutes. Everything else downloads
prebuilt.

To move to a new release, change `nixos-26.05` to `nixos-26.11` in
`flake.nix` and run the same commands. Read the release notes first.
Never change `system.stateVersion`.

## Offline

- **Editing the config offline works.** Changing sway keys, services, or
  options rebuilds without network: the build tools for the current
  system are kept in the store (`keep-outputs`).
- **Adding a package offline only works if it's already in the store.**
  Add anything you'll want to `configuration.nix` while you're online.
- **`nix shell nixpkgs#foo` uses the pinned nixpkgs, never the internet
  registry.** It works offline whenever `foo` has been fetched before.
- **Garbage collection runs weekly** and deletes generations older than
  30 days.
