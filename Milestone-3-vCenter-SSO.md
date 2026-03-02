# Milestone 3 - vCenter SSO Integration

This milestone continues from Milestone 2.2 where vCenter was deployed. The goal is to sync time across the environment, join vCenter to the dylan.local Active Directory domain, configure SSO with an AD identity source, and enable domain admin login to vCenter.

## NTP Time Synchronization

Before joining vCenter to the domain, it is critical that all systems in the environment are syncing to the same NTP time source. Time drift between vCenter and the domain controller will cause the AD join and SSO authentication to fail.

### Configuring NTP on dc01

SSH into dc01 from xubuntu-wan and configure the Windows Time service to sync from pool.ntp.org manually:

```
ssh dylan-adm@10.0.17.4
powershell
```

Run the following commands to set the NTP peer list to pool.ntp.org and force a resync:

```powershell
w32tm /config /manualpeerlist:"pool.ntp.org" /syncfromflags:manual /update
w32tm /resync
```

Verify the time configuration with:

```powershell
w32tm /query /status
w32tm /query /peers
```

The output should show that the source is syncing from pool.ntp.org and that the peer state is active. The stratum value of 1 indicates a primary reference synced by radio clock, and the last successful sync time confirms the service is working correctly.

<img src="https://github.com/user-attachments/assets/Screenshot_2026-02-18_103448.png" />

### Verifying NTP on ESXi

NTP was configured on the ESXi host during Milestone 2.2. To verify, log into the ESXi Host Client and navigate to Host > Manage > System > Time & Date. Confirm that the NTP server is set to `pool.ntp.org` and that the NTP Daemon service is running with the policy set to "Start and stop with host."

### Verifying NTP on vCenter

The vCenter Server Appliance management interface at `https://vcenter.dylan.local:5480` shows time synchronization status on the summary page. Confirm that the time settings are configured to sync with the ESXi host, which in turn syncs with pool.ntp.org. This ensures all three systems (dc01, ESXi, and vCenter) are using the same time source.

## Joining vCenter to the Domain

With time synchronized across the environment, vCenter can now be joined to the dylan.local Active Directory domain.

1. Log into the vSphere Client at `https://vcenter.dylan.local` using `Administrator@DYLAN.LOCAL`.

2. Navigate to **Administration > Single Sign On > Configuration**. On the left sidebar, click **Active Directory Domain**.

3. Click **Join AD** and enter the following:
   - Domain: `dylan.local`
   - Username: `dylan-adm` (or the full UPN `dylan-adm@dylan.local`)
   - Password: your domain admin password

4. After the domain join completes successfully, reboot the vCenter Server through the management interface at `https://vcenter.dylan.local:5480`. Do not power off the VM directly — use the management portal's reboot option to ensure a clean restart of all vCenter services.

5. Wait for vCenter to fully come back online. This can take several minutes as all services restart.

## Adding the AD Identity Source

After the reboot, the dylan.local domain needs to be added as an identity source so that AD users can authenticate to vCenter.

1. Log back into the vSphere Client at `https://vcenter.dylan.local` with `Administrator@DYLAN.LOCAL`.

2. Navigate to **Administration > Single Sign On > Configuration > Identity Sources**.

   Before adding the AD identity source, the page shows two existing sources: the System Domain (dylan.local for the SSO domain) and the Local OS (Default).

<img src="https://github.com/user-attachments/assets/Screenshot_2026-02-18_105405.png" />

3. Click **ADD** to add a new identity source. Select **Active Directory (Integrated Windows Authentication)** as the type. The domain should auto-populate as `dylan.local`. Click Add.

4. After adding the identity source, the Identity Sources list now shows three items: the System Domain (vsphere.local), the Local OS (Default), and the newly added dylan.local entry with type "Active Directory (Integrated Windows Authentication)" and alias "DYLAN."

<img src="https://github.com/user-attachments/assets/Screenshot_2026-02-18_131240.png" />

5. Optionally, select the dylan.local identity source and click **SET AS DEFAULT** to make it the default authentication domain. This means users can log in with just `dylan-adm` instead of needing to specify `dylan-adm@dylan.local` every time.

## Adding Domain Admins to the vCenter Administrators Group

With the AD identity source added, the dylan.local Domain Admins group needs to be granted administrative access within vCenter.

1. In the vSphere Client, navigate to **Administration > Single Sign On > Users and Groups > Groups**.

2. Find and select the **Administrators** group from the list.

3. Click **Edit**. In the "Add Members" section, change the domain dropdown to **dylan.local**.

4. Search for and add the following members:
   - `Administrator`
   - `domain admins`
   - `dylan-adm`

<img src="https://github.com/user-attachments/assets/Screenshot_2026-02-18_131213.png" />

5. Click **Save** to apply the changes. The dylan.local domain admins now have full administrative access to vCenter.

## Logging In with the Named Domain Admin

1. Log out of the vSphere Client.

2. Log back in using the named domain administrator account: `dylan-adm@DYLAN.LOCAL`.

3. After logging in, verify the login by checking the username displayed in the upper right corner of the vSphere Client. It should show `dylan-adm@DYLAN.LOCAL`.

<img src="https://github.com/user-attachments/assets/Screenshot_2026-02-18_131133.png" />

The vSphere Client displays the full vCenter inventory including vcenter.dylan.local, the 480-dylan datacenter, the ESXi host at 192.168.3.227, and all VMs (480-fw, vcenter, WinServer19, xubuntu-wan). The vCenter Details panel confirms version 8.0.0 with 1 host and 4 virtual machines. This confirms that the dylan-adm domain admin account has full administrative access to vCenter through the AD SSO integration.

## Summary

At the end of this milestone, the following has been accomplished:

- NTP is synchronized across dc01, ESXi, and vCenter using pool.ntp.org
- vCenter has been joined to the dylan.local Active Directory domain
- The dylan.local AD identity source has been added to vCenter SSO using Integrated Windows Authentication
- The dylan.local Domain Admins group and dylan-adm user have been added to the vCenter Administrators group
- The named domain admin account (dylan-adm@DYLAN.LOCAL) can successfully log into vCenter with full administrative access
