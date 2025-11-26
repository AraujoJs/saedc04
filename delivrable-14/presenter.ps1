[xml]$XML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="MainWindow" x:Name="Window" Height="450" Width="800">
    
    <Grid HorizontalAlignment="Left" Width="800">
      <Menu>
        <MenuItem Header="Main">
          <MenuItem x:Name="MenuConnect" Header="Connect" InputGestureText="CTRL+L" />
          <MenuItem x:Name="MenuExit" Header="Exit" InputGestureText="CTRL+X" />
        </MenuItem>
        
         <MenuItem Header="Operations">
          <MenuItem x:Name="MenuStart" Header="Start" InputGestureText="CTRL+S" />
          <MenuItem x:Name="MenuStop" Header="Stop" InputGestureText="CTRL+F" />
          <MenuItem x:Name="MenuClone" Header="Clone" InputGestureText="CTRL+C" />
        </MenuItem>
        
        <MenuItem Header="Reports">
          <MenuItem x:Name="MenuStorage" Header="Storage" InputGestureText="CTRL+R+S" />
          <MenuItem x:Name="MenuReport" Header="Report" InputGestureText="CTRL+R" />
        </MenuItem>
        
        <MenuItem Header="About">
          <MenuItem x:Name="MenuHelp" Header="Help" InputGestureText="CTRL+H" />
          <MenuItem x:Name="MenuAbout" Header="About" InputGestureText="CTRL+A" />
        </MenuItem>
      </Menu>
    </Grid>

</Window>
"@



$proxmoxHost = "10.1.15.75:8006"
$proxmoxUser = "root@pam"
$proxmoxPassword = "Tatadc26"

$SecurePassword = ConvertTo-SecureString $proxmoxPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($proxmoxUser, $SecurePassword)

$TicketObj = Connect-PveCluster -HostsAndPorts $proxmoxHost -Credentials $Credential -SkipCertificateCheck

function pveGUI {
    $FormXML = (New-Object System.Xml.XmlNodeReader $XML)
    $Window = [Windows.Markup.XamlReader]::Load($FormXML)

    $Window.ShowDialog() | Out-Null
}


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


pveGUI


