# Phase 4 — Entra Connect Sync, Hybrid Join, and Intune Enrollment

**Goal:** Connect the on-premises Active Directory (AD) domain `corp.local` to the Microsoft Entra ID tenant from Phase 3, so the same users sign in everywhere with the same password (hybrid identity), then hybrid-join the workstation CORP-WS01 and enroll it into Microsoft Intune for device management.

**End state achieved:**

- 55 users and 3 department groups synchronised to the tenant, all signing in as `@nnmkhoa.onmicrosoft.com`
- Password Hash Synchronisation (PHS) verified end-to-end
- CORP-WS01 is **Microsoft Entra hybrid joined** (DomainJoined: YES + AzureAdJoined: YES)
- CORP-WS01 is **enrolled in Intune and Compliant**, primary user asmith

---

## 1. The network problem that had to be fixed first

Entra Connect runs on the Domain Controller (DC), CORP-DC01 — and the DC had **no internet access** (Edge returned `ERR_TIMED_OUT` for entra.microsoft.com).

**Root cause:** the lab's default gateway, 192.168.10.1, **did not exist**. Every Phase 1–2 task was same-subnet traffic (workstation ↔ DC), which never needs a gateway, so the phantom gateway went unnoticed until something on the lab network needed the internet. The Hyper-V Default Switch the virtual machines (VMs) sat on provides its own Network Address Translation (NAT) and Dynamic Host Configuration Protocol (DHCP) — but only for addresses on its own 172.28.x.x subnet, not for the lab's static 192.168.10.x addresses.

**Fix (host-side, no AD changes):**

1. Created a Hyper-V **Internal** virtual switch named `CORP-LAB`.
2. Set the host's `vEthernet (CORP-LAB)` adapter to static **192.168.10.1/24** (no gateway/Domain Name System (DNS) — the host *is* the gateway now), making the lab's documented gateway real.
3. Created a NAT for the lab subnet on the host: `New-NetNat -Name "CORP-LAB-NAT" -InternalIPInterfaceAddressPrefix 192.168.10.0/24`.
4. Moved both VMs' network adapters from the Default Switch to `CORP-LAB`. CORP-DC01 kept 192.168.10.10; CORP-WS01 kept 192.168.10.20.

This implements the "future fix" noted in the Phase 2 runbook.

*Screenshots: `dc-no-internet.png`*

## 2. User Principal Name (UPN) preparation

Cloud sign-in names must use a domain the tenant can verify. `@corp.local` can never be verified, so before synchronising:

1. In **Active Directory Domains and Trusts**, added the alternate UPN suffix **nnmkhoa.onmicrosoft.com**.
2. In Active Directory Users and Computers (ADUC), selected the users in each department organisational unit (OU) (IT, HR, Sales) and flipped their User logon name suffix to the new suffix. Example verified on asmith: logon name `asmith@nnmkhoa.onmicrosoft.com`; the pre-Windows 2000 logon name `CORP\asmith` is unchanged, and passwords/domain sign-ins are unaffected.

*Screenshots: `upn-suffix-added.png`, `asmith-upn-flipped.png`*

## 3. Microsoft Entra Connect Sync — installation and configuration

Downloaded from the Entra admin centre (**Entra Connect → Get started → Connect Sync → Download Connect Sync Agent**). The legacy product name survives under the hood: the installer lives in `C:\Program Files\Microsoft Azure Active Directory Connect\` and the executable is `AzureADConnect.exe` — on Windows Server, relaunching the wizard later is easiest via the Run box with that full path, because Start search does not index it.

The **Customise** path was used (Express offers no OU scoping). Choices, with reasons:

| Setting | Choice | Why |
|---|---|---|
| User sign-in | **Password Hash Synchronisation (PHS)** | Users sign in to cloud apps with their AD password; a hash of the password hash syncs — the password itself never leaves the network |
| Seamless single sign-on | Off | Optional polish; can be enabled later from the wizard's task list |
| Connector account | Wizard-created ("Create a new account") | Dedicated, least-privilege account instead of reusing an admin |
| Domain/OU filtering | **Employees + Workstations OUs only** | Least privilege: the cloud only receives what it needs. Service Accounts, the DC's own OU and built-ins stay on-premises |
| Source anchor | "Let Azure manage" (written to `mS-DS-ConsistencyGuid`) | The immutable ID that permanently links each AD object to its cloud twin |
| Optional features | Password writeback, group writeback, device writeback all **off** | Deliberate minimal surface for the lab |
| Staging mode | Off; initial sync started on completion | Single sync server |

One screen deserves explanation: **Microsoft Entra sign-in configuration** listed *both* suffixes (`corp.local` and `nnmkhoa.onmicrosoft.com`) as **"Not Added"**, and configuration proceeded via the "Continue without matching all UPN suffixes to verified domains" checkbox, keeping `userPrincipalName` as the username attribute. `corp.local` can never be added (unverifiable by design). The tenant domain shows "Not Added" because that column tracks *custom* domains — `nnmkhoa.onmicrosoft.com` is the tenant's built-in default domain, and it works: it is the suffix the Phase 3 test user already signs in with.

The completion page also recommended enabling the **Active Directory Recycle Bin** for the forest (genuine recommendation, optional — not yet done) and a Trusted Platform Module (TPM) for the sync server (skipped in the lab).

*Screenshots: `entra-connect-download.png`, `connect-sync-phs.png`, `entra-signin-configuration.png`, `connect-ou-filtering.png`, `connect-sync-complete.png`*

## 4. Synchronisation verification

Four checks, all passed:

1. **Users arrived.** Microsoft 365 admin centre → Active users lists the synchronised users with `@nnmkhoa.onmicrosoft.com` names and **Unlicensed** status (expected — sync does not assign licences). Total: 55 users (54 provisioned + knguyen) and the 3 department groups. The tenant now shows two "Khoa Nguyen" entries — the cloud-only admin and the synchronised on-prem account — which is deliberate admin-account separation.
2. **Group membership synced.** asmith's user card shows her **IT-Users** membership, and **Delete is greyed out** — a synchronised object is mastered on-premises, so the cloud cannot delete or edit it.
3. **Scope held.** Searching Active users for `svc-` returns nothing: `svc-backup` stayed on-premises, proving the OU filtering worked. (CORP\Administrator and the DC itself were likewise not synchronised.)
4. **PHS proven.** Signing in to the cloud as asmith with her **AD password succeeded** — authentication passed, and Outlook on the web then failed with `OwaUserHasNoMailboxAndNoLicenseAssignedException`. That is a *post-authentication* licencing error (no licence → no mailbox), which is exactly the evidence that the password hash sync works.

*Screenshots: `synced-users-list.png`, `asmith-synced-details.png`, `sync-scope-svc-search.png`, `phs-outlook-licence-error.png`*

## 5. Licencing asmith — and an attribute that doesn't exist

Plan: set asmith's usage location on-premises (attribute `msExchUsageLocation` = CA) so it would flow through sync — licence assignment in the portal requires a usage location.

**Finding:** the attribute **does not exist in this forest**. asmith's Attribute Editor jumps from `msExchLabeledURI` straight to `msIIS-FTPDir`. `msExchUsageLocation` only exists when the **Exchange schema extensions** have been applied; Exchange was never installed here, so the attribute was never added to the schema. A small set of legacy `msExch*` attributes ship in the base schema, which is why the list *looks* Exchange-ish at first glance.

**Plan B (what was done):** with nothing on-premises mapped to usage location, the portal owns the field. In the Microsoft 365 admin centre, asmith's licence page set **Select location: Canada** directly and assigned **Office 365 E5** + **Enterprise Mobility + Security E5** (the latter carries the Intune licence this phase needs). Her mailbox then provisioned, retiring the Outlook error from §4.

*Screenshots: `attribute-editor-no-usage-location.png`, `asmith-licences-assigned.png`*

## 6. Hybrid join preparation

### 6a. Service Connection Point (SCP)

Hybrid join needs an SCP: a small object in AD's configuration partition that domain devices read to discover their Entra tenant (name + tenant ID). Written via the Entra Connect wizard → **Tasks → Configure device options → Configure Hybrid Microsoft Entra ID join** → Windows 10 or later devices → forest `corp.local`, Authentication Service **Microsoft Entra ID**, Enterprise Admin credentials supplied.

**First attempt failed** with a generic error page ("An error has occurred on the SCP page… Win32Exception — A device attached to the system is not functioning"). The error named its log: `C:\ProgramData\AADConnect\trace-20261031-161309.log`. Reading the log tail showed only successful telemetry uploads, so the log was searched as a whole (`Select-String -Pattern "ERROR"` in PowerShell) — Notepad's Find had failed twice because it starts from the cursor with no wrap-around. The search showed the wizard's sign-in broker had in fact **authenticated successfully** (HTTP 200) and the failure came later, "getting auth providers" — wizard plumbing against this VM, not credentials or AD. **A straight retry of the same task then completed successfully** and the SCP is written.

Device **writeback** was deliberately not configured (it serves Active Directory Federation Services / Windows Hello key-trust scenarios, neither used here).

*Screenshots: `scp-configuration.png`, `scp-error.png`, `aadconnect-log-error-search.png`, `scp-complete.png`*

### 6b. Mobile Device Management (MDM) user scope and the enrolment Group Policy Object (GPO)

- Entra admin centre → **Mobility (MDM and WIP) → Microsoft Intune → MDM user scope: All** → Save (confirmation toast received). This is the tenant-side switch deciding who may enrol devices; without it the GPO push below fails.
- New GPO **"Intune Auto-Enrollment"**, linked to the **Workstations OU**: Computer Configuration → Policies → Administrative Templates → Windows Components → **MDM** → **"Enable automatic MDM enrollment using default Azure AD credentials" = Enabled** (credential type: User Credential, the default).

*Screenshots: `mdm-user-scope-all.png`, `gpo-mdm-enrollment-enabled.png`*

## 7. CORP-WS01 hybrid join — troubleshooting log

### 7a. The sign-in that "failed" (Enhanced Session)

Signing in to CORP-WS01 as `CORP\asmith` through the Hyper-V console failed: *"To sign in remotely, you need the right to sign in through Remote Desktop Services…"*. Cause: the connection was in **Enhanced Session Mode**, which is Remote Desktop Protocol (RDP) in disguise — and asmith has no RDP sign-in right (and, by design of the Phase 1 "Workstation Local Admins" GPO, no local admin back door either). Fix: **View → Enhanced Session OFF** (Basic session = true console logon). asmith signed in normally. Her own lockdown policy working as intended.

*Screenshot: `enhanced-session-signin-error.png`*

### 7b. Registration attempts fail — Event 420

After `gpupdate /force` (both policies applied successfully), `dsregcmd /status` showed **DomainJoined: YES, AzureAdJoined: NO**. Manually running the `\Microsoft\Windows\Workplace Join\Automatic-Device-Join` scheduled task required elevation (a standard user gets "Access is denied"; User Account Control (UAC) credentials of `CORP\Administrator` were used — the over-the-shoulder pattern: the user stays standard, an admin lends credentials to one window).

The attempts' own log — **Event Viewer → Microsoft → Windows → User Device Registration → Admin** — showed repeated **Event 420**:

> Automatic registration failed at authentication phase. Unable to acquire Kerberos ticket. Exit code: No authority could be contacted for authentication. Kerberos endpoint: https://login.microsoftonline.com/\<tenant-id\>/kerberos

What the evidence ruled in and out:

| Check | Result | Meaning |
|---|---|---|
| Event 101 in the same log | Discovery callback **successful**, correct tenant endpoints returned | SCP (§6a) works; the device finds the right tenant |
| `nltest /dsgetdc:corp.local` | DC found at 192.168.10.10, flags include **KDC**, GC, LDAP; completed successfully | DC location/DNS healthy |
| `klist -li 0x3e7` (SYSTEM session) | `corp-ws01$` holds fresh **AES-256** Kerberos tickets issued by the DC | Machine Kerberos works for ordinary AD operations — yet attempts at that same minute still failed with Event 420 |

**Resolution:** CORP-DC01 had not been restarted since before the §1 network switch change. After a **clean reboot of CORP-DC01**, the next automatic registration attempt succeeded: the Entra admin centre showed CORP-WS01 registered at 4:59 PM with Join type **Microsoft Entra hybrid joined**, and `dsregcmd /status` confirmed **AzureAdJoined: YES**, **DeviceAuthStatus: SUCCESS**, with a TPM-protected device certificate (valid 2026–2036). Working diagnosis: the DC's Kerberos/Netlogon state was stale after the network change; a clean DC boot cleared it. (A plausible-looking theory along the way — that Edge tabs open on the 4 GB DC were starving it of memory — was checked and discarded: no Edge was open on the DC. The portals run in the host's browser, where they belong.)

Side observation: Entra Devices also lists the DC itself (WIN-D8E44CTNJU) as **Microsoft Entra registered** with owner Khoa Nguyen — a side effect of signing in to the wizard flows on the DC. Harmless; optional cleanup.

*Screenshots: `dsregcmd-before-join.png`, `event-420-kerberos-error.png`, `nltest-dc-discovery.png`, `klist-machine-tickets.png`, `entra-devices-hybrid-joined.png`, `dsregcmd-joined-yes.png`*

## 8. Intune enrolment

With the join in place, asmith's next sign-in on CORP-WS01 fired the §6b GPO enrolment. The device-side evidence is in **Event Viewer → Microsoft → Windows → DeviceManagement-Enterprise-Diagnostics-Provider → Admin**: enrolment processing (Enrolment Type `MDMDeviceWithAAD`) ran at 5:13 PM. One **Event 454** error appeared during provisioning — the management client failed to apply the DMClient **CertPinning** node (Win32 error 0x86000011) — and proved **non-fatal**: the enrolment completed regardless. (The Settings → Access work or school page never did display an MDM entry; the portal is the definitive source.)

**Verification — Intune admin centre → Devices → Windows:**

| Field | Value |
|---|---|
| Device name | CORP-WS01 |
| Managed by | **Intune** |
| Ownership | Corporate |
| Compliance | **Compliant** |
| OS version | 10.0.26300.9457 |
| Primary user UPN | asmith@nnmkhoa.onmicrosoft.com |
| Last check-in | 10/31/2026, 05:13 PM |

*Screenshots: `event-454-mdm-certpinning.png`, `intune-device-compliant.png`*

## 9. Phase 4 verification checklist

- [x] Alternate UPN suffix added; all Employees users flipped to `@nnmkhoa.onmicrosoft.com`
- [x] Lab VMs moved to a dedicated internal switch with a real gateway and host NAT; DC has internet
- [x] Entra Connect Sync installed (Customise path): PHS, OU filtering to Employees + Workstations, source anchor `mS-DS-ConsistencyGuid`
- [x] 55 users + 3 groups in the tenant; group membership synced; synchronised objects mastered on-premises (portal Delete greyed out)
- [x] OU scope proven (`svc-backup` absent from the tenant)
- [x] PHS proven by asmith's cloud sign-in with her AD password
- [x] asmith licenced (Office 365 E5 + EMS E5, usage location Canada set in the portal after the `msExchUsageLocation` finding)
- [x] SCP written (after one diagnosed wizard failure and retry)
- [x] MDM user scope = All; "Intune Auto-Enrollment" GPO enabled on the Workstations OU
- [x] CORP-WS01 hybrid joined (AzureAdJoined: YES, DeviceAuthStatus: SUCCESS)
- [x] CORP-WS01 enrolled in Intune and Compliant

## 10. Known leftovers (deliberate, not defects)

- **Active Directory Recycle Bin** not yet enabled for `corp.local` (recommended on the sync configuration-complete page).
- **Seamless single sign-on** not enabled in Entra Connect (optional).
- The DC's stray **Microsoft Entra registered** device object (§7b) could be deleted from Entra Devices.
- The tenant admin account still has no multifactor authentication method registered (Phase 3 leftover hardening).
- Both trials (Office 365 E5, EMS E5) have **recurring billing OFF** and expire **November 30, 2026**; a re-check reminder is set for November 25, 2026. All Phase 4 cloud work was completed inside the trial window.
