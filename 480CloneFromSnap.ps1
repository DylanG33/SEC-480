# Params
$templateName = Read-Host "Which VM do you want to clone"
$snapName = Read-Host "What snapshot should be used"
$cloneName = Read-Host "What should the new VM be called"

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

# temp linked clone 
$tempName = "$($srcVM.Name)-templink"

$tempClone = New-VM -LinkedClone -Name $tempName -VM $srcVM -ReferenceSnapshot $snap -VMHost $esxiHost -Datastore $dataStore

# promote it
$finalVM = New-VM -Name $cloneName -VM $tempClone -VMHost $esxiHost -Datastore $dataStore

# snapshot again
$finalVM | New-Snapshot -Name "Baseline"

$tempClone | Remove-VM -Confirm:$false

Write-Host "Full clone '$cloneName' is ready" -ForegroundColor Green
