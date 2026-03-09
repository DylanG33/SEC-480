function 480banner()
{
    Write-Host "Wassup its DG"
}

function 480Connect([string] $server)
{
    $conn = $global:DefaultVIServer
    #checking if we are already connected
    if ($conn){
        $msg = "Already connected to: {0}" -f $conn

        Write-Host -ForegroundColor Blue $msg
    }else {
        $conn = Connect-VIServer -Server $server
        #if check fails, Connect-VIServer handles exception
    }
}

function Get-480VM {
    <#
    .SYNOPSIS
    Looks up a VM and its snapshot with error handling
    #>
    param(
        [string]$VMName,
        [string]$SnapshotName
    )

    # Find the VM
    $vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Host "'$VMName' was not found" -ForegroundColor Red
        return $null
    }

    # Find the snapshot
    $snap = Get-Snapshot -VM $vm -Name $SnapshotName -ErrorAction SilentlyContinue
    if (-not $snap) {
        Write-Host "ERROR: Snapshot '$SnapshotName' was not found on VM '$VMName'" -ForegroundColor Red
        return $null
    }

    return @{
        VM = $vm
        Snapshot = $snap
    }
}

function New-480FullClone {
    <#
    .SYNOPSIS
    Creates a full independent clone by making a temp linked clone first, then promoting it
    #>
    param(
        [string]$VMName,
        [string]$SnapshotName = "Base",
        [string]$CloneName,
        [string]$ESXiHost,
        [string]$DataStoreName
    )

    if (-not $VMName) {
        $VMName = Read-Host "Which VM do you want to clone"
    }
    if (-not $CloneName) {
        $CloneName = Read-Host "What should the new VM be called"
    }
    if (-not $ESXiHost) {
        $ESXiHost = Read-Host "Enter your ESXi host IP"
    }
    if (-not $DataStoreName) {
        $DataStoreName = Read-Host "Enter your datastore name"
    }

    # snapshot
    $result = Get-480VM -VMName $VMName -SnapshotName $SnapshotName
    if (-not $result) { return }

    # host and datastore
    $vmhost = Get-VMHost -Name $ESXiHost -ErrorAction SilentlyContinue
    if (-not $vmhost) {
        Write-Host "ESXi host '$ESXiHost' was not found" -ForegroundColor Red
        return
    }

    $ds = Get-DataStore -Name $DataStoreName -ErrorAction SilentlyContinue
    if (-not $ds) {
        Write-Host "Datastore '$DataStoreName' was not found" -ForegroundColor Red
        return
    }

    # Check if name is already taken
    $existing = Get-VM -Name $CloneName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "A VM named '$CloneName' already exists" -ForegroundColor Red
        return
    }

    # Temp linked clone name
    $tempName = "$($result.VM.Name)-templink"

    # temp linked clone
    $tempClone = New-VM -LinkedClone -Name $tempName -VM $result.VM -ReferenceSnapshot $result.Snapshot -VMHost $vmhost -Datastore $ds -ErrorAction SilentlyContinue

    if (-not $tempClone) {
        Write-Host "Failed to create linked clone" -ForegroundColor Red
        return
    }

    # promote
    $finalVM = New-VM -Name $CloneName -VM $tempClone -VMHost $vmhost -Datastore $ds -ErrorAction SilentlyContinue

    if (-not $finalVM) {
        Write-Host "Failed to promote to full clone" -ForegroundColor Red
        return
    }

    $finalVM | New-Snapshot -Name "Base"

    $tempClone | Remove-VM -Confirm:$false

    Write-Host "Full clone '$CloneName' is ready." -ForegroundColor Green
    return $finalVM
}

function New-480LinkedClone {
    <#
    .SYNOPSIS
    Creates a linked clone from a VM snapshot and
    sets the network adapter to the specified port group.
    #>
    param(
        [string]$VMName,
        [string]$SnapshotName = "Base",
        [string]$CloneName,
        [string]$ESXiHost,
        [string]$DataStoreName,
        [string]$NetworkName = "480-WAN"
    )

    if (-not $VMName) {
        $VMName = Read-Host "Which VM do you want to clone"
    }
    if (-not $CloneName) {
        $CloneName = Read-Host "What should the new VM be called"
    }
    if (-not $ESXiHost) {
        $ESXiHost = Read-Host "Enter your ESXi host IP"
    }
    if (-not $DataStoreName) {
        $DataStoreName = Read-Host "Enter your datastore name"
    }

    # snapshot
    $result = Get-480VM -VMName $VMName -SnapshotName $SnapshotName
    if (-not $result) { return }

    # host and datastore
    $vmhost = Get-VMHost -Name $ESXiHost -ErrorAction SilentlyContinue
    if (-not $vmhost) {
        Write-Host "ESXi host '$ESXiHost' was not found" -ForegroundColor Red
        return
    }

    $ds = Get-DataStore -Name $DataStoreName -ErrorAction SilentlyContinue
    if (-not $ds) {
        Write-Host "Datastore '$DataStoreName' was not found" -ForegroundColor Red
        return
    }

    # Check if name is already taken
    $existing = Get-VM -Name $CloneName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "A VM named '$CloneName' already exists" -ForegroundColor Red
        return
    }

    # Create the linked clone
    $linkedClone = New-VM -LinkedClone -Name $CloneName -VM $result.VM -ReferenceSnapshot $result.Snapshot -VMHost $vmhost -Datastore $ds -ErrorAction SilentlyContinue

    if (-not $linkedClone) {
        Write-Host "Failed to create linked clone" -ForegroundColor Red
        return
    }

    # Swap the network adapter
    Get-NetworkAdapter -VM $linkedClone | Remove-NetworkAdapter -Confirm:$false
    New-NetworkAdapter -VM $linkedClone -NetworkName $NetworkName -StartConnected -Type Vmxnet3

    Write-Host "Linked clone '$CloneName' is ready on $NetworkName." -ForegroundColor Green
    return $linkedClone
}
