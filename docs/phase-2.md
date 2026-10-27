# Phase 2: Client Join and Group Policy Verification — COMPLETE 2026-10-27

Goal: prove the Phase 1 build works from a real endpoint — a Windows 11
client joins corp.local, and the Group Policy Objects (GPOs) built in
Phase 1 actually land on a domain logon.

Result: all 8 verification steps passed. The client is domain-joined,
sits in the Workstations Organizational Unit (OU), gets the correct
department drive map per user, has a locked-down local Administrators
group, enforces the domain password policy, and reports all three GPOs
in `gpresult`.

## 1. Client virtual machine (VM) — what was actually used

- Hyper-V VM name: CORP-WS01; Windows computer name after rename:
  CORP-WS01 (see section 4). Do not confuse the Hyper-V VM name
  (inventory label) with the Windows computer name (the name that
  becomes the Active Directory computer object).
- Edition used: Windows 11 Enterprise Evaluation. This is the edition
  offered by the Microsoft evaluation image found for the lab. It was
  kept, and labelled Enterprise (not Pro), because it joins a domain
  and applies Group Policy Objects the same way as Pro for this lab.
- Setup account actually used: lab-user. The intended name labadmin
  was rejected during setup with "Please type a different user name",
  after an earlier setup failure-and-retry. Conclusion recorded so it
  is not retried: labadmin is not the usable setup account name for
  this client.
- Memory: 6 GB (6144 MB in Hyper-V Settings → Memory), chosen by Khoa
  over a suggested 8 GB. Host has 32 GB RAM at 3200 MHz; Domain
  Controller (DC) uses 4 GB, client uses 6 GB, leaving ample headroom.
  Host usage of 24/32 GB seen earlier is not a problem: the figure to
  watch is Available RAM in Task Manager, not In use.

## 2. Fixes needed before setup would run

- Trusted Platform Module (TPM): setup first failed the Windows 11
  hardware check. Fix: power the VM off, then in Hyper-V Settings →
  Security enable Trusted Platform Module (and Secure Boot). The
  error cleared after this change.
- Processor check: setup then failed with "The processor needs to
  have two or more cores" because the VM defaulted to 1 virtual
  processor. Windows 11 requires 2. Fix: power the VM off, then in
  Hyper-V Settings → Processor set Number of virtual processors
  to 2. Setup advanced after this change.
- Install screen: "Install Windows 11 Enterprise Evaluation" with
  "Keep nothing" selected — correct for a new, empty virtual disk.

## 3. Out-of-box experience (OOBE) — what was seen

- The OOBE network screen showed network name "corp.local" and
  "No Internet". That is a useful early signal: the client was
  already seeing the lab network and domain suffix. Setup proceeded
  on the offline path ("I don't have internet" → limited setup).
- OOBE advanced past local-account creation to the privacy screens.
- Black console screen (2026-10-24): after a restart, the client
  console showed a black screen and would not connect, but a later
  Hyper-V screenshot showed the VM Status as Running. Conclusion:
  the VM had not crashed; the console was not displaying. This is a
  display / console issue, not a dead machine. Resume steps: confirm
  Status Running, close the VM Connection window completely and
  reconnect, toggle View → Enhanced session off and reconnect,
  Action → send Ctrl+Alt+Del and wait a full minute, and only then
  Turn Off → Start as a last resort.

## 4. Slow client boot — root cause found and fixed (2026-10-27)

- Symptom: CORP-WS01 took 10+ minutes to launch while CORP-DC01
  opened and ran fast, even after the client was raised to 6 GB RAM.
- Ruled out, with evidence: processor (Hyper-V Manager showed both
  VMs at 0–4% processor use — the client was waiting, not working)
  and memory (6 GB confirmed in the client's Task Manager).
- Root cause, verified from a host Task Manager screenshot: D: is a
  500 GB Seagate Barracuda hard disk drive (HDD), model ST500DM002,
  holding the virtual machine storage. It showed 100% active time
  with ~174 ms average response time and only ~5 MB/s total
  throughput (2.3 MB/s read + 2.6 MB/s write) — the signature of a
  mechanical drive choking on many small random virtual machine
  requests. C: is the solid-state drive (SSD) and sat at ~0% active
  time. CORP-DC01 feels fast on the same drive only because it is
  idle and barely touches the disk.
- Fix applied 2026-10-27: CORP-WS01's storage was moved to C: with
  Hyper-V Manager → right-click CORP-WS01 → Move → Move the
  virtual machine's storage → Move the virtual machine's data to a
  single location → a folder on C:. No reinstall: moving storage
  only relocates the disk file; Windows, the setup account, and the
  domain-join state are unchanged. Move time was roughly 10 minutes.
  CORP-DC01 stays on D: — its workload is tiny (directory database,
  SYSVOL policies on demand), so it does not need the SSD.
- Note: the lab is completable on the HDD setup too — a slow disk
  delays the Phase 2 tests but does not change any result. The move
  is a speed fix, not a requirement.

## 5. Network — Default Switch DHCP conflict, resolved with a static address

- CORP-DC01 is on Hyper-V's built-in Default Switch, not a custom
  internal switch, so CORP-WS01 also uses Default Switch
  (same-switch rule).
- Conflict confirmed 2026-10-27: CORP-WS01's first `ipconfig /all`
  showed a Default Switch address — IPv4 172.28.162.221/20,
  gateway / Dynamic Host Configuration Protocol (DHCP) / Domain Name
  System (DNS) server 172.28.160.1, suffix mshome.net. CORP-DC01's
  192.168.10.x DHCP scope (192.168.10.50–200) was not reaching the
  client because the Default Switch's own DHCP answers first.
- Fix applied and verified: CORP-WS01 uses a static address —
  IP 192.168.10.20, subnet mask 255.255.255.0, gateway 192.168.10.1,
  preferred DNS 192.168.10.10. The address sits outside the DHCP
  scope, so it can never collide with a lease. Verified with
  `ipconfig /all` (DHCP Enabled: No, values as entered) and
  `ping 192.168.10.10` (4 replies, 0% loss, under 1 ms).
- Gotcha recorded: in the adapter properties dialogs, the new
  address only saves if you click OK on BOTH windows — OK on the
  Internet Protocol Version 4 (TCP/IPv4) dialog, then OK (not the X,
  not Cancel) on the Ethernet Properties window. Closing the second
  window with the X discards the change. A PowerShell alternative
  that avoids the dialogs entirely: `Set-NetIPInterface -Dhcp
  Disabled`, `New-NetIPAddress` with the values above,
  `Set-DnsClientServerAddress` to 192.168.10.10.
- Honest record: CORP-WS01 does not currently get its address from
  CORP-DC01's DHCP scope. The scope still exists on the DC, and the
  recorded future fix — if DHCP delivery to clients is ever wanted
  as designed — is a dedicated Internal virtual switch for both VMs
  with a host adapter at 192.168.10.1. That change was not needed
  for Phase 2.
- CORP-DC01 must stay on for almost all of Phase 2: the network
  check, the domain join, the Active Directory Users and Computers
  (ADUC) move, the drive maps (\\192.168.10.10\IT and \HR live on
  CORP-DC01), the password test, and a meaningful `gpresult` run.
  Only the rename and the local Administrators view do not strictly
  need it on.

## 6. Verification steps and results (all passed 2026-10-27)

1. **Network** — static 192.168.10.20/24, gateway 192.168.10.1,
   DNS 192.168.10.10, verified by `ipconfig /all` and a clean ping
   to CORP-DC01 (see section 5).
2. **Rename** — computer renamed to CORP-WS01, restarted.
   Verified: `hostname` returns CORP-WS01.
3. **Domain join** — System Properties (`sysdm.cpl`) → Domain
   `corp.local` → signed in as CORP\Administrator → restarted.
   Verified: full computer name CORP-WS01.corp.local, Domain:
   corp.local. (Join proof in the repo is the System Properties
   screenshot; the "Welcome to the corp.local domain" dialog itself
   was not captured.)
4. **OU move** — on CORP-DC01, in ADUC, CORP-WS01 moved from the
   built-in Computers container to the Workstations OU. Verified:
   ADUC shows CORP-WS01 inside Workstations. Skipping this would
   have meant the Workstation Local Admins policy silently never
   applied.
5. **Drive maps** — signed in as CORP\asmith → H: mapped to
   \\192.168.10.10\IT ("IT Department"). Signed out, signed in as
   CORP\cbrown → H: mapped to \\192.168.10.10\HR ("HR Department").
   Same H: letter, different share per user — item-level targeting
   on the department groups works as designed. Both shares report
   38.1 GB free of 49.3 GB, consistent with the shares living on
   CORP-DC01's C: drive.
6. **Local-admin lockdown** — after `gpupdate /force` (needed
   because CORP-WS01 entered the Workstations OU after its last
   restart), local Administrators contains exactly Administrator
   (built-in, the local recovery account) and CORP\Domain Admins.
   No asmith, cbrown, or lab-user — the policy's "delete all"
   ticks removed the setup account's admin membership and left
   only the managed entries.
7. **Password policy** — as CORP\asmith, attempted to change the
   password to `test123`. Rejected with: "Unable to update the
   password. The value provided for the new password does not meet
   the length, complexity, or history requirements of the machine
   or domain." The 12-character minimum and complexity rules from
   the Default Domain Policy are enforced. (A rejected change does
   not alter the password.)
8. **`gpresult`** — user half, run as CORP\asmith: CN=Alice Smith,
   OU=IT, OU=Employees, policy applied from
   WIN-D8E44CTNJU.corp.local at 3:17 PM, Applied Group Policy
   Objects includes Department Drive Mappings, security groups
   include IT-Users (which is why the IT map applied). Computer
   half, run elevated with `gpresult /r /scope:computer`:
   CN=CORP-WS01, OU=Workstations, policy applied from
   WIN-D8E44CTNJU.corp.local at 3:16 PM, Applied Group Policy
   Objects includes Workstation Local Admins and Default Domain
   Policy. All three GPOs proven.

## 7. Troubleshooting notes from this phase

- **Two passwords exist in this lab — do not confuse them.**
  Accounts created by hand (CORP\Administrator, knguyen, lab-user)
  use Khoa's own self-chosen password. Accounts created by the
  provisioning script (asmith, cbrown, and the other 53 users) use
  the shared password from the provisioning CSV. A domain-user
  logon must use the CSV password; the Administrator password
  will fail for asmith. (Password values are never written in
  this repo — see the CSV on CORP-DC01, which itself never goes
  near GitHub.)
- **Account lockout is real and was hit during this phase.**
  After several wrong-password attempts, asmith locked out per the
  Phase 1 policy (5 attempts → 30-minute lockout). Fix: on
  CORP-DC01, ADUC → asmith → Properties → Account tab → tick
  Unlock account → OK; or wait 30 minutes. Unlocking an account
  is a standard Level 1 helpdesk task.
- **Ctrl+Alt+Del goes to the host, not the guest.** It is the
  host's Secure Attention Sequence, so the host always grabs it
  before the VM console sees it. Alternatives inside the guest:
  VM Connection window → Action → Ctrl+Alt+Delete;
  Ctrl+Alt+End in the console window; or skip it entirely via
  Settings → Accounts → Sign-in options → Password → Change.
- **"User name or password is incorrect" on the Change a password
  screen is not a policy rejection.** It means the old/current
  password field did not match the signed-in account. The policy
  rejection instead names length, complexity, or history
  requirements.
- **`gpresult` scope and elevation.** A standard user only sees
  their own user settings — the computer section simply does not
  appear. The computer section needs an elevated prompt, and
  `gpresult /r /scope:computer` shows computer settings only.
  Plain `gpresult /r` in an elevated prompt running as an account
  that has never signed in to the machine's desktop fails with
  "does not have RSoP data" — that account has no stored policy
  results yet. Computer settings are per-machine and identical
  regardless of which admin runs the elevated command.

## 8. Screenshots for the repo (screenshots/ folder)

- `ipconfig-ws01.png` — corrected static output: DHCP Enabled: No,
  192.168.10.20, gateway 192.168.10.1, DNS 192.168.10.10
- `domain-join-verified.png` — System Properties showing full
  computer name CORP-WS01.corp.local and Domain: corp.local
  (substitute shot; the Welcome dialog itself was not captured)
- `aduc-ws01-workstations-ou.png` — ADUC with Workstations OU open
  and CORP-WS01 visible inside it
- `drive-map-asmith-it.png` — File Explorer as CORP\asmith, H:
  "IT Department"
- `drive-map-cbrown-hr.png` — File Explorer as CORP\cbrown, H:
  "HR Department"
- `local-admins-members.png` — lusrmgr.msc Administrators members:
  Administrator and CORP\Domain Admins only
- `password-policy-rejection.png` — the length/complexity/history
  rejection for `test123` (typed passwords show as dots; still
  check every shot for any real password before upload, same rule
  as Phase 1)
- `gpresult-ws01.png` — `gpresult /r` as CORP\asmith: Department
  Drive Mappings applied, IT-Users membership
- `gpresult-ws01-computer.png` — `gpresult /r /scope:computer`
  (elevated): Workstation Local Admins and Default Domain Policy
  applied, computer in OU=Workstations
- Upload rule, same as Phase 1: Add file → Upload files with the
  actual files, never paste from a rendered view.

## 9. Sequencing — do not change

- Phase 2 is complete with this commit.
- Next: the review pass over the fuzzy Phase 1 (and now Phase 2)
  settings, using review-list.md.
- Only after that review, sign up for the 30-day Microsoft 365 E5
  trial for Phase 3. Starting the trial early burns trial days on
  join and review work.
