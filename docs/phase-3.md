# Phase 3 — Microsoft 365 Tenant, Entra ID, MFA and Conditional Access

**Status:** Complete — built and verified October 31, 2026
**Phase goal:** Stand up the cloud half of the lab: a Microsoft 365 tenant running Microsoft Entra ID, practise core Level 1 cloud admin tasks (create a user, assign licences), and enforce multi-factor authentication (MFA) with a Conditional Access policy — proven end-to-end in the sign-in logs.

## Environment

| Item | Value |
|---|---|
| Tenant domain | nnmkhoa.onmicrosoft.com |
| Tenant admin | KhoaNguyen@nnmkhoa.onmicrosoft.com |
| Test user | Lab Test User — labtest@nnmkhoa.onmicrosoft.com |
| Licences (apps/services) | Office 365 E5 trial — 25 licences |
| Licences (identity/security) | Enterprise Mobility + Security (EMS) E5 trial — 25 licences (adds Entra ID P2 and Intune) |
| Consoles used | Microsoft 365 admin center (users, licences, billing) and Microsoft Entra admin center (identity security) |

> Passwords are never recorded in this repository. The test user's temporary password was stored only in a password manager.

## Step 1 — Tenant signup and billing safeguards

The tenant was created with an **Office 365 E5 trial** (order confirmed October 31, 2026, CA$0.00 due on the day). The trial terms required payment details up front and would have auto-converted to a paid annual subscription (CA$667.20 + CA$86.74 estimated tax = CA$753.94) on November 30, 2026 if left alone.

Safeguard applied immediately after signup, before any lab work:

- **Billing → Your products → Office 365 E5 → Recurring billing: turned off.** The product page then reads "Expires on November 30, 2026" and the subscription status shows Active / Free trial — the trial runs to expiry and cannot convert. (Screenshot: `billing-e5-recurring-off.png`)
- A calendar reminder was set for November 25, 2026 to re-verify before the deadline.

## Step 2 — Verify licences

**Billing → Licences** confirmed the pool the lab would draw from: **Office 365 E5 — 25 total, 1 assigned (the tenant admin), 24 available.** (Screenshot: `licences-e5.png`)

## Step 3 — Create a cloud test user and assign a licence

In the Microsoft 365 admin center: **Users → Active users → Add a user**

- Display name: Lab Test User; username: `labtest@nnmkhoa.onmicrosoft.com`
- Auto-generated temporary password, with "Require this user to change their password when they first sign in" left on — the standard joiner flow
- Usage location: Canada; licence assigned: **Office 365 E5**
- The account has no administrator role ("No administrator access") — a deliberately ordinary user to act as the policy test subject. (Screenshot: `active-users.png`)

## Step 4 — First sign-in finding: password-only access

The test user's first sign-in (InPrivate browser window, office.com) required only the forced password change — **no MFA prompt appeared, and the sign-in succeeded on password alone.** Investigated from the admin side:

- **Security defaults: Enabled** (Entra admin center → Identity → Overview → Properties → Manage security defaults). (Screenshot: `security-defaults-enabled.png`)
- **Lab Test User → Authentication methods: "No usable methods"** — zero MFA methods registered. (Screenshot: `auth-methods-before.png`)

**Explanation:** security defaults require users to register for MFA but allow a **14-day grace period** before registration is enforced. On day one, the account was inside that window, so it was protected by a password and nothing else. This is the gap the rest of the phase closes: "MFA is available in the tenant" is not the same as "MFA is enforced at sign-in."

## Step 5 — The Conditional Access licence wall (and the fix)

Opening **Conditional Access** returned an access error:

> "No access. This feature requires a subscription to Microsoft Entra ID P1 or P2." (Error 401)

(Screenshot: `conditional-access-licence-error.png`)

**Root cause — a licensing bundle distinction:**

- The tenant's only Entra product was **Microsoft Entra ID Free** (confirmed on the Your products page — the Free tier is tenant-wide and not user-assignable, so no assignment can unlock Premium features). (Screenshot: `your-products-entra-free.png`)
- **Office 365 E5** (what the trial provided) covers apps and services only. Entra ID Premium lives in the **Enterprise Mobility + Security (EMS)** bundle; **Microsoft 365 E5** includes it because it is Office 365 E5 + EMS E5 + Windows. Intune (needed in Phase 4) is in EMS as well, so this wall would have blocked Phase 4 too.

**Fix:** an **EMS E5 trial** was added to the same tenant from the admin center Marketplace (25 licences, CA$0.00, October 31 – November 29, 2026).

- The checkout's second screen ("Trial renewal settings") revealed the trial would convert by default to a paid subscription — 1 licence, monthly, CA$29.40 + tax = CA$33.22 on November 30, 2026. (Screenshot: `ems-trial-renewal-settings.png`)
- The same safeguard as Step 1 was applied: the EMS product page confirms **Recurring billing off** ("Expires on November 30, 2026", trial Active, Free trial), so the conversion cannot occur. Both trials now share the same November 29/30 deadline and the same November 25 reminder. (Screenshot: `ems-recurring-billing-off.png`)
- EMS E5 licences were then assigned to both the tenant admin and Lab Test User (Users → Active users → user → Licences and apps). After a few minutes for licence propagation, Conditional Access opened normally.

## Step 6 — Build the Conditional Access policy (Report-only first)

Entra admin center → **Conditional Access → Policies → New policy**:

| Setting | Value |
|---|---|
| Name | Require MFA - Lab Test User |
| Users (Include) | Lab Test User only (admin deliberately excluded — no lockout risk) |
| Target resources | All resources (formerly "All cloud apps") |
| Network / Conditions | Not configured / none |
| Grant | Grant access → **Require multifactor authentication** |
| Session | None |
| Enable policy | **Report-only** |

(Screenshots: `ca-policy-details.png`, `ca-policy-report-only.png`)

**Report-only verification:** a fresh sign-in as the test user (sign out, then sign back in, so a new sign-in event is generated) was opened in **Sign-in logs**. On the sign-in's **Report only** tab, the policy had evaluated the sign-in:

- Policy: Require MFA - Lab Test User; Grant controls: Mfa
- Result: **Report-only: User action required** — the policy matched the right user and would have forced MFA if it had been On. (Screenshot: `signin-log-report-only.png`)

## Step 7 — Go live: security defaults off, policy on

1. **Security defaults → Disabled** (Identity → Overview → Properties → Manage security defaults; reason: the organization is using Conditional Access). Security defaults and Conditional Access are two engines for the same job and cannot run at the same time; the portal refuses to enable a policy while security defaults are on — the successful enable below confirms the switch took effect.
2. **Policy → Enable policy → On → Save** ("Successfully updated… Policy will be enabled in a few minutes"). The policies list then showed **State: On**. (Screenshot: `ca-policy-on.png`)

## Step 8 — Enforcement test

A fresh sign-in as Lab Test User was **interrupted** by the "Install Microsoft Authenticator" registration prompt — no skip option this time. (Screenshot: `mfa-registration-prompt.png`) Registration was completed with an authenticator app, and the sign-in finished with MFA.

After-state evidence:

- **Authentication methods (after):** the page now lists a usable method — **Software OATH token** (default sign-in method "OATH TOTP one-time code"). The registration landed as code-based one-time codes rather than a push-approval entry; a one-time code is a valid second factor and satisfies the policy. (Screenshot: `auth-methods-after.png`)
- **Sign-in logs (after):** the enforced sign-in (October 31, 2026, 3:16 PM) shows on its **Conditional Access** tab — Policy: **Require MFA - Lab Test User**, Grant controls: **Require multifactor authentication**, Result: **Success**. (Screenshot: `signin-log-ca-success.png`)

## Verification summary

- [x] Tenant created; admin sign-in working; licences verified (25 Office 365 E5)
- [x] Billing safeguards: recurring billing **off** on both trials; no conversion possible; reminder set for November 25, 2026
- [x] Cloud test user created with an E5 licence; no admin role
- [x] "Before" state documented: security defaults on, 14-day grace, zero MFA methods, password-only sign-in
- [x] Licence wall diagnosed (Office 365 E5 has no Entra ID Premium; tenant was Entra ID Free) and resolved with an EMS E5 trial
- [x] Conditional Access policy built least-privilege (test user only), proven in Report-only via sign-in logs
- [x] Security defaults disabled; policy switched **On**
- [x] Enforcement proven: sign-in interrupted, MFA registered, sign-in log Result **Success**

## Troubleshooting and lessons

- **"This feature requires a subscription to Microsoft Entra ID P1 or P2" (401):** the tenant is on Entra ID Free. Check **Billing → Your products** to see which Entra tier the tenant actually owns before assuming a bundle includes Premium — "E5" in Office 365 E5 and Microsoft 365 E5 are not the same bundle.
- **Trial checkout wording:** the first EMS trial screen ("renew before your trial expires") sounded non-converting; the *second* screen (Trial renewal settings) showed a paid conversion was configured. Read every checkout screen, and always verify **Recurring billing** on the product page afterwards.
- **Report-only results live on their own tab** in the new sign-in log details ("Report only"), separate from the "Conditional access" tab, which lists enforced policies.
- **Sign-in logs lag** by a few minutes, and an existing browser session won't generate a new sign-in event — sign out and back in to force one, then Refresh.
- **The redesigned Entra admin center** renames familiar items (e.g., "Resources (formerly cloud apps)") and hides Conditional Access outside the obvious menus; the top search bar is the fastest route to it.
- **Graceful sequencing matters:** policy created in Report-only → verified in logs → security defaults disabled → policy enabled. At no point was the admin account inside the policy's scope, so recovery was always one sign-in away.

## Screenshot index

| File | Shows |
|---|---|
| `billing-e5-recurring-off.png` | Office 365 E5 trial, recurring billing off |
| `licences-e5.png` | Licences page — 25 E5, 1 assigned |
| `active-users.png` | Both users in Active users; test user has no admin role |
| `security-defaults-enabled.png` | Security defaults Enabled (before state) |
| `auth-methods-before.png` | Test user — "No usable methods" |
| `conditional-access-licence-error.png` | Conditional Access blocked — P1/P2 required |
| `your-products-entra-free.png` | Your products — Entra ID Free is the only Entra product |
| `ems-trial-renewal-settings.png` | EMS trial renewal settings — the hidden conversion |
| `ems-recurring-billing-off.png` | EMS E5 trial Active, recurring billing off |
| `ca-policy-details.png` | Policy summary — 1 user, all resources, require MFA |
| `ca-policy-report-only.png` | Policies list — policy in Report-only |
| `signin-log-report-only.png` | Report-only verdict — "User action required" |
| `ca-policy-on.png` | Policies list — policy State: On |
| `mfa-registration-prompt.png` | Enforced sign-in interrupted for MFA registration |
| `auth-methods-after.png` | Test user — Software OATH token registered |
| `signin-log-ca-success.png` | Enforced sign-in — Conditional Access Result: Success |
