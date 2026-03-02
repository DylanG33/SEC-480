
# Milestone 1 - Bare Metal ESXI Setup
## USB
1. Download RUFUS on your computer and format the disk to default using it (create a bootable ESXI USB)
2. Plugged my ESXI USB into my micro sever which is super4 for me 
3. Accessed my server via the IPMI IP Address and logged in with my credentials that I found in my email 
4. I spammed f11 like my life depended on it and selected the USB to boot from 
<img width="423" height="217" alt="image" src="https://github.com/user-attachments/assets/11be1675-650c-40bf-b666-a2843c653409" />

## Data stores 
* I had two drives so if you had one this is not the guide or notes that you should follow

**Pretty simple steps:**
1. Renamed the data store to datastore1-super27
2. Created another datastore called datastore2-super27
2. Create an ISO folder 
3. From there cyber share folder upload copies of Ubuntu and Pfsense 
*should look like this:
<img width="1008" height="471" alt="image" src="https://github.com/user-attachments/assets/4e3d4ffd-7eef-455b-be6b-7410f305ca46" />

## Creating 480-WAN Switch
* In the ESXi dashboard add a virtual switch called 480-WAN with MTU set as 1500 like this:
> <img width="1355" height="660" alt="image" src="https://github.com/user-attachments/assets/2fa2942c-fe9b-45cd-bdc7-3ed7076082a7" />

Also create a port group name 480-WAN and under virtual switch add the new one you just created. In the end it should look similar to this:
<img width="1392" height="635" alt="image" src="https://github.com/user-attachments/assets/8a0884e8-7846-4b15-8c4f-479ba040fbbf" />

## Creating VM
*Through the ESXI dashboard create the VM and use all the specifcations in the video, at the end it should look like this:
<img width="1384" height="695" alt="image" src="https://github.com/user-attachments/assets/a14643c3-b491-49e3-9992-4834f24311a5" />

### VM Creation and Initial Boot

After confirming the VM configuration, allow a few minutes for it to initialize. Access the VM console through your created instance - VyOS should begin its boot sequence.

Log into the system using the default credentials vyos/vyos. 

Accept the prompts and defaults throughout the installation process and reboot once installation completes.

### Base Network Configuration

Enter configuration mode and clear the hardware IDs to prepare for network changes:

```
configure
show interfaces
delete interfaces ethernet eth0 hw-id
delete interfaces ethernet eth1 hw-id
commit
save
set interfaces ethernet eth0 address dhcp
set service ssh listen-address 0.0.0.0
commit
save
exit
poweroff
```

### Post-Snapshot Network Setup

Before powering back on, create a base snapshot and modify the VM settings to connect the second network adapter to 480-WAN

Log back in and configure the static addressing and routing:

```
show interfaces
configure
delete interfaces ethernet eth0 address dhcp
set interfaces ethernet eth0 address 192.168.3.X/24
commit
save
ping 192.168.3.250
set protocols static route 0.0.0.0/0 next-hop 192.168.3.250
set interfaces ethernet eth0 description cyber
set interfaces ethernet eth1 description 480-wan
set interfaces ethernet eth1 address 10.0.17.2/24
set system name-server 192.168.4.4
set system name-server 192.168.4.5
set service dns forwarding listen-address 10.0.17.2
set service dns forwarding allow-from 10.0.17.0/24
set service dns forwarding system
set nat source rule 10 source address 10.0.17.0/24
set nat source rule 10 outbound-interface eth0
set nat source rule 10 translation address masquerade
set system host-name 480-fw
commit
save
```

**Note:** Replace X in the eth0 address with your assigned number. The eth0 address connects to the lab network, while eth1 uses a standard internal address shared with everyone.

Verify connectivity by pinging google.com

---

## Xubuntu Desktop VM Setup

### Creating the VM

From the Virtual Machines tab, select Create / Register VM. Configure with the following specs:

- **Storage:** datastore2
- **CPU:** 2 cores
- **RAM:** 3 GB
- **Hard disk:** 30 GB (thin provisioned)
- **Network:** VM Network (temporary for initial setup)
- **CD/DVD:** Mount the xubuntu ISO 

### Installation

Once the desktop loads, open a web browser and go to:

```
github.com/gmcyber/rangecontrol
```

go to src > scripts/base-vms and open ubuntu-desktop.sh. Copy the entire script 

Open a terminal and sudo -i

Paste and execute the script and after you're done, shut down the system:

### Switching to Internal Network

While the VM is powered off, edit its settings to change the network adapter from VM Network to 480-WAN. Take a base snapshot at this point. 
