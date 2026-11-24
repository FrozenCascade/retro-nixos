{ ... }:
let
  # DNS over TLS. Mullvad's "adblock" resolver refuses known ad and tracker domains, so it filters
  # every app on the system, not just the browser. For a plain resolver use e.g. "9.9.9.9#dns.quad9.net".
  dnsServers = [
    "194.242.2.3#adblock.dns.mullvad.net"
    "2a07:e340::3#adblock.dns.mullvad.net"
  ];

  # only used when the servers above cannot be reached
  fallbackServers = [
    "9.9.9.9#dns.quad9.net"
    "149.112.112.112#dns.quad9.net"
  ];
in
{
  networking.networkmanager.dns = "systemd-resolved";

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = dnsServers;
      FallbackDNS = fallbackServers;
      # "opportunistic" on purpose: the Proton VPN's own DNS inside the tunnel does not speak TLS,
      # and a strict setting would break name lookups whenever the VPN is on
      DNSOverTLS = "opportunistic";
      DNSSEC = "false";            # Mullvad validates; checking again locally trips over blocked domains
      Domains = [ "~." ];          # use the servers above for everything, not the router's DNS from DHCP
      LLMNR = "false";             # legacy name broadcast: leaks your hostname and is easy to spoof
      MulticastDNS = "false";      # the same for mDNS; set "true" if you need .local printers or devices
    };
  };

  # A different hardware address per network instead of your real one (stable = the same one every time
  # you return to the same network, so hotspots and routers still recognise you)
  networking.networkmanager.wifi.macAddress = "stable";
  networking.networkmanager.wifi.scanRandMacAddress = true;
  networking.networkmanager.ethernet.macAddress = "stable";

  # Nothing is open to the network unless a module opens it; also stay silent to pings
  networking.firewall = {
    enable = true;
    allowPing = false;
  };
}
