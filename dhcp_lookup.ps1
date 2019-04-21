#
# Locate a DHCP lease record from all DHCP servers in the domain.
# 
# Example
#   > import-module dhcp_lookup.ps1
# 	> get-dhcpleaseinfo 10.24.191.60
#
#	lease_host    : kiosk5.company.com
#	scope_id      : 10.24.191.0
#	lease_ip      : 10.24.191.60
#	server        : dhcpserver4
#	lease_mac     : 54-ee-75-8f-ea-12
#	lease_expires : 4/27/2019 7:44:46 AM
#
# Michael Laforest
# Created: 01/24/2019
# Updated: 04/21/2019
#

param(
	[Parameter(Mandatory=$true)]
	[string]$identity
)

# from https://stackoverflow.com/questions/8365537/checking-for-a-range-in-powershell
function IsIpAddressInRange {
	param(
        [string] $ipAddress,
        [string] $fromAddress,
        [string] $toAddress
    )
    $ip = [system.net.ipaddress]::Parse($ipAddress).GetAddressBytes()
    [array]::Reverse($ip)
    $ip = [system.BitConverter]::ToUInt32($ip, 0)
    $from = [system.net.ipaddress]::Parse($fromAddress).GetAddressBytes()
    [array]::Reverse($from)
    $from = [system.BitConverter]::ToUInt32($from, 0)
    $to = [system.net.ipaddress]::Parse($toAddress).GetAddressBytes()
    [array]::Reverse($to)
    $to = [system.BitConverter]::ToUInt32($to, 0)
    $from -le $ip -and $ip -le $to
}


function find_good_server($ip) {
	# first try the server with the first and second octets
	$all_servers = get-dhcpserverindc
	$iparr = $ip.split('.')

	$try_server = $null
	foreach ($server in $all_servers) {
		$server_iparr = $server.ipaddress.ipaddresstostring.split('.')
		if ($iparr[0] -eq $server_iparr[0] -and $iparr[1] -eq $server_iparr[1]) {
			$try_server = $server
			break
		}
	}
	
	if ($try_server -ne $null) {	
		$scope = find_scope $ip $try_server
		if ($scope -ne $null) {
			return $try_server.dnsname,$scope
		}
	}

	# failed on first attempt.  iterate servers
	$i = 0;
	$found_server = $null;
	$found_scope  = $null;
	foreach ($server in $all_servers) {
		Write-Progress -id 1 -Activity "Checking DHCP server" -status "$($i+1)/$($all_servers.Length) - $($server.dnsname.split('.')[0])" -percentComplete $(($i++ / $all_servers.Length)*100)
		if ($server.dnsname -eq $try_server.dnsname) {
			continue
		}
		$scope = find_scope $ip $server
		if ($scope -ne $null) {
			$found_server = $server.dnsname;
			$found_scope  = $scope;
			break;
		}
	}
	
	Write-Progress -id 1 -completed -Activity "Checking DHCP server" -status "asdf" -percentComplete 100
	if ($found_server -eq $null) {
		write-error "Could not find DHCP server with correct scope"
	}
	return $found_server,$found_scope
}

function find_scope($ip, $server) {
	if ($server -eq $null) {
		return $null
	}
	
	$scope_id = $null
	$i = 0
		
	$scopes = get-dhcpserverv4scope -computer $server.dnsname
	if ($scopes.Length -eq $null) {
		return $null
	}
	foreach ($scope in $scopes) {
		Write-Progress -id 2 -parentid 1 -Activity "Checking scope" -status "$($scope.scopeid)" -percentComplete $(($i++ / $scopes.Length)*100)
		if (IsIpAddressInRange $ip $scope.StartRange $scope.EndRange) {
			$scope_id = $scope.scopeid;
			break
		}
	}

	Write-Progress -id 2 -completed -Activity "Checking scope" -status "asdf" -percentComplete 100
	return $scope_id
}

function find_lease($ip, $server, $scope_id) {
	$leases = get-dhcpserverv4lease -computer $server -scopeid $scope_id
	$lease = $leases | where {$_.ipaddress -eq $ip}
	return $lease
}


function get-dhcpleaseinfo([string]$ip) {
	<#
	.SYNOPSIS
	Get info about a IPv4 DHCP lease.

	.PARAMETER Identity
	The IP address to query.
	
	.DESCRIPTION
	Iterate over all DHCP servers in the domain and return the lease record that matches the IP specified.
	
	.EXAMPLE
	get-DHCPLeaseInfo 10.24.191.60
	#>

	$server,$scope_id = find_good_server $ip
	if ($server -eq $null) {
		write-error "Unable to locate correct scope on any DHCP server for IP $ip"
		return $null
	}
	
	$lease = find_lease $ip $server $scope_id
	if ($lease -eq $null) {
		write-error "Unable to locate lease on DHCP server with correct scope"
		return $null
	}

	$ret = @{
		server		  = $($server.split('.')[0]);
		scope_id	  = $scope_id;
		lease_ip	  = $($lease.ipaddress);
		lease_mac	  = $($lease.clientid);
		lease_expires = $($lease.leaseexpirytime);
		lease_host	  = $($lease.hostname);
	}

	return new-object -typename psobject -property $ret
}
