# Hybrid Enterprise Lab

A virtualized hybrid identity and infrastructure lab built in Hyper-V, simulating a small-enterprise network (`corp.local`) integrated with Microsoft Entra ID and Intune.

## Architecture Overview
- **Hypervisor:** Hyper-V (Windows Pro)
- **On-Premises Infrastructure:** Windows Server 2022 Domain Controller (`CORP-DC01`)
- **Core Services:** Active Directory Domain Services (AD DS), DNS, DHCP, Group Policy Objects (GPOs)
- **Cloud Identity:** Microsoft Entra ID (M365 E5 Tenant) & Microsoft Intune

## Progress Tracker
- [x] Phase 0: Environment setup, ISO downloads, and repo initialization.
- [/] Phase 1: On-Premise Domain Controller, DNS/DHCP, AD OU Structure, GPOs, and PowerShell provisioning.
- [ ] Phase 2: Client Workstation VM Domain Join & GPO verification.
- [ ] Phase 3: Microsoft 365 Cloud Tenant setup, MFA, and Conditional Access.
- [ ] Phase 4: Hybrid Identity Sync (Entra Connect) and Intune MDM enrollment.
- [ ] Phase 5: Documentation polish and resume integration.
