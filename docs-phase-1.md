# Phase 1: On-Premises Foundation & Domain Controller

Goal: Build the core company network — one domain controller that provides
identity (AD), name resolution (DNS), and automatic IP assignment (DHCP).

## 1. Environment & Network Configuration

- **Virtual Machine:** CORP-DC01 (Hyper-V VM name) — Windows Server 2022,
  Generation 2, 4 GB RAM, 50 GB virtual disk stored on D:
- **Windows hostname:** WIN-D8E44CTNJU — the server was promoted before it
  was renamed, so Windows kept its default name. The domain is unaffected.
- **IP Addressing:** Static IP 192.168.10.10, subnet mask 255.255.255.0,
  default gateway 192.168.10.1
  - Why static: clients must always be able to find the domain controller
    at the same address. Servers never get their address from DHCP.
- **DNS Configuration:** Preferred DNS set to loopback (127.0.0.1)
  - Why: this server IS the DNS server for corp.local, so it looks
    names up in itself first.

[TODO screenshot: IPv4 properties / ipconfig /all on the DC]

## 2. Active Directory Domain Services (AD DS)

- Installed the AD DS role in Server Manager, then promoted the server to
  a domain controller: Add a new forest
- **Forest / Domain Name:** corp.local
- **Sign-in after promotion:** CORP\Administrator

### Organizational Unit (OU) Structure

- corp.local
  - Employees (root OU)
    - IT
    - HR
    - Sales

OUs are used instead of the built-in Users container because Group Policy
can be linked to OUs (it cannot be linked to the default containers), and
because OUs keep everyday users separate from built-in admin accounts.

### Users created

- knguyen (Khoa Nguyen) — created manually in the IT OU and added to the
  Domain Admins security group for lab administration
- svc-backup — an example service account in a dedicated Service
  Accounts OU, created to demonstrate how service accounts differ from
  user accounts (no forced password change at first logon, password set
  to never expire, purpose recorded in the Description field). It is a
  demonstration account and is not used by any actual service.
- Bulk test users created by running a PowerShell provisioning script
  (developed with AI assistance) reading employees.csv:
  - 54 users total — 18 per department across IT, HR and Sales
  - The original 5 users (asmith, bjones, cbrown, dprince, ewright) are included in the 54
- The script skips a user who already exists, so it is safe to re-run,
  and writes a timestamped log (provisioning-log.txt). A re-run after
  fixing the target OUs completed the full set with no errors, and each
  user is added to their department security group (IT-Users, HR-Users,
  Sales-Users, created in the Employees OU). IT-Users holds 19 members:
  the 18 IT users plus knguyen, added manually through the group's
  Members tab.

[TODO screenshot: ADUC showing Employees > IT / HR / Sales and the users]
[TODO file: add the script as scripts/Provision-Users-v2.ps1 and a
 password-redacted copy of employees.csv]

## 3. DNS Forwarders

- Tool: DNS Manager
- Added forwarders: 1.1.1.1 (Cloudflare) and 8.8.8.8 (Google)
- What this does: queries for corp.local are answered by this server.
  Queries for anything else (e.g. google.com) are forwarded to a public
  DNS server instead of failing.
- Note: forwarder validation showed an error in the lab because the VM
  could not reach the public DNS server from its virtual switch at that
  moment. The forwarders were saved anyway with OK / Apply.

[TODO screenshot: DNS Manager showing the forwarders tab]

## 4. DHCP

- Role installed on the domain controller, server authorised in AD
- **Scope name:** Corp-Internal-Scope
- **Range handed out:** 192.168.10.50 – 192.168.10.200 (151 addresses)
- **Subnet mask:** 255.255.255.0 — **Lease duration:** 8 days (default)
- **Scope options given to every client:**
  - Router / default gateway: 192.168.10.1
  - DNS server: 192.168.10.10 (the domain controller)
  - Parent domain: corp.local
- Addresses 192.168.10.1 – 192.168.10.49 are kept outside the scope on
  purpose, for servers and other static devices like the DC itself (.10).
- **Exclusion range:** 192.168.10.50 – 192.168.10.59 inside the scope is
  never handed out automatically, kept free for future static devices.
- **Reservations** (a specific device always receives the same address,
  matched by MAC address):
  - LAB-PRINTER-01 — 192.168.10.60
  - LAB-SPARE-01 — 192.168.10.61

[TODO screenshot: DHCP console showing scope, exclusion and reservations]

## 5. Group Policy (GPOs)

- **Password & lockout policy** — edited in the Default Domain Policy
  (domain password rules are only read from GPOs linked at the domain
  root). Minimum password length 12, complexity requirements enabled,
  account lockout after 5 invalid logon attempts for 30 minutes.
- **Department Drive Mappings** — one GPO linked to the Employees OU.
  Department folders C:\Shares\IT, \HR, \Sales are shared to their own
  security group (share permission Change, NTFS permission Modify;
  the inherited CORP\Users read entry was removed). Three drive-map
  preferences map H: to \\192.168.10.10\IT, \\192.168.10.10\HR and
  \\192.168.10.10\Sales, each with item-level targeting on the matching
  group (IT-Users / HR-Users / Sales-Users), so every user sees one H:
  drive pointing at their own department's folder.
- **Workstation Local Admins** — GPO linked to a Workstations OU (for
  computer accounts). Uses a Local Users and Groups preference to reset
  the local Administrators group on workstations to Domain Admins only
  (plus the built-in local Administrator account, which always remains).

Note: the drive mappings and local-admin policy apply on the client
machine, so their end-to-end verification (sign in as a test user, check
the H: drive with gpresult) happens in Phase 2 when the Windows 11
client joins the domain.

## 6. Troubleshooting encountered

- Server Manager still showed the old IP after the static IP was set —
  a cached display; the address on the adapter was correct.
- Bulk user creation failed for HR and Sales with "Directory object not
  found" — the target OUs did not exist yet. Fix: create the OU first,
  then re-run.
- A CSV filename mismatch (employee.csv vs employees.csv) prevented the
  script finding its input file. Fix: make the name in the script match
  the file exactly.
- Reviewing the v2 provisioning script before running it caught a silent
  bug: users who already existed were skipped before the group-add step,
  so a re-run would have left the original 5 users in no department
  group. Fix: the skip path now checks group membership and adds the
  user to their department group if missing.

NOTE: Do not put any real passwords in this repo. Passwords used in this
lab are not recorded here.
