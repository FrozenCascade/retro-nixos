{ pkgs, lib, ... }:

# Lets chosen programs skip the VPN while everything else keeps using it.
#   vpn-bypass <command>     runs that command outside the VPN, e.g. `vpn-bypass vesktop`
#   bypassVpn = true;        on an app in settings.nix (`apps`): its launcher entry starts it that way
# How it works: vpn-bypass starts the command with the extra group `vpnbypass` (vpn-bypass.c). The firewall
# marks traffic from any process in that group, a routing rule sends marked traffic through the normal
# connection (not the VPN tunnel), and NAT gives it the Wi-Fi's address.
# Your user is NOT a member of the group (that would put every program outside the VPN); only vpn-bypass adds it.
# The main group stays yours on purpose: with a different main group, the desktop portal refuses the app
# (no screen sharing, no file pickers).
# Works for programs installed through Nix, not Flatpak apps (their sandbox does not pass the group on).
# Programs that are already open keep their old connection, so restart them. To check it works:
#   curl -s https://ifconfig.me ; vpn-bypass curl -s https://ifconfig.me     (two different addresses with the VPN on)
let
  mark = "0x4e47";        # any number the VPN does not use
  ip = "${pkgs.iproute2}/bin/ip";

  helper = pkgs.runCommandCC "vpn-bypass" { } ''
    mkdir -p $out/bin
    $CC -O2 -Wall -o $out/bin/vpn-bypass ${./vpn-bypass.c}
  '';
in
{
  users.groups.vpnbypass = { };

  # setuid so it can add the group, see the top of vpn-bypass.c; appears as /run/wrappers/bin/vpn-bypass
  security.wrappers.vpn-bypass = {
    source = "${helper}/bin/vpn-bypass";
    owner = "root";
    group = "root";
    setuid = true;
  };

  # replies come back on the Wi-Fi for an address that belongs to the tunnel; strict checking would drop them
  networking.firewall.checkReversePath = lib.mkDefault "loose";

  # --suppl-groups: match the group among a process's extra groups, not only its main group
  networking.firewall.extraCommands = ''
    iptables -t mangle -D OUTPUT -m owner --gid-owner vpnbypass -j MARK --set-mark ${mark} 2>/dev/null || true
    iptables -t mangle -D OUTPUT -m owner --gid-owner vpnbypass --suppl-groups -j MARK --set-mark ${mark} 2>/dev/null || true
    iptables -t mangle -A OUTPUT -m owner --gid-owner vpnbypass --suppl-groups -j MARK --set-mark ${mark}
    iptables -t nat -D POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE 2>/dev/null || true
    iptables -t nat -A POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE
    ${ip} rule del fwmark ${mark} lookup main pref 10 2>/dev/null || true
    ${ip} rule add fwmark ${mark} lookup main pref 10
  '';

  networking.firewall.extraStopCommands = ''
    iptables -t mangle -D OUTPUT -m owner --gid-owner vpnbypass --suppl-groups -j MARK --set-mark ${mark} 2>/dev/null || true
    iptables -t nat -D POSTROUTING -m mark --mark ${mark} ! -o lo -j MASQUERADE 2>/dev/null || true
    ${ip} rule del fwmark ${mark} lookup main pref 10 2>/dev/null || true
  '';
}
