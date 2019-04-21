#
# dhcp_backup.ps1
#
# Michael Laforest
# Created: 5/15/2018
# Updated: 5/15/2018
#

Import-Module ActiveDirectory
Import-Module DHCPServer

$backup_path = "\\server\BACKUPS\DHCP"
$domain = ".company.com"

function main() {
	$servers = get-dhcpserverindc
	$i = 0
	$today = get-date -format 'yyyy-MM-dd'
	
	$servers | %{
		$s = $_.DNSName.replace($domain, '')
		Write-Progress -Activity "Backing up DHCP Server" -status "Processing server $i/$($servers.Length) [$s]" -percentComplete (($i++ / $servers.Length)*100)
		$f = "$($backup_path)\$($s)-$($today).xml"
		export-dhcpserver -computer $_.DNSName -file $f -leases -force
	}
	Write-Progress -id 1 -Completed -Activity "Backing up DHCP Server" -percentComplete 1 -status "adsf"
}

main
