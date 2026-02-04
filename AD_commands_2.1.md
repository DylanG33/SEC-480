```
Install-ADDSForest -DomainName "dylan.local" -DomainNetbiosName "DYLAN" -InstallDns -Force
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 10.0.17.4
Add-DnsServerResourceRecordA -Name "vcenter" -ZoneName "dylan.local" -IPv4Address 10.0.17.3
Add-DnsServerResourceRecordA -Name "480-fw" -ZoneName "dylan.local" -IPv4Address 10.0.17.2
Add-DnsServerResourceRecordA -Name "xubuntu-wan" -ZoneName "dylan.local" -IPv4Address 10.0.17.100
Add-DnsServerPrimaryZone -NetworkID "10.0.17.0/24" -ReplicationScope "Forest"
Add-DnsServerResourceRecordPtr -Name "3" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "vcenter.dylan.local"
Add-DnsServerResourceRecordPtr -Name "2" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "480-fw.dylan.local"
Add-DnsServerResourceRecordPtr -Name "100" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "xubuntu-wan.dylan.local"
Add-DnsServerResourceRecordPtr -Name "4" -ZoneName "17.0.10.in-addr.arpa" -PtrDomainName "dc01.dylan.local"
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Install-WindowsFeature -Name DHCP -IncludeManagementTools
Add-DhcpServerInDC -DnsName "dc01.dylan.local" -IPAddress 10.0.17.4
Add-DhcpServerv4Scope -Name "480-WAN-Scope" -StartRange 10.0.17.101 -EndRange 10.0.17.150 -SubnetMask 255.255.255.0 -State Active
Set-DhcpServerv4OptionValue -ScopeId 10.0.17.0 -Router 10.0.17.2
Set-DhcpServerv4OptionValue -ScopeId 10.0.17.0 -DnsServer 10.0.17.4
New-ADUser -Name "dylan-adm" -SamAccountName "dylan-adm" -UserPrincipalName "dylan-adm@dylan.local" -AccountPassword (ConvertTo-SecureString "********" -AsPlainText -Force) -Enabled $true -PasswordNeverExpires $true
Add-ADGroupMember -Identity "Domain Admins" -Members "dylan-adm"
```
