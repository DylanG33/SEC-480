# Milestone 5 - 480-utils Module

Built out a reusable PowerShell module `480Utils.psm1` that handles vCenter connections and VM cloning. 

---

## Setting Up VS Code and Git on xubuntu-wan

- Installed VS Code on xubuntu-wan and added the PowerShell extension
- Ran `sudo apt update` then `sudo apt install git` to confirm git was installed 
- Configured global git identity:

```powershell
git config --global user.name "DylanG33"
git config --global user.email "dylan.george@mymail.champlain.edu"
```

- Cloned the SEC-480 repo into home directory:

```bash
git clone https://github.com/DylanG33/SEC-480.git
cd ./SEC-480/
```

<img src="https://github.com/user-attachments/assets/a1d37b76-eebd-4d4a-bd9b-f6a9d04c227f" />

---

## Building the Module Skeleton

- Created the `modules/480-utils/` folder structure inside the repo
- Made two files: `480-utils.psd1` and `480-utils.psm1`
- Started with a basic `480banner` function as a sanity check:

```powershell
function 480banner() {
    Write-Host "Wassup its DG"
}
```

<img src="https://github.com/user-attachments/assets/97f29140-d2c5-4748-a712-8cc2b3677810" />

---

## PowerShell Profile for Auto-Import

- Opened PowerShell and checked the profile path with `$profile`
- Edited `Microsoft.PowerShell_profile.ps1` to add the modules folder to `$env:PSModulePath`:

```powershell
$env:PsModulePath = $env:PsModulePath + ":/home/dylan-george/SEC-480/modules"
```

- Reloaded PowerShell and verified the path was set by running `$env:PsModulePath`

<img src="https://github.com/user-attachments/assets/343a847c-51ad-4353-aeae-04041cbdc26d" />

- Force-imported the module and tested the banner function:

```powershell
Import-Module "/home/dylan-george/SEC-480/modules/480-utils" -Force
480banner
```

Output: `Wassup its DG` 

<img src="https://github.com/user-attachments/assets/93d081e7-fd30-4ed7-b6aa-71793b7669b5" />

---

## Writing the 480Utils Functions

All functions live in `480Utils.psm1`. Here's what each one does:

### `Connect-480VCenter`
- Connects to vCenter at `vcenter.dylan.local` using `dylan-adm@dylan.local`
- Wrapped in a try/catch — prints green on success, red error message on failure
- Uses `Connect-VIServer` under the hood

```powershell
Connect-480VCenter
```

### `Get-480VM`
- Takes a VM name and snapshot name as params
- Looks up the VM with `Get-VM`, then finds the snapshot with `Get-Snapshot`
- Returns `$null` with a red error message if either isn't found
- Used by the clone functions to validate before doing anything

### `New-480LinkedClone`
- Prompts for any missing params interactively with `Read-Host`
- Validates the VM, snapshot, ESXi host, and datastore all exist before proceeding
- Checks if a VM with that name already exists
- Calls `New-VM -LinkedClone` to create the clone from the Base snapshot
- Swaps the network adapter to `480-WAN` 

### `New-480FullClone`
- Same input validation flow as linked clone
- Full clone process:
  1. Creates a temp linked clone from the Base snapshot
  2. Clones the temp linked clone into a full independent VM
  3. Takes a new "Base" snapshot on the final VM
  4. Deletes the temp linked clone with `Remove-VM -Confirm:$false`
- Full clone is storage-independent — no dependency on the original VM's disks

> A full clone needs to go through a linked clone first because `New-VM` without `-LinkedClone` clones from the current state, not a snapshot. The temp linked clone locks to the Base snapshot, then the full clone is made from that.

---

## Pushing to GitHub

- Staged and committed from the `modules/480-utils` directory:

```bash
git add .
git commit -m "Milestone 5 tings from dylan"
git push
```

- Confirmed push was successful: `main -> main`

<img src="https://github.com/user-attachments/assets/4f2bf7f0-0172-46eb-b401-5d6263cab309" />
