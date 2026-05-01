## 10.1 - Users and Groups

### Build the CSV

Created a CSV file of 100 NBA players across 10 teams. The file has two columns: `Name` and `Team`. Each team acts as a group in Active Directory.

```<img width="960" height="376" alt="Screenshot 2026-04-29 171517" src="https://github.com/user-attachments/assets/0151dea7-b10d-488e-bec4-b5c7c222b0d5" />
<img width="960" height="376" alt="Screenshot 2026-04-29 171517" src="https://github.com/user-attachments/assets/c9f16e6f-b412-4c53-8cf6-ec988d65d684" />

Name,Team
LeBron James,Lakers
Anthony Davis,Lakers
Stephen Curry,Warriors
Klay Thompson,Warriors
...
```

The full CSV is saved at `ansible/users.csv` in the repo.

### Create the Ansible Playbook

Created `provision-users.yml` to copy the CSV to dc-blue1, create AD groups, create AD users, wait for AD to register the new objects, assign users to their groups, and fetch the credentials file back to xubuntu-wan.

```yaml
---
- name: Provision NBA Players to BLUE1.LOCAL
  hosts: servers
  gather_facts: no

  tasks:

    - name: Copy users CSV to dc-blue1
      win_copy:
        src: "{{ playbook_dir }}/users.csv"
        dest: C:\users.csv

    - name: Create AD groups from CSV
      win_shell: |
        Import-Module ActiveDirectory
        $users = Import-Csv -Path "C:\users.csv"
        $teams = $users | Select-Object -ExpandProperty Team -Unique
        foreach ($team in $teams) {
          if (-not (Get-ADGroup -Filter "Name -eq '$team'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name $team `
              -GroupScope Global `
              -GroupCategory Security `
              -Path "OU=Groups,OU=Accounts,OU=BLUE1,DC=BLUE1,DC=LOCAL"
            Write-Host "Created group: $team"
          } else {
            Write-Host "Group already exists: $team"
          }
        }

    - name: Create AD users and assign to groups
      win_shell: |
        Import-Module ActiveDirectory
        $users = Import-Csv -Path "C:\users.csv"
        foreach ($user in $users) {
          $username = ($user.Name -replace ' ', '.').ToLower()
          $password = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 12 | ForEach-Object {[char]$_}) + "!1"
          $securePass = ConvertTo-SecureString $password -AsPlainText -Force

          if (-not (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue)) {
            New-ADUser `
              -Name $user.Name `
              -SamAccountName $username `
              -UserPrincipalName "$username@BLUE1.LOCAL" `
              -AccountPassword $securePass `
              -Enabled $true `
              -Path "OU=Accounts,OU=BLUE1,DC=BLUE1,DC=LOCAL"
            Write-Host "Created user: $username"
          } else {
            Write-Host "User already exists: $username"
          }

          $entry = "$username,$($user.Team),$password"
          Add-Content -Path "C:\credentials.txt" -Value $entry
        }

    - name: Wait for AD to register new users
      win_shell: Start-Sleep -Seconds 15

    - name: Assign users to groups
      win_shell: |
        Import-Module ActiveDirectory
        $users = Import-Csv -Path "C:\users.csv"
        foreach ($user in $users) {
          $username = ($user.Name -replace ' ', '.').ToLower()
          $adUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue
          if ($adUser) {
            Add-ADGroupMember -Identity $user.Team -Members $username -ErrorAction SilentlyContinue
            Write-Host "Assigned $username to $($user.Team)"
          }
        }

    - name: Fetch credentials file from dc-blue1
      fetch:
        src: C:\credentials.txt
        dest: /home/dylan-george/credentials.txt
        flat: yes
```

The `Wait for AD to register new users` task adds a 15 second pause between user creation and group assignment. Without this, the group assignment runs before AD fully registers the new user objects and the `MemberOf` attribute does not populate. The credentials file is fetched to `/home/dylan-george/credentials.txt` which is outside the repo to keep passwords out of version control.

### Run the Playbook

```bash
ansible-playbook -i windows.yml provision-users.yml
```
<img <img width="1085" height="320" alt="Screenshot 2026-04-29 172625" src="https://github.com/user-attachments/assets/e79c924f-580e-4e9d-b677-7c3c55b54b5d" />
alt="Screenshot 2026-04-29 171517" src="https://github.com/user-attachments/assets/3f2b16d6-b2b7-4182-a1c8-b13fa8454fa6" />

### Verify - Deliverable 1

Logged into dc-blue1 as Administrator and ran the following to confirm two users from different groups:

```powershell
Get-ADUser -Identity "stephen.curry" -Properties MemberOf, DistinguishedName | Select-Object Name, DistinguishedName, MemberOf

Get-ADUser -Identity "lebron.james" -Properties MemberOf, DistinguishedName | Select-Object Name, DistinguishedName, MemberOf
```

Output confirmed both users are in `OU=Accounts,OU=BLUE1,DC=BLUE1,DC=LOCAL` and are members of their respective team groups in `OU=Groups,OU=Accounts,OU=BLUE1,DC=BLUE1,DC=LOCAL`.

<img alt="Screenshot 2026-04-29 172625" src="https://github.com/user-attachments/assets/72c76962-ea0c-460c-b98d-45405465744c" />

---

## 10.2 - File Services

### Clone fs-blue1

Used 480Utils to clone a new Server 2019 VM onto BLUE-LAN as the file server:

```powershell
New-480LinkedClone -VMName "2019-server" -SnapshotName "base" -CloneName "fs-blue1" -NetworkName "BLUE-LAN"
Start-480VM -VMName "fs-blue1"
```

Set the static IP using the existing `Set-480WindowsIP` function:

```powershell
Set-480WindowsIP -InterfaceName "Ethernet0 2"
# IP: 10.0.5.6, Gateway: 10.0.5.2, DNS: 10.0.5.5
```

### Add fs-blue1 to Inventory

Added fs-blue1 to `windows.yml`:

```yaml
fs-blue1:
  ansible_host: 10.0.5.6
  ansible_user: deployer
  ansible_connection: winrm
  ansible_winrm_transport: basic
  ansible_winrm_server_cert_validation: ignore
  ansible_port: 5985
```

Tested connectivity:

```bash
ansible fs-blue1 -i windows.yml -m win_ping
```

<img alt="Screenshot 2026-04-30 171440" src="https://github.com/user-attachments/assets/5cb207f8-d57e-4715-b577-f06528b7004d" />


### Create the File Server Playbook

Created `fileserver-blue1.yml` to set the hostname, join the domain, create share directories, and configure SMB shares with AD group permissions:

```yaml
---
- name: Configure File Server fs-blue1
  hosts: fs-blue1
  gather_facts: no

  vars_prompt:
    - name: domain_password
      prompt: "Enter BLUE1 Administrator password"
      private: yes

  tasks:

    - name: Set hostname to fs-blue1
      win_hostname:
        name: fs-blue1
      register: hostname_result

    - name: Reboot after hostname change
      win_reboot:
      when: hostname_result.reboot_required

    - name: Join fs-blue1 to BLUE1.LOCAL
      microsoft.ad.membership:
        dns_domain_name: BLUE1.LOCAL
        domain_admin_user: Administrator@BLUE1.LOCAL
        domain_admin_password: "{{ domain_password }}"
        state: domain
      register: domain_join

    - name: Reboot after domain join
      win_reboot:
      when: domain_join.reboot_required

    - name: Create share directories
      win_shell: |
        $teams = @("Lakers","Warriors","Bucks","Celtics","Nuggets","Sixers","Suns","Mavericks","Clippers","Heat")
        foreach ($team in $teams) {
          $path = "C:\Shares\$team"
          if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force
            Write-Host "Created: $path"
          } else {
            Write-Host "Already exists: $path"
          }
        }

    - name: Create SMB shares and set permissions
      win_shell: |
        $teams = @("Lakers","Warriors","Bucks","Celtics","Nuggets","Sixers","Suns","Mavericks","Clippers","Heat")
        foreach ($team in $teams) {
          $path = "C:\Shares\$team"

          if (-not (Get-SmbShare -Name $team -ErrorAction SilentlyContinue)) {
            New-SmbShare -Name $team -Path $path -FullAccess "BLUE1\$team"
            Write-Host "Created share: $team"
          } else {
            Write-Host "Share already exists: $team"
          }

          $acl = Get-Acl $path
          $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("BLUE1\$team","Modify","ContainerInherit,ObjectInherit","None","Allow")
          $acl.SetAccessRule($rule)
          Set-Acl $path $acl
          Write-Host "Permissions set for: $team"
        }
```

`microsoft.ad.membership` is used instead of `win_domain_membership` which was removed in ansible.windows 3.0.0. Each share is created with `New-SmbShare` granting `FullAccess` to the matching AD group. NTFS permissions are then set separately using `Set-Acl` so access control is enforced at both the share and filesystem level.

### Run the Playbook

```bash
ansible-playbook -i windows.yml fileserver-blue1.yml
```

<img alt="Screenshot 2026-05-01 160326" src="https://github.com/user-attachments/assets/c51a9112-bcd3-4853-8357-2f683c3cd86e" />

### Configure Group Policy Drive Mappings

Opened Group Policy Management on dc-blue1 and created a GPO called `Drive Mappings` linked to `BLUE1.LOCAL`. Under `User Configuration → Preferences → Windows Settings → Drive Maps`, added a mapped drive for each team with item-level targeting set to the matching AD security group:

- `F:` → `\\fs-blue1\Lakers` — targeted to `BLUE1\Lakers`
- `G:` → `\\fs-blue1\Warriors` — targeted to `BLUE1\Warriors`

<img alt="Screenshot 2026-05-01 161117" src="https://github.com/user-attachments/assets/f6db0dfd-7e8b-484c-9c59-94ad1b2c8cd9" />

### Verify - Deliverable 2

Logged into fs-blue1 as `BLUE1\lebron.james` (Lakers group member) and ran:

```powershell
whoami
Get-ChildItem \\fs-blue1\Lakers
Get-ChildItem \\fs-blue1\Warriors
```

Output confirmed:
- `whoami` shows `blue1\lebron.james`
- Lakers share is accessible
- Warriors share returns `Access is denied`

<img alt="Screenshot 2026-05-01 164103" src="https://github.com/user-attachments/assets/2b6b9ea7-718d-4635-9608-6390e0482620" />

---

## 10.3 - Windows Workstation

### Clone ws-blue1

Used 480Utils to clone a Server 2019 VM as the workstation onto BLUE-LAN:

```powershell
New-480LinkedClone -VMName "2019-server" -SnapshotName "base" -CloneName "ws-blue1" -NetworkName "BLUE-LAN"
Start-480VM -VMName "ws-blue1"
```

Set static IP:

```powershell
Set-480WindowsIP -InterfaceName "Ethernet0 2"
# IP: 10.0.5.7, Gateway: 10.0.5.2, DNS: 10.0.5.5
```

### Add ws-blue1 to Inventory

```yaml
ws-blue1:
  ansible_host: 10.0.5.7
  ansible_user: deployer
  ansible_connection: winrm
  ansible_winrm_transport: basic
  ansible_winrm_server_cert_validation: ignore
  ansible_port: 5985
```

Tested connectivity:

```bash
ansible ws-blue1 -i windows.yml -m win_ping
```

<img alt="Screenshot 2026-05-01 162719" src="https://github.com/user-attachments/assets/06aa0d62-d885-487a-a588-1c2ef6250940" />

### Create the Workstation Playbook

Created `workstation-blue1.yml` to set the hostname and join ws-blue1 to BLUE1.LOCAL:

```yaml
---
- name: Configure Workstation ws-blue1
  hosts: ws-blue1
  gather_facts: no

  vars_prompt:
    - name: domain_password
      prompt: "Enter BLUE1 Administrator password"
      private: yes

  tasks:

    - name: Set hostname to ws-blue1
      win_hostname:
        name: ws-blue1
      register: hostname_result

    - name: Reboot after hostname change
      win_reboot:
      when: hostname_result.reboot_required

    - name: Join ws-blue1 to BLUE1.LOCAL
      microsoft.ad.membership:
        dns_domain_name: BLUE1.LOCAL
        domain_admin_user: Administrator@BLUE1.LOCAL
        domain_admin_password: "{{ domain_password }}"
        state: domain
      register: domain_join

    - name: Reboot after domain join
      win_reboot:
      when: domain_join.reboot_required
```

---
