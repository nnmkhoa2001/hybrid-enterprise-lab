Hybrid Enterprise Lab
A virtualized identity and infrastructure lab built in Hyper-V, simulating
the on-premises network of a small enterprise (corp.local). It is being built
in phases toward hybrid integration with Microsoft Entra ID and Intune.
The goal is to practise the tasks used daily in Level 1 help desk / service
desk roles: user account administration, group membership, DNS/DHCP checks,
joining computers to a domain, Group Policy, and clear technical
documentation.
Architecture Overview
Hypervisor: Hyper-V (Windows Pro)
On-Premises Infrastructure: Windows Server 2022 domain controller
  (Hyper-V VM name: CORP-DC01; Windows hostname: WIN-D8E44CTNJU)
Domain: corp.local — static IP 192.168.10.10
Core Services: Active Directory Domain Services (AD DS), DNS, DHCP,
  Group Policy Objects (GPOs)
Cloud Identity (planned, Phases 3-4): Microsoft Entra ID (Microsoft 365
  tenant) and Microsoft Intune, connected with Entra Connect Sync
flowchart TB
    subgraph Host["Windows host — Hyper-V"]
        DC["CORP-DC01 (WIN-D8E44CTNJU)<br/>Windows Server 2022<br/>192.168.10.10"]
        Client["Windows 11 client VM<br/>(Phase 2)"]
    end
    DC ---|"AD DS · DNS · DHCP<br/>corp.local"| Client
    DC -->|"GPOs: password policy,<br/>department drive mappings,<br/>workstation local admins"| Client
    DC -.->|"Entra Connect Sync<br/>(Phase 4)"| Entra["Microsoft Entra ID<br/>(Phase 3)"]
    Entra -.-> Intune["Microsoft Intune<br/>(Phase 4)"]
(Dashed connections are planned phases, not yet built.)
Progress Tracker
Phase 0: Environment setup, ISO downloads, and repo initialization
Phase 1: Domain controller, DNS/DHCP, AD OU structure, security
      groups, 54 provisioned users, and three GPOs (password/lockout,
      department drive mappings, workstation local admins)
Phase 2: Client workstation VM domain join and GPO verification
Phase 3: Microsoft 365 cloud tenant setup, MFA, and Conditional Access
Phase 4: Hybrid identity sync (Entra Connect) and Intune enrolment
Phase 5: Documentation polish and resume integration
Documentation
Phase 1 — On-premises foundation
Phase 2 — Endpoint join (to be added)
Phase 3 — Microsoft 365 tenant (to be added)
Phase 4 — Hybrid sync and Intune (to be added)
Note on PowerShell
Test user accounts in this lab were populated in bulk from a CSV using a
PowerShell provisioning script developed with AI assistance. PowerShell
script authorship is not claimed; the hands-on work in this project is the
Active Directory, DNS, and DHCP configuration and verification.
