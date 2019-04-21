#
# dhcp_replicate_mac_filters.ps1
#
# Michael Laforest
# Created: 10/20/2018
# Updated: 10/20/2018
#

#
# CHANGE LOG
#
#

Import-Module ActiveDirectory
Import-Module DHCPServer

$_script = "DHCP Replicate MAC Filters"
$_ver    = "0.1"
$_author = "Michael Laforest"

function is_mac_duplicate($arr, $mac) {
	foreach ($m in $arr) {
		if ($m.MacAddress -eq $mac) {
			return 1
		}
	}
	return 0
}

function get_aggregate($servers, $list_type) {
	$list = @()
	$servers     = $servers | add-member -NotePropertyName Connected -NotePropertyValue 0 -passthru
	foreach ($server in $servers) {
		$new = 0
		try {
			$entries = get-DhcpServerv4Filter -computer $server.DnsName | where {$_.List -eq $list_type}
			$server.connected = 1
			foreach ($e in $entries) {
				#$dup = 
				if ((is_mac_duplicate $list $e.MacAddress) -eq 0) {
					$list += $e
					$new++
				}
			}
			write-host "[INFO] $($server.DnsName), $list_type $($entries.length), new $new"
		} catch {
			write-host "[ERR ] Failed to connect to $($server.DnsName)"
			continue
		}
	}
	return $servers, $list
}

function apply_list($servers, $list_type, $list) {
	# Apply only to servers we could connect to.
	# This will prevent losing entries if the server was not available when we scraped
	# the list but is available now.
	$cservers = $servers | where {$_.Connected -eq 1}
	foreach ($server in $cservers) {
		foreach ($entry in $list) {
			Add-DhcpServerv4Filter -computer $server.DnsName -List $list_type -MacAddress "$($entry.MacAddress)" -Description "$($entry.Description)" -erroraction silentlycontinue
		}
		write-host "[INFO] $($server.DnsName) updated $list_type"
	}
}

function main() {
	############################
	# START ENVIRON VARS
	# 
	#
	# END ENVIRON VARS
	############################
	$start       = date
	$deny_list   = @()
	
	$servers             = get-dhcpserverindc
	$servers, $deny_list = get_aggregate $servers "Deny"
	
	write-host "[INFO] Total DENY $($deny_list.length)"
	
	apply_list $servers "Deny" $deny_list
	
	$elapsed     = "{0}" -f ((date) - $start)
}

main
