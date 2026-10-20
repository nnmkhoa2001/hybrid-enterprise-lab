# Phase 1: On-Premises Foundation & Domain Controller

## 1. Environment & Network Configuration
- **Virtual Machine:** `CORP-DC01` (Windows Server 2022 Gen 2 VM)
- **IP Addressing:** Static IP `192.168.10.10` configured on the internal virtual switch.
- **DNS Configuration:** Pointed primary DNS to loopback (`127.0.0.1`).

## 2. Active Directory Domain Services (AD DS)
- **Forest/Domain Name:** `corp.local`
- **Organizational Unit (OU) Structure:**
  - Created a root `Employees` OU.
  - Created an `IT` sub-OU under `Employees`.
- **Identity Provisioning:**
  - Created user account `knguyen` (`Khoa Nguyen`).
  - Assigned `knguyen` to the **Domain Admins** security group for administrative tasks.
