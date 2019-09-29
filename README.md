# openwrt-cfg

The scripts in this repository are designed to automate standing up OpenWRT, much in the same way CM software like Chef, Ansible, or nearly anything except bash can be used to manage servers.

## Disclaimer

This repo assumes you are familiar with OpenWRT, Linux, networking, and all that. Some of the scripts might be safe-ish, but many will not be compatible with different versions of LEDE/OpenWRT or different routers. Altering network settings and router settings can make your router unreachable, unstable, or a paperweight. I managed to get a load average of 90 (on a dual core ARM) when trying to configure relaying.

These scripts have been tested on a Linksys WRT3200ACM running OpenWRT 18.04, and are built on the OpenWRT documentation found at

- <https://oldwiki.archive.openwrt.org/doc/howto/start>
- <https://openwrt.org/docs/guide-user/start>

## Usage

This repo is designed with speed and simplicity in mind. Most likely your workflow will be something like

1. Write your local scripts per the documentation below
1. Plug in to a fresh OpenWRT install
1. `scp -r $PWD root@192.168.1.1:`
1. `ssh root@192.168.1.1 cd openwrt-cfg/.local && ./myscript.sh && reboot`
1. Profit

## Contents

- `scripts`: Scripts that perform various tasks. See below.
- `functions`: Source-able functions to ease configuration.
- `environment`: Example configuration files for an AP and its repeaters
- `.local`: An ignored folder where you can store your personal configs.

### Scripts

This folder contains scripts that perform various configuration management tasks. Each script has a comment at the top that explains what the script does and lists any variables the script consumes along with default values and whether they are required. The subdirectories under `scripts/` are organized by category.

#### base

These scripts perform basic setup tasks.

- `begin.sh` upgrades system packages, installs some handy tools, and sets the hostname.
- `authentication.sh` sets the root password (required), disables SSH password logins, either sets root SSH keys or disables root SSH login, optionally adds a dropbear WAN listener and optionally adds a user with SSH keys. You will likely either want to add a user and give him SSH keys or add root SSH keys.
- `luci.sh` tells LuCi to redirect HTTP to HTTPS, and optionally disable the service or listen only on the **current LAN IP address**.
- `ntp.sh` sets the timezone and zone name, enables the NTP client, and sets the NTP server to use.

#### dns

These scripts perform DNS-related tasks.

- `unbound.sh` trades DNSMasq for Unbound and odhcpd. It integrates the two, uses non-tracking (Cloudflare and Quad9) DoT servers, sets up local DNS, and sets some sensible configuration defaults. **NOTE**: Using `.local` for the local domain name may cause conflicts with Zeroconf/mDNS/Bonjour/etc. Unless `FORCE_DNS=''`, it will redirect all requests to `53/UDP` and `853/TCP` from all bridge interfaces to `127.0.0.1`.
- `adblock.sh` installs and configures Adblock, sets the active blocklists, **integrates with Unbound**, and adds a cron to update the blocklists.

#### network

- `sqm.conf` installs and configures SQM to use the `cake` method. It requires upload and download speed to be provided, and assumes that you are using cable or similar internet. ADSL/VDSL uses may need to change the relevant settings.
- `mdns.sh` installs and configures avahi-daemon. It does not alter the default publishing settings, and does enable the reflector for cross-zone multicasting as determined by the value of the `AVAHI_IFS` variable. It also ignores TTLs of incoming messages - this is necessary, for example, for Chromecasts that live on a separate network than the devices that connect to them, since they broadcast with a TTL of 1. You need this if you have `mDNS`/`Zeroconf`/`Bonjour`/etc devices spread across networks.

### Functions

This folder contains functions that simplify network/firewall/dhcp/wifi configuration. As this process cannot be totally automated, these functions can be used in your local scripts to keep your code DRY, especially if you're making several of any of the above. The scripts are fairly opinionated, although the configuration is minimal: they "should work" when used in conjunction with the scripts above.

Notes:

- For IPv6 configuration, the scripts assume that you want to use SLAAC.
- Make sure to export `${CPU_IFACE:=eth0}` if your CPU is on a different interface

Source the `functions/functions.sh` script in your script, which will in turn source all of the files in the directory that match `_*.sh` (ie everything else).

### Environment

These files can be sourced by your scripts in `.local` to perform generic setup tasks such as running the `scripts/`. Each script contains an `exit 0` followed by some example scripting to set up and configure networks. Unless you have complex requirements, you should be able to source the correct environment script and base your local configuration completely off the examples contained in the file.

Each environment correlates to a particular type of setup:

- `master.sh` configures a _router_ that will likely be connected to other routing/switching devices. For example, it enables STP on the interfaces.
- `client.sh` configures a client that might connect to a device that's been configured from `master.sh`

### Local

Keep your local configuration in this directory. They will likely:

- Export the environment variables you wish to set in the scripts
- Call the relevant environment script
- Source the functions and configure your networks
- Perform any additional local configuration

## TODO

- Lock down the Avahi daemon configuration (does anything _actually use_ Zeroconf for DNS/etc?), and see if `uwpxy` can be used to convert those multicasts to unicasts for WiFi clients.
- Make SQM determine link bandwidth automagically
- Make IPv6 configuration better, it's flaky with my `/64` PD from Spectrum.
- [Firewall Configuration](https://openwrt.org/docs/guide-user/firewall/start) could likely use some tuning
- Fix `unbound_control` per note in `unbound.sh`

### Missing Monitoring

This setup logs everything to the syslog (ie `logread`). Unbound has some additional logging options - grep for `log-` in the docs for the config file.

Unbound has `unbound-control stats`, which prints a thorough chunk of information, and the version of Adblock packaged with 19.x OpenWRT can, with tcpdump, dump out some stats as well.

The savvy SA might be interested in

- [Network monitoring](https://openwrt.org/docs/guide-user/services/network_monitoring/start)
- [IDS](https://openwrt.org/docs/guide-user/services/snort)

### Missing Features

- [OpenVPN](https://openwrt.org/docs/guide-user/services/vpn/openvpn/start) client and server (this may require some Unbound rejiggering)
- ..which requires [DDNS](https://openwrt.org/docs/guide-user/services/ddns/client), but the [Route53 script](https://github.com/openwrt/packages/blob/21f5cdd2fa2d4336d4c77d22d404252be1b82ebd/net/ddns-scripts/files/update_route53_v1.sh) is a bag of suck
- [NAS](https://openwrt.org/docs/guide-user/services/nas/start)
- Serve DoT locally with Unbound (requires a valid cert), and maybe disable local resolution for some VLANs
- Protect against brute force attacks (from [Snowman](http://www.snowman.net/projects/ipt_recent/)):

```bash
iptables -A FORWARD -m recent --update --seconds 60 -j DROP
iptables -A FORWARD -i eth0 -d 127.0.0.0/8 -m recent --set -j DROP
```

## License

This software is licensed under the MIT License, included in the LICENSE file.
