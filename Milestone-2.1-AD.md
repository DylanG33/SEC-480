# Milestone 2.1 - AD

This milestone builds on the existing architecture from Milestone 1. The goal is to deploy a Windows Server 2019 Domain Controller, create a sysprepped baseline image, and configure Active Directory services entirely through PowerShell.

## Creating the Windows Server 2019 Baseline

1. Pull the Windows Server 2019 ISO from `X:\ISOs\S25\SYS480` and upload it to your ESXi datastore.

2. Create a new VM in ESXi with the following specs: 2 vCPUs, 4 GB RAM, 90 GB HDD (thin provisioned), and a network adapter on VM Network. Attach the Server 2019 ISO as the CD/DVD drive. Do not enable Windows-based virtualization security.

3. Boot the VM and begin the Windows Server 2019 installation. Select "Windows Server 2019 Standard (Desktop Experience)" and choose "Custom" install. Select the empty 90 GB drive as the install target.

4. When prompted to set the Administrator password, do not set one. Press `CTRL + SHIFT + F3` to enter audit mode. Close the Sysprep dialog that appears.

5. Open an elevated PowerShell window and run `sconfig`. From here, make the following changes:
   - Option 5: Set Windows Update to Manual
   - Option 9: Set the timezone to Eastern
   - Option 6: Search for and install ALL available updates

   Updates will require multiple reboots. Keep searching and installing until no more updates are found. This took roughly 45 minutes to an hour.

6. Install VMware Tools. In the ESXi Host Client, go to the VM settings cog in the top right, then Guest OS > Install VMware Tools. This mounts the installer to the VM. Run the setup inside the VM and select "Typical." Restart the VM after installation.

7. Download the sysprep script from `https://tinyurl.com/480sysprep` using `wget` or Internet Explorer. Run each line individually in an elevated PowerShell session. Skip the `Write-Host` lines and power config lines. Uncomment any commented lines before running them.

8. Reboot the VM, then run the following command:

   ```
   C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /unattend:C:\unattend.xml
   ```

   If you get a popup saying "Sysprep tool is already running," close the Sysprep dialog window and try again. Wait for the process to complete and the VM to shut down.

9. After the VM powers off, edit the VM settings in ESXi. Change the CD/DVD drive to "Host Device." Verify the network adapter MAC address is set to "Automatic." If it shows a hardcoded MAC, remove and re-add the network adapter. Take a snapshot named "Base."

![ESXi Host Client showing the WinServer19 VM with the Base snapshot successfully created. VM specs show 2 vCPUs, 4 GB RAM, 90 GB HDD, VMware Tools installed, and MAC address set to Automatic.](Screenshot_2026-02-03_201335.png)

This Base snapshot is your clean Windows Server 2019 image. Keep it for future deployment labs. From here, continue using this VM to set up DC1.

## Configuring the Domain Controller

10. Power on the VM. When prompted, set the Administrator password. Change the network adapter to the 480-WAN port group. Set a static IP through the GUI on the console:
    - IP Address: 10.0.17.4
    - Subnet Mask: 255.255.255.0
    - Default Gateway: 10.0.17.2
    - DNS Server: 10.0.17.2

11. Rename the computer to `dc01` using PowerShell:

    ```
    Rename-Computer -NewName "dc01"
    ```

    Restart the VM for the name change to take effect.

![PowerShell showing the Rename-Computer command with a warning that changes take effect after restart.](Screenshot_2026-02-03_202300.png)

12. Verify the network configuration is correct before proceeding with the AD setup.

![Network Connection Details showing IPv4 address 10.0.17.4, subnet 255.255.255.0, gateway 10.0.17.2, and DNS 10.0.17.2.](Screenshot_2026-02-03_202315.png)

## AD Configuration via SSH from Xubuntu

From this point forward, all configuration is done remotely from the xubuntu-wan box over SSH. Open a terminal on xubuntu-wan and connect:

```
ssh Administrator@10.0.17.4
```

Enter the Administrator password when prompted, then launch PowerShell:

```
powershell
```

13. Install Active Directory Domain Services:

    ```
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    ```

14. Install the AD forest with DNS. This will reboot the server automatically:

    ```
    Install-ADDSForest -DomainName "dylan.local" -DomainNetbiosName "DYLAN" -InstallDns -Force
    ```

15. After the reboot, SSH back in and update the DNS client to point to itself:

    ```
    Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 10.0.17.4
    ```

16. Create forward lookup (A) records for the infrastructure hosts:

    ```
    Add-DnsServerResourceRecordA -Name "vcenter" -ZoneName "dylan.local" -IPv4Address 10.0.17.3
    Add-DnsServerResourceRecordA -Name "480-fw" -ZoneName "dylan.local" -IPv4Address 10.0.17.2
    Add-DnsServerResourceRecordA -Name "xubuntu-wan" -ZoneName "dylan.local" -IPv4Address 10.0.17.100
    ```

17. Create the reverse lookup zone and add PTR records:

    ```
    Add-DnsServerPrimaryZone -NetworkID "10.0.17.0/24" -ReplicationScope "Forest"
    Add-DnsServerResourceRecordPtr -Name "3" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "vcenter.dylan.local"
    Add-DnsServerResourceRecordPtr -Name "2" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "480-fw.dylan.local"
    Add-DnsServerResourceRecordPtr -Name "100" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "xubuntu-wan.dylan.local"
    Add-DnsServerResourceRecordPtr -Name "4" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "dc01.dylan.local"
    ```

18. Enable Remote Desktop:

    ```
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
    ```

19. Install and configure DHCP:

    ```
    Install-WindowsFeature -Name DHCP -IncludeManagementTools
    Add-DhcpServerInDC -DnsName "dc01.dylan.local" -IPAddress 10.0.17.4
    Add-DhcpServerv4Scope -Name "480-WAN-Scope" -StartRange 10.0.17.101 -EndRange 10.0.17.150 -SubnetMask 255.255.255.0 -State Active
    Set-DhcpServerv4OptionValue -ScopeId 10.0.17.0 -Router 10.0.17.2
    Set-DhcpServerv4OptionValue -ScopeId 10.0.17.0 -DnsServer 10.0.17.4
    ```

20. Create a named domain admin account:

    ```
    New-ADUser -Name "dylan-adm" -SamAccountName "dylan-adm" -UserPrincipalName "dylan-adm@dylan.local" -AccountPassword (ConvertTo-SecureString "YourPasswordHere" -AsPlainText -Force) -Enabled $true -PasswordNeverExpires $true
    Add-ADGroupMember -Identity "Domain Admins" -Members "dylan-adm"
    ```

## Verification

Run the following commands to confirm everything is configured correctly.

21. Verify the AD domain information:

    ```
    Get-ADDomain
    ```

![Get-ADDomain output showing the dylan.local forest, dc01.dylan.local as PDCEmulator, InfrastructureMaster, and RIDMaster, with DomainMode set to Windows2016Domain.](Screenshot_2026-02-03_210545.png)

22. Verify DNS records and DHCP scope:

    ```
    Get-DnsServerResourceRecord -ZoneName "dylan.local"
    Get-DhcpServerv4Scope
    ```

![DNS records for dylan.local showing A records for 480-fw, dc01, vcenter, and xubuntu-wan, along with SRV records for AD services. DHCP scope 480-WAN-Scope is active with range 10.0.17.101 to 10.0.17.150.](Screenshot_2026-02-03_210604.png)

23. Verify the domain admin user was created:

    ```
    Get-ADUser -Filter *
    ```

![Get-ADUser output showing Administrator (enabled), Guest (disabled), krbtgt (disabled), and dylan-adm with UPN dylan-adm@dylan.local.](Screenshot_2026-02-03_210630.png)
