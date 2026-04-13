# 480LinkedClone.ps1
# Creates a linked clone from a VM snapshot and swaps the network adapter to the right port group

# Params
$templateName = Read-Host "Which VM do you want to clone"
$snapName = Read-Host "What snapshot do you want to use"
$cloneName = Read-Host "What do you wantthe new VM be called"

# vCenter connection info
$vcHost = "vcenter.dylan.local"
$vcAdmin = "dylan-adm@dylan.local"
$vcPassword = "Towerhill0!"

Connect-VIServer -Server $vcHost -User $vcAdmin -Password $vcPassword

# source VM
$srcVM = Get-VM -Name $templateName -ErrorAction Stop
if (-not $srcVM) {
    Write-Host "Could not find VM '$templateName'" -ForegroundColor Red
    exit
}

# snapshot
$snap = Get-Snapshot -VM $srcVM -Name $snapName -ErrorAction Stop
if (-not $snap) {
    Write-Host "Could not find snapshot '$snapName' on VM '$templateName'" -ForegroundColor Red
    exit
}

# host and datastore
$esxiHost = Get-VMHost -Name "192.168.3.227"
$dataStore = Get-DataStore -Name "datastore2-super27"

# linked clone
$linkedClone = New-VM -LinkedClone -Name $cloneName -VM $srcVM -ReferenceSnapshot $snap -VMHost $esxiHost -Datastore $dataStore

if (-not $linkedClone) {
    Write-Host "Failed to create linked clone" -ForegroundColor Red
    exit
}

# Swap the network adapter to 480-WAN
Get-NetworkAdapter -VM $linkedClone | Remove-NetworkAdapter -Confirm:$false
New-NetworkAdapter -VM $linkedClone -NetworkName "480-WAN" -StartConnected -Type Vmxnet3

Write-Host "Linked clone '$cloneName' is ready on 480-WAN" -ForegroundColor Green
