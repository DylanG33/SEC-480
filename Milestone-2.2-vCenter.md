# Milestone 2.2 - vCenter

Milestones 1 and 2.1 should be completed. This lab deploys vCenter Server 8.0 onto the existing infrastructure and adds the ESXi host to a new datacenter.

## Preparation

1. Download the VCSA (vCenter Server Appliance) ISO and upload it to your ESXi datastore.

2. On xubuntu-wan, update the netplan configuration to point DNS to dc01 and add the dylan.local search domain. Edit the file with `sudo nano /etc/netplan/01-network-manager-all.yaml` and configure it as follows:

   ```yaml
   network:
     version: 2
     renderer: networkd
     ethernets:
       ens160:
         addresses:
           - 10.0.17.100/24
         routes:
           - to: default
             via: 10.0.17.2
         nameservers:
           addresses:
             - 10.0.17.4
           search:
             - dylan.local
   ```

   Apply the changes with `sudo netplan apply`.

![Netplan configuration on xubuntu-wan showing DNS pointed to 10.0.17.4 with dylan.local search domain.](Screenshot_2026-02-06_132017.png)

3. Add your ESXi host to `/etc/hosts` so `nslookup` resolves properly. This is needed for the VCSA installer to work. Verify that `nslookup vcenter.dylan.local` resolves to 10.0.17.3 before proceeding.

4. In the ESXi Host Client, go to Host > Manage > System > Time & Date > Edit NTP Settings. Set the NTP server to `pool.ntp.org`. Then go to Services, find the NTP Daemon, start it, and set its policy to "Start and stop with host." Time sync between ESXi and DC is important for vCenter to install properly.

## Installing vCenter Server

5. In ESXi, edit the xubuntu-wan VM settings and add a new CD/DVD drive. Select the VCSA ISO you uploaded to the datastore. Make sure the drive is connected. The ISO should mount automatically inside the VM.

6. On xubuntu-wan, open a terminal and navigate to the installer directory:

   ```
   cd /media/dylan-george/VMware\ VCSA/vcsa-ui-installer/lin64/
   ./installer --no-sandbox
   ```

   This launches the vCenter Server 8.0 graphical installer. Select "Install" to begin a fresh vCenter Server deployment.

![vCenter Server 8.0 Installer launched from xubuntu-wan showing the Install, Upgrade, Migrate, and Restore options.](Screenshot_2026-02-06_132047.png)

7. The installation runs in two stages. Stage 1 deploys the VCSA appliance to your ESXi host. Stage 2 configures vCenter services. Each stage takes 10-20 minutes once it starts.

   During Stage 1, provide the following:
   - ESXi host: your super's IP address (192.168.3.227)
   - ESXi root credentials
   - VM name: dylan-vcenter
   - Disk mode: Thin Disk
   - Network: VM Network (initially)

   During Stage 2, configure the network and SSO settings:
   - IP address: 10.0.17.3
   - Subnet mask: 24
   - Gateway: 10.0.17.2
   - DNS server: 10.0.17.4
   - Hostname: vcenter.dylan.local
   - SSO domain: dylan.local
   - SSO username: administrator
   - Time sync: Synchronize with ESXi host
   - SSH access: Activated

   Review the summary and click Finish.

![Stage 2 Ready to Complete screen showing network configuration with IP 10.0.17.3, gateway 10.0.17.2, DNS 10.0.17.4, hostname vcenter.dylan.local, and SSO domain dylan.local.](Screenshot_2026-02-06_141533.png)

## Accessing vCenter and Adding the ESXi Host

8. Once both stages complete, open a browser on xubuntu-wan and navigate to `https://vcenter.dylan.local`. Log in with `Administrator@DYLAN.LOCAL` and the password you set during installation.

![vSphere Client showing vcenter.dylan.local summary page with version 8.0.0, build 20519528, logged in as Administrator@DYLAN.LOCAL.](Screenshot_2026-02-06_145137.png)

9. Right-click on vcenter.dylan.local in the left sidebar and select "New Datacenter." Name it `480-Dylan`.

10. Right-click on the 480-Dylan datacenter and select "Add Host." Enter the ESXi host IP address (192.168.3.227), provide the root credentials, and accept the certificate. Review the host summary showing the Supermicro Super Server running VMware ESXi 8.0.0 with VMs 480-fw, xubuntu-wan, WinServer19, and dylan-vcenter. Click through the remaining defaults and hit Finish.

![Add Host wizard showing host summary for 192.168.3.227, a Supermicro Super Server running ESXi 8.0.0 with four VMs listed.](Screenshot_2026-02-06_145303.png)

11. After the host is added, the vSphere Client displays the full inventory. The 480-Dylan datacenter contains the ESXi host at 192.168.3.227, and all VMs (480-fw, dylan-vcenter, WinServer19, xubuntu-wan) are visible in the sidebar.

![vSphere Client showing the 480-Dylan datacenter with ESXi host 192.168.3.227 added and all VMs listed in the inventory tree.](Screenshot_2026-02-06_145338.png)
