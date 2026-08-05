#===========================================================
# AZURE VM WITH 2 NICs FOR DOCKER MACVLAN DEMO
# Region : Central US
#===========================================================

# Variables
$RG="RG-MACVLAN"
$LOCATION="centralus"

$VNET="vnet-macvlan"
$SUBNET="subnet1"

$NSG="nsg-macvlan"

$PIP="pip-macvlan"

$NIC1="nic-management"
$NIC2="nic-container"

$VM="vm-macvlan"

$USERNAME="azureuser"
$PASSWORD="Azure@123456789"

#-----------------------------------------------------------
# Create Resource Group
#-----------------------------------------------------------

az group create `
-g $RG `
-l $LOCATION

#-----------------------------------------------------------
# Create Virtual Network
#-----------------------------------------------------------

az network vnet create `
-g $RG `
-n $VNET `
--address-prefixes 10.0.0.0/16 `
--subnet-name $SUBNET `
--subnet-prefixes 10.0.0.0/24

#-----------------------------------------------------------
# Create NSG
#-----------------------------------------------------------

az network nsg create `
-g $RG `
-n $NSG

#-----------------------------------------------------------
# Allow SSH
#-----------------------------------------------------------

az network nsg rule create `
-g $RG `
--nsg-name $NSG `
-n AllowSSH `
--priority 100 `
--direction Inbound `
--access Allow `
--protocol Tcp `
--destination-port-ranges 22

#-----------------------------------------------------------
# Public IP
#-----------------------------------------------------------

az network public-ip create `
-g $RG `
-n $PIP `
--sku Standard

#-----------------------------------------------------------
# Management NIC (Primary / eth0)
#-----------------------------------------------------------

az network nic create `
-g $RG `
-n $NIC1 `
--vnet-name $VNET `
--subnet $SUBNET `
--network-security-group $NSG `
--public-ip-address $PIP

#-----------------------------------------------------------
# Container NIC (Secondary / eth1)
#-----------------------------------------------------------

az network nic create `
-g $RG `
-n $NIC2 `
--vnet-name $VNET `
--subnet $SUBNET

#-----------------------------------------------------------
# Create Ubuntu 24.04 VM
#-----------------------------------------------------------

az vm create `
-g $RG `
-n $VM `
--image Ubuntu2404 `
--size Standard_B2s `
--admin-username $USERNAME `
--admin-password $PASSWORD `
--authentication-type password `
--nics $NIC1 $NIC2

#-----------------------------------------------------------
# Show Public IP
#-----------------------------------------------------------

Write-Host ""
Write-Host "==============================="
Write-Host "PUBLIC IP"
Write-Host "==============================="

az vm show `
-g $RG `
-n $VM `
-d `
--query publicIps `
-o tsv

Write-Host ""
Write-Host "SSH Command"
Write-Host "ssh $USERNAME@<Public-IP>"

Write-Host ""
Write-Host "Inside Linux verify:"
Write-Host "ip -br addr"

Write-Host ""
Write-Host "Expected:"
Write-Host "eth0 = Management NIC"
Write-Host "eth1 = Docker Macvlan NIC"