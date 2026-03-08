# Milestone 4 - PowerCLI and Linked Clones

This milestone installs PowerShell and PowerCLI on xubuntu-wan, extracts base VMs from existing snapshots on dc01, xubuntu, and vyos, builds an Ubuntu Server base VM, and creates linked clones.

## Milestone 4.2 - PowerShell, PowerCLI, and Snapshot Extraction

### Installing Dependencies

1. Install prerequisites for PowerCLI and Ansible on xubuntu-wan:

   ```
   sudo apt install sshpass python3-paramiko git
   sudo apt-add-repository ppa:ansible/ansible
   sudo apt update
   sudo apt install ansible
   ```

2. Configure Ansible to skip host key checking:

   ```
   cat >> ~/.ansible.cfg << EOF
   [defaults]
   host_key_checking = false
   EOF
   ```

3. Install PowerShell via snap:

   ```
   sudo snap install powershell --classic
   ```

   Log out and back in, then verify with `pwsh --version`.

### Installing PowerCLI

4. Launch PowerShell and install VMware PowerCLI:

   ```
   pwsh
   ```

   ```powershell
   Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
   Install-Module VMware.PowerCLI -Scope CurrentUser
   ```

5. Configure PowerCLI settings:

   ```powershell
   Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
   Set-PowerCLIConfiguration -ParticipateInCeip $false -Confirm:$false
   Set-PowerCLIConfiguration -PythonPath /usr/bin/python3 -Confirm:$false
   ```

### Extracting Base VMs from Snapshots

Back in Milestone 2.1, a "Base" snapshot was taken on WinServer19 before it was configured as dc01. The same was done for VyOS and xubuntu-wan. Now with vCenter available, PowerCLI can extract those clean snapshots into standalone base VMs.

6. I wrote `480CloneFromSnap.ps1` to handle this. The script prompts for the source VM, snapshot name, and new VM name. It connects to vCenter, creates a temporary linked clone from the snapshot, promotes it to a full clone, takes a new "Baseline" snapshot, and removes the temp linked clone:

   ```powershell
   $templateName = Read-Host "Which VM do you want to clone"
   $snapName = Read-Host "What snapshot should be used"
   $cloneName = Read-Host "What should the new VM be called"

   $vcHost = "vcenter.dylan.local"
   $vcAdmin = "dylan-adm@dylan.local"
   $vcPassword = "YourPasswordHere"

   Connect-VIServer -Server $vcHost -User $vcAdmin -Password $vcPassword

   $srcVM = Get-VM -Name $templateName -ErrorAction Stop
   $snap = Get-Snapshot -VM $srcVM -Name $snapName -ErrorAction Stop

   $esxiHost = Get-VMHost -Name "192.168.3.227"
   $dataStore = Get-DataStore -Name "datastore2-super27"

   $tempName = "$($srcVM.Name)-templink"
   $tempClone = New-VM -LinkedClone -Name $tempName -VM $srcVM -ReferenceSnapshot $snap -VMHost $esxiHost -Datastore $dataStore

   $finalVM = New-VM -Name $cloneName -VM $tempClone -VMHost $esxiHost -Datastore $dataStore
   $finalVM | New-Snapshot -Name "Baseline"
   $tempClone | Remove-VM -Confirm:$false
   ```

7. Run the script for each VM that needs a base image extracted (WinServer19, xubuntu-wan, 480-fw):

   ```powershell
   ./480CloneFromSnap.ps1
   ```

### Creating Linked Clones

8. I wrote `480LinkedClone.ps1` to create linked clones. It prompts for the source VM, snapshot, and clone name, then creates a linked clone and swaps the network adapter to 480-WAN:

   ```powershell
   $templateName = Read-Host "Which VM do you want to clone"
   $snapName = Read-Host "What snapshot do you want to use"
   $cloneName = Read-Host "What do you want the new VM be called"

   $vcHost = "vcenter.dylan.local"
   $vcAdmin = "dylan-adm@dylan.local"
   $vcPassword = "YourPasswordHere"

   Connect-VIServer -Server $vcHost -User $vcAdmin -Password $vcPassword

   $srcVM = Get-VM -Name $templateName -ErrorAction Stop
   $snap = Get-Snapshot -VM $srcVM -Name $snapName -ErrorAction Stop

   $esxiHost = Get-VMHost -Name "192.168.3.227"
   $dataStore = Get-DataStore -Name "datastore2-super27"

   $linkedClone = New-VM -LinkedClone -Name $cloneName -VM $srcVM -ReferenceSnapshot $snap -VMHost $esxiHost -Datastore $dataStore

   Get-NetworkAdapter -VM $linkedClone | Remove-NetworkAdapter -Confirm:$false
   New-NetworkAdapter -VM $linkedClone -NetworkName "480-WAN" -StartConnected -Type Vmxnet3
   ```

## Milestone 4.3 - Ubuntu Server Base VM

* Upload the Ubuntu Server ISO to the ISOs folder on the ESXi datastore.

* Create a new VM in ESXi with default settings, thin provisioned disk, and the Ubuntu Server ISO attached.

* Boot the VM, go through the Ubuntu Server installer. Set up an admin user and install OpenSSH Server.

* After installation, reboot, remove the ISO, and set CD/DVD back to Host Device. Verify netplan has DHCP enabled.

* Power off the VM and take a snapshot named "Base."

### Creating Linked Clones from All Base VMs

14. Use `480LinkedClone.ps1` to create linked clones from each base VM. Power them on and verify they pick up DHCP addresses on 480-WAN.
