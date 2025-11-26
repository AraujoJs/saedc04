$proxmoxHost = "10.1.15.75:8006"
$proxmoxUser = "root@pam"
$proxmoxPassword = "Tatadc26"

$SecurePassword = ConvertTo-SecureString $proxmoxPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($proxmoxUser, $SecurePassword)

$TicketObj = Connect-PveCluster -HostsAndPorts $proxmoxHost -Credentials $Credential -SkipCertificateCheck

function pveClone {
    param (
        [int]$vmidSource,
        [int]$vmidClone,
        [string]$cloneName,
        [string]$cloneDesc,
        [string]$password,
        [string]$ip,
        [int]$mask,
        [string]$gateway,
        [int]$vlan = $null
    )

    New-PveNodesQemuClone -Name $cloneName -Description $cloneDesc -Node pve15-1 -full $false -Vmid $vmidSource -Newid $vmidClone

    do {
        $lockStatus = (Get-PveNodesQemuStatusCurrent -vmid $vmidClone -Node pve15-1).Response.data.lock
        Start-Sleep -Seconds 3
    } while ($lockStatus -ne $null)

    $pwd = ConvertTo-SecureString $password -AsPlainText -Force
    New-PveNodesQemuConfig -Node pve15-1 -vmid $vmidClone -Cipassword $pwd

    $Iplist = @{0 = "ip=$ip/$mask,gw=$gateway"}

    if ($vlan -in 10,20,30,40) {
        $bridge = "vmbr2"
        $tag = $vlan
        $NetConfig = @{0 = "virtio,bridge=$bridge,tag=$tag"}
        Write-Host "VLAN $vlan found, network attached to $bridge - $tag"
    }
    else {
        $bridge = "vmbr0"
        $NetConfig = @{0 = "virtio,bridge=$bridge"}
        Write-Host "No valid VLAN, network attached to $bridge - /"
    }

    Set-PveNodesQemuConfig -Node pve15-1 -vmid $vmidClone -IpConfigN $Iplist -NetN $NetConfig

    Write-Host "VM $cloneName cloned with IP $ip/$mask and gateway $gateway"
}

function pveReport {
    $nodes = Get-PveNodes
    $clusterStatusAll = Get-PveClusterStatus

    foreach ($node in $nodes.Response.data) {
        $nodeName = $node.node
        Write-Host "-- Node: $nodeName"
        Write-Host "--------"

        $clusterNode = $clusterStatusAll.Response.data | Where-Object { $_.name -eq $nodeName }
        $clusterStatus = if ($clusterNode) { $clusterNode.status } else { "unknown" }
        Write-Host "-- Cluster Status: $clusterStatus"

        $storageObjs = Get-PveNodesStorage -Node $nodeName
        foreach ($storage in $storageObjs.Response.data) {
            $avail = $storage.total - $storage.used
            Write-Host ("Storage {0}: total={1}, used={2}, avail={3}" -f $storage.storage, $storage.total, $storage.used, $avail)
        }

        $vms = Get-PveNodesQemu -Node $nodeName
        if ($vms.Response.data.Count -eq 0) {
            Write-Host "No VMs on this nod"
        } else {
            Write-Host ("------ REPORT ------")
            foreach ($vm in $vms.Response.data) {
                Write-Host ("VMID: {0, -5} | Name: {1, -25} | Status: {2, -1}" -f $vm.vmid, $vm.name, $vm.status)
            }
        }

        Write-Host ""
    }
}

function pveStart {
    param ([int]$vmid)
    Start-PveVM -Vmid $vmid
}

function pveStop {
    param ([int]$vmid)
    Stop-PveVM -Vmid $vmid
}

do {
    Write-Host "-=-=-=- MENU -=-=-=-"
    Write-Host "1) -- Clone VM"
    Write-Host "2) -- Start VM"
    Write-Host "3) -- Stop VM"
    Write-Host "4) -- Generate Report"
    Write-Host "5) - Exit"
    $choice = Read-Host "Choose an option"

    switch ($choice) {
        1 {
            $vmidSource = [int](Read-Host "Enter source VMID")
            $vmidClone = [int](Read-Host "Enter new VMID")
            $cloneName = Read-Host "Enter new VM name"
            $cloneDesc = Read-Host "Enter VM description"
            $password = Read-Host "Enter VM password"
            $ip = Read-Host "Enter VM IP address (ex 10.98.10.50)"
            $mask = [int](Read-Host "Enter subnet mask (ex 24)")
            $gateway = Read-Host "Enter gateway (ex 10.98.10.254)"
            
            $vlanInput = Read-Host "Enter VLAN (10,20,30,40) or leave empty"
            if ([string]::IsNullOrWhiteSpace($vlanInput)) {
                $vlan = $null
            }
            else {
                $vlan = [int]$vlanInput
            }

            pveClone -vmidSource $vmidSource -vmidClone $vmidClone -cloneName $cloneName `
                     -cloneDesc $cloneDesc -password $password -ip $ip -mask $mask -gateway $gateway -vlan $vlan
        }
        2 {
            $vmid = [int](Read-Host "Enter VMID to start")
            pveStart -vmid $vmid
        }
        3 {
            $vmid = [int](Read-Host "Enter VMID to stop")
            pveStop -vmid $vmid
        }
        4 {
            pveReport
        }
        5 { exit }
        default { Write-Host "Invalid choice" }
    }
} while ($true)