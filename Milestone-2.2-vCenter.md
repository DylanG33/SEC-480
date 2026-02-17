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

<img src="https://github.com/user-attachments/assets/7ae9ea3b-4413-4964-b886-1b4d9ca3e5f8" />

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

<img src="https://github.com/user-attachments/assets/28aea56c-4854-4f55-ac63-453be8fedffe" />

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

<img src="https://github.com/user-attachments/assets/de3e69fe-6b1a-4201-a3bb-4234b976c009" />

## Accessing vCenter and Adding the ESXi Host

8. Once both stages complete, open a browser on xubuntu-wan and navigate to `https://vcenter.dylan.local`. Log in with `Administrator@DYLAN.LOCAL` and the password you set during installation.

<img src="https://github.com/user-attachments/assets/cb759e63-d99d-4fc4-be07-353573f7ed09" />

9. Right-click on vcenter.dylan.local in the left sidebar and select "New Datacenter." Name it `480-Dylan`.

10. Right-click on the 480-Dylan datacenter and select "Add Host." Enter the ESXi host IP address (192.168.3.227), provide the root credentials, and accept the certificate. Review the host summary showing the Supermicro Super Server running VMware ESXi 8.0.0 with VMs 480-fw, xubuntu-wan, WinServer19, and dylan-vcenter. Click through the remaining defaults and hit Finish.

<img src="https://github.com/user-attachments/assets/e099aaa6-fd37-43fa-9a67-a1b5e5b8b050" />

11. After the host is added, the vSphere Client displays the full inventory. The 480-Dylan datacenter contains the ESXi host at 192.168.3.227, and all VMs (480-fw, dylan-vcenter, WinServer19, xubuntu-wan) are visible in the sidebar.
    
<img src="https://github.com/user-attachments/assets/2a03d5c7-8886-400a-aab9-ba0a3315d0fa" />

