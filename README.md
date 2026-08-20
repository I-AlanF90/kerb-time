# kerb-time
Kerberos clock skew helper that queries a domain controller's NTP offset and runs commands with faketime without modifying the system clock.


kerb-time is a lightweight Bash utility for dealing with Kerberos clock skew issues.

Instead of changing your system clock to match a domain controller, kerb-time queries the DC’s NTP offset and runs your command through faketime. This avoids disrupting VPN connections, tunnels, or other processes that may depend on the host’s real system time.

Features

* Automatically queries the target DC’s NTP offset
* Calculates positive or negative clock skew
* Does not modify the host system clock
* Runs Kerberos tools through faketime
* Supports interactive command entry
* Supports direct command execution with -c
* Includes timeout and dependency checks
* Useful with Impacket and other Kerberos-aware tooling

Usage
```bash
./kerb-time.sh <DC_IP>
```

Interactive example:
```bash
./kerb-time.sh 10.10.10.10
```

Direct command execution:
```bash
./kerb-time.sh 10.10.10.10 -c "impacket-GetUserSPNs domain.local/user -request -dc-ip 10.10.10.10"
```

Why?

Kerberos typically requires the client and domain controller clocks to be closely synchronized. In lab environments, the DC may sometimes be several hours ahead or behind your attack machine.

Changing the entire system clock can disrupt VPNs, pivot tunnels, and other long-running processes.

kerb-time solves this by applying the DC’s clock offset only to the command being executed.

<img width="1873" height="1042" alt="SCR-20260819-sqbk" src="https://github.com/user-attachments/assets/055ba0dd-2165-4f18-84e3-1ff43f520bfe" />
