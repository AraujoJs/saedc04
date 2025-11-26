$proxmoxHost = "10.1.15.75:8006"
$proxmoxUser = "root@pam"
$proxmoxPassword = "Tatadc26"

$SecurePassword = ConvertTo-SecureString $proxmoxPassword -AsPlainText -Force

$Credential = New-Object System.Management.Automation.PSCredential($proxmoxUser, $SecurePassword)

Connect-PveCluster -HostsAndPorts $proxmoxHost -Credential $Credential -SkipCertificateCheck

$vmidSource = 110
$vmidClone = 150
$node = "pve15-1"
$cloneName = "pc-clone"

New-PveNodesQemuClone -Name $cloneName -Node $node -full $false -Vmid $vmidSource -Newid $vmidClone

do {
    $lockStatus = (Get-PveNodesQemuStatusCurrent -vmid $vmidClone -node $node).Response.data.lock
    Write-Host "Attente..."
    Start-Sleep -Seconds 5
} while ($lockStatus -ne $null)

Write-Host "Clonage OK"

$nouveauMotDePasse = ConvertTo-SecureString "Tatadc26" -AsPlainText -Force
New-PveNodesQemuConfig -Node $node -vmid $vmidClone -Cipassword $nouveauMotDePasse

$Iplist=@{} 
$Iplist[0] = "ip=10.98.30.22/24,gw=10.98.30.254"

Set-PveNodesQemuConfig -Node $node -vmid $vmidClone -IpConfigN $Iplist
Start-PveVM -vmid $vmidClone

Write-Host "Config OK"
