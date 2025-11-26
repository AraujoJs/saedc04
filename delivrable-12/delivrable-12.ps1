
$proxmoxHost = "10.1.15.75:8006"
$proxmoxUser = "root@pam"
$proxmoxPassword = "Tatadc26"

$SecurePassword = ConvertTo-SecureString $proxmoxPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($proxmoxUser, $SecurePassword)

Connect-PveCluster -HostsAndPorts $proxmoxHost -Credential $Credential -SkipCertificateCheck

$vmidSource = 110
$node = "pve15-1"
$currentId = 160

$csv = Import-Csv "machines.csv"

foreach ($line in $csv) {
    $vmidClone = $currentId
    $cloneName = $line.Nom
    $cloneDesc = $line.Poste
    $clonePasswd

    New-PveNodesQemuClone -Name $cloneName -Node $node -full $false -Vmid $vmidSource -Newid $vmidClone -Description $cloneDesc

    do {
        $lockStatus = (Get-PveNodesQemuStatusCurrent -vmid $vmidClone -node $node).Response.data.lock
        Start-Sleep -Seconds 3
    } while ($lockStatus -ne $null)
    $pwd = ConvertTo-SecureString $line.motdepasse -AsPlainText -Force
    New-PveNodesQemuConfig -Node $node -vmid $vmidClone -Cipassword $pwd

    $Iplist=@{}
    $Iplist[0] = "ip=$($line.IP)/24,gw=10.98.10.254"

    $NetConfig=@{}
    $NetConfig[0] = "virtio,bridge=vmbr2,tag=10"

    Set-PveNodesQemuConfig -Node $node -vmid $vmidClone -IpConfigN $Iplist -NetN $NetConfig

    $currentId++
}
