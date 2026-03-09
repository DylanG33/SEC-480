# Milestone 6 - Blue Network and Intro to Ansible

This milestone extended 480-utils with new network and VM control functions, cloned a new firewall for the BlueX environment, and got Ansible set up with an initial ping test.

---

## New 480-utils Functions

### New-Network
- Added `New-Network` to create a virtual switch and port group on a given ESXi host
- Validates the host exists first, then runs `New-VirtualSwitch` followed by `New-VirtualPortGroup`

### Get-IP
- Added `Get-IP` to pull the MAC and IP from the first network adapter of a named VM
- MAC comes from `Get-NetworkAdapter`, IP comes from `$vm.guest.ipaddress[0]`
- IP requires VMware Tools running on the guest, installed it on xubuntu-wan with:

```bash
sudo apt install open-vm-tools -y
```
---

## blue27-fw Linked Clone

- Used `New-480LinkedClone` to clone the vyos base image and named it `blueX-fw`
- Left the VM powered off for now, will be configured with Ansible later

<img src="https://github.com/user-attachments/assets/43c364ca-a335-4c91-ba3f-0437f9e95184" />

---

## Start and Stop Functions

- Added `Start-480VM` and `Stop-480VM` to 480-utils
- Named differently from the built-in PowerCLI commands to avoid conflicts
- Both check power state first and print yellow if the VM is already in that state
- Used `-Confirm:$false` on Stop so it does not prompt

---

## Set-Network 

- Added `Set-Network` to set a VM network adapter to a port group of your choice
- Lists all adapters with their index so you can pick which one to change
- Validates the VM and network exist before making any changes

```powershell
Set-Network
```
---

## Part 5 - Ansible Setup (6.3)

### Install
- Updated apt and installed ansible on xubuntu-wan:

```bash
sudo apt update
sudo apt install ansible -y
ansible --version
```

<img src="https://github.com/user-attachments/assets/2756453e-34a4-4f8f-ae70-4cbf26da4917" />

### Inventory and Config
- Created the ansible folder inside the SEC-480 repo and made an inventory file:

```bash
cd ~/SEC-480
mkdir ansible
cd ansible
nano inventory
```

- **(Partial for secuirty)** Inventory with lab VMs:

```ini
[all]
480-fw ansible_host=192.168.3.37
xubuntu-wan ansible_host=10.0.17.100
WinServer19 ansible_host=10.0.17.4
vcenter ansible_host=10.0.17.3
ubuntu-server ansible_host=192.168.3.51
```

<img src="https://github.com/user-attachments/assets/7dcde736-d625-408d-ac36-9932b85816a4" />

- Created `ansible.cfg` to point at the inventory and disable host key checking:

```ini
[defaults]
inventory = /home/dylan-george/SEC-480/ansible
host_key_checking = false
```

<img src="https://github.com/user-attachments/assets/726cfa1b-7127-414d-9c47-4ed38e1bf052" />

- Added a `.gitignore` so the inventory does not get pushed to GitHub since it could contain credentials later

### Ansible Ping

```bash
ansible all -i inventory -m ping
```

<img src="https://github.com/user-attachments/assets/de8bddef-e6ef-4329-b33f-e5f3a4a4ca59" />
