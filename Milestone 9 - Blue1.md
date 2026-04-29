# Milestone 9 - Blue1.local

### Clone dc-blue1

From xubuntu-wan in PowerShell, used 480Utils to create a linked clone of the Server 2019 base on the BLUE-LAN network and started it:

```powershell
Import-Module ~/SEC-480/480Utils.psm1
480Connect -server "vcenter.dylan.local"
New-480LinkedClone -VMName "2019-server" -CloneName "dc-blue1" -NetworkName "BLUE-LAN"
Start-480VM -VMName "dc-blue1"
```

### Add Set-480WindowsIP to 480Utils.psm1

Added a new function to `480Utils.psm1` that uses `Invoke-VMScript` to run `netsh` commands inside the guest OS to set a static IP without needing a direct network connection to the VM.

```powershell
function Set-480WindowsIP {
    param(
        [string]$VMName,
        [string]$IPAddress,
        [string]$Gateway,
        [string]$DNS,
        [string]$GuestUser,
        [System.Security.SecureString]$GuestPassword,
        [string]$InterfaceName = "Ethernet0"
    )

    if (-not $VMName) { $VMName = Read-Host "Enter VM name" }
    if (-not $IPAddress) { $IPAddress = Read-Host "Enter static IP address" }
    if (-not $Gateway) { $Gateway = Read-Host "Enter gateway" }
    if (-not $DNS) { $DNS = Read-Host "Enter DNS server" }
    if (-not $GuestUser) { $GuestUser = Read-Host "Enter guest username" }
    if (-not $GuestPassword) { $GuestPassword = Read-Host "Enter guest password" -AsSecureString }

    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "VM '$VMName' not found" -ForegroundColor Red
        return
    }

    $cred = New-Object System.Net.NetworkCredential($GuestUser, $GuestPassword)
    $plainPass = $cred.Password

    $setIP = "netsh interface ip set address name=`"$InterfaceName`" static $IPAddress 255.255.255.0 $Gateway"
    $setDNS = "netsh interface ip set dns name=`"$InterfaceName`" static $DNS"

    Write-Host "Setting static IP on $VMName..."
    Invoke-VMScript -VM $vm -ScriptText $setIP -GuestUser $GuestUser -GuestPassword $plainPass -ScriptType Bat
    Invoke-VMScript -VM $vm -ScriptText $setDNS -GuestUser $GuestUser -GuestPassword $plainPass -ScriptType Bat

    Write-Host "IP set to $IPAddress on $VMName." -ForegroundColor Green
}
```

The function follows the same `Read-Host` pattern used throughout 480Utils so calling it with no arguments prompts for each value interactively. `System.Net.NetworkCredential` is used to convert the SecureString password to plaintext only at the point `Invoke-VMScript` requires it.

### Run Set-480WindowsIP

Reimported the module and called the function with the correct interface name for dc-blue1:

```powershell
Import-Module "/home/dylan-george/SEC-480/modules/480-utils" -Force
Set-480WindowsIP -InterfaceName "Ethernet0 2"
```

Filled in the prompts:
- VM name: `dc-blue1`
- Static IP: `10.0.5.5`
- Gateway: `10.0.5.2`
- DNS: `10.0.5.5`
- Guest user: `deployer`

### Verify Static IP

Opened the dc-blue1 console in the ESXi host client and confirmed the IP configuration:

```cmd
ipconfig /all
```

<img<img width="2533" height="855" alt="Screenshot 2026-04-29 110854" src="https://github.com/user-attachments/assets/fff34ac1-77c5-4ffb-9691-d8823e924fde" />
 src="https://github.com/user-attachments/assets/37cf3025-1aa9-4b7a-949b-f0bf59d4665e" />

---

## ADDS Deployment over Ansible

### Enable WinRM on dc-blue1

From an Administrator command prompt on dc-blue1, enabled WinRM for remote management and opened port 5985 in the firewall:

```cmd
winrm quickconfig -q
winrm set winrm/config/service/auth @{Basic="true"}
winrm set winrm/config/service @{AllowUnencrypted="true"}
netsh advfirewall firewall add rule name="WinRM HTTP" protocol=TCP dir=in localport=5985 action=allow
```

### Install pywinrm on xubuntu-wan

Ansible requires the pywinrm Python library to connect to Windows hosts over WinRM:

```bash
pip install pywinrm --break-system-packages
```

### Windows Inventory File

Created `windows.yml` to define the Windows host group and WinRM connection variables:

```yaml
all:
  children:
    servers:
      hosts:
        dc-blue1:
          ansible_host: 10.0.5.5
          ansible_user: deployer
          ansible_connection: winrm
          ansible_winrm_transport: basic
          ansible_winrm_server_cert_validation: ignore
          ansible_port: 5985
```

`ansible_connection: winrm` tells Ansible to use WinRM instead of SSH. `ansible_winrm_transport: basic` uses basic auth over HTTP on port `5985`.

Tested connectivity:

```bash
ansible servers -i windows.yml -m win_ping
```

### ADDS Playbook

Created `adds-blue1.yml` to handle the full domain controller deployment:

```yaml
---
- name: Deploy ADDS on dc-blue1
  hosts: servers
  gather_facts: no

  vars_prompt:
    - name: admin_password
      prompt: "Enter new local Administrator password"
      private: yes

  tasks:

    - name: Set local Administrator password
      win_user:
        name: Administrator
        password: "{{ admin_password }}"
        state: present

    - name: Set hostname to dc-blue1
      win_hostname:
        name: dc-blue1
      register: hostname_result

    - name: Reboot after hostname change
      win_reboot:
      when: hostname_result.reboot_required

    - name: Install ADDS and promote to domain controller
      microsoft.ad.domain:
        dns_domain_name: BLUE1.LOCAL
        domain_netbios_name: BLUE1
        safe_mode_password: "{{ admin_password }}"
      register: domain_install

    - name: Reboot after domain promotion
      win_reboot:
        test_command: 'exit (Get-Service -Name DNS).Status -ne "Running"'
      when: domain_install.reboot_required

    - name: Pause to let DNS stabilize
      pause:
        seconds: 60

    - name: Add DNS forwarder
      win_shell: Add-DnsServerForwarder -IPAddress 8.8.8.8

    - name: Create BLUE1 top-level OU
      win_shell: |
        Import-Module ActiveDirectory
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'BLUE1'" -ErrorAction SilentlyContinue)) {
          New-ADOrganizationalUnit -Name "BLUE1" -Path "DC=BLUE1,DC=LOCAL"
        }
      register: ou_result
      retries: 5
      delay: 15
      until: ou_result.rc == 0

    - name: Create Accounts OU under BLUE1
      win_shell: |
        Import-Module ActiveDirectory
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Accounts'" -SearchBase "OU=BLUE1,DC=BLUE1,DC=LOCAL" -ErrorAction SilentlyContinue)) {
          New-ADOrganizationalUnit -Name "Accounts" -Path "OU=BLUE1,DC=BLUE1,DC=LOCAL"
        }

    - name: Create Groups OU under Accounts
      win_shell: |
        Import-Module ActiveDirectory
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Groups'" -SearchBase "OU=Accounts,OU=BLUE1,DC=BLUE1,DC=LOCAL" -ErrorAction SilentlyContinue)) {
          New-ADOrganizationalUnit -Name "Groups" -Path "OU=Accounts,OU=BLUE1,DC=BLUE1,DC=LOCAL"
        }

    - name: Create Computers OU under BLUE1
      win_shell: |
        Import-Module ActiveDirectory
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Computers'" -SearchBase "OU=BLUE1,DC=BLUE1,DC=LOCAL" -ErrorAction SilentlyContinue)) {
          New-ADOrganizationalUnit -Name "Computers" -Path "OU=BLUE1,DC=BLUE1,DC=LOCAL"
        }

    - name: Create Servers OU under Computers
      win_shell: |
        Import-Module ActiveDirectory
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Servers'" -SearchBase "OU=Computers,OU=BLUE1,DC=BLUE1,DC=LOCAL" -ErrorAction SilentlyContinue)) {
          New-ADOrganizationalUnit -Name "Servers" -Path "OU=Computers,OU=BLUE1,DC=BLUE1,DC=LOCAL"
        }

    - name: Create Workstations OU under Computers
      win_shell: |
        Import-Module ActiveDirectory
        if (-not (Get-ADOrganizationalUnit -Filter "Name -eq 'Workstations'" -SearchBase "OU=Computers,OU=BLUE1,DC=BLUE1,DC=LOCAL" -ErrorAction SilentlyContinue)) {
          New-ADOrganizationalUnit -Name "Workstations" -Path "OU=Computers,OU=BLUE1,DC=BLUE1,DC=LOCAL"
        }
```

`vars_prompt` with `private: yes` prompts for the Administrator password at runtime so it is never stored in the playbook or inventory. The `microsoft.ad.domain` module handles the ADDS role installation and forest creation in a single task. The reboot after domain promotion uses `test_command` to wait until the DNS service is confirmed running before Ansible considers the host back online. Each OU task checks for existence before creating so the playbook is idempotent.

### Run the Playbook

```bash
ansible-playbook -i windows.yml adds-blue1.yml
```

<img src="https://github.com/user-attachments/assets/a2756968-a447-439c-ba95-1af6cbad14e5" />

### Verify

Logged into dc-blue1 as `BLUE1\Administrator` and ran the following to confirm domain, membership, and OU structure:

```powershell
hostname
whoami
Get-ADGroupMember -Identity "Domain Admins"
Get-ADOrganizationalUnit -LDAPFilter '(name=*)' -SearchBase 'OU=BLUE1,DC=BLUE1,DC=LOCAL' | Format-Table Name
```

<img src="https://github.com/user-attachments/assets/850d9490-b53c-4bff-a2a2-41752d4b0867" />


## Video
https://drive.google.com/file/d/1_RjjR1tYm81xTasmKuwmkEqfHMTXH2W0/view?usp=sharing 
---
