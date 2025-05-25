# Azure Ubuntu VM Creation Script
# This script creates an Ubuntu VM with 2 CPU cores, 4GB RAM, and 40GB storage
# Generic script that works across different Azure subscriptions and organizations

# Check if Azure PowerShell module is installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Write-Host "Azure PowerShell module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
}

# Import the Azure PowerShell module
Import-Module Az

# Connect to Azure account (this will prompt for login)
Write-Host "Connecting to Azure account..." -ForegroundColor Green
Connect-AzAccount

# Get available subscriptions and let user choose
$subscriptions = Get-AzSubscription
if ($subscriptions.Count -gt 1) {
    Write-Host "Available subscriptions:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "$($i + 1). $($subscriptions[$i].Name) ($($subscriptions[$i].Id))"
    }
    $choice = Read-Host "Select subscription number (1-$($subscriptions.Count))"
    $selectedSubscription = $subscriptions[$choice - 1]
    Set-AzContext -SubscriptionId $selectedSubscription.Id
} else {
    # Use the single available subscription
    Set-AzContext -SubscriptionId $subscriptions[0].Id
}

# Prompt user for basic configuration parameters
$resourceGroupName = Read-Host "Enter Resource Group name (will be created if doesn't exist)"
$location = Read-Host "Enter Azure region (e.g., East US, West Europe, Southeast Asia)"
$vmName = Read-Host "Enter VM name"
$adminUsername = Read-Host "Enter admin username for the VM"

# Prompt for admin password with secure input
$adminPassword = Read-Host "Enter admin password" -AsSecureString

# Define VM specifications (matching requirements: 2 cores, 4GB RAM)
$vmSize = "Standard_B2s"  # 2 vCPUs, 4GB RAM - cost-effective burstable VM size

# Define storage specifications (40GB OS disk)
$osDiskSizeGB = 40

# Define network configuration names (will be auto-generated based on VM name)
$vnetName = "$vmName-vnet"
$subnetName = "$vmName-subnet" 
$nsgName = "$vmName-nsg"
$publicIpName = "$vmName-pip"
$nicName = "$vmName-nic"

Write-Host "Creating Ubuntu VM with the following specifications:" -ForegroundColor Green
Write-Host "- VM Size: $vmSize (2 vCPUs, 4GB RAM)" -ForegroundColor White
Write-Host "- OS Disk: $osDiskSizeGB GB" -ForegroundColor White
Write-Host "- Location: $location" -ForegroundColor White
Write-Host "- Resource Group: $resourceGroupName" -ForegroundColor White

# Create or get existing resource group
Write-Host "Creating/verifying resource group..." -ForegroundColor Yellow
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    # Create new resource group if it doesn't exist
    $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
    Write-Host "Created new resource group: $resourceGroupName" -ForegroundColor Green
} else {
    Write-Host "Using existing resource group: $resourceGroupName" -ForegroundColor Green
}

# Create virtual network with a subnet
Write-Host "Creating virtual network and subnet..." -ForegroundColor Yellow
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix "10.0.1.0/24"  # Define subnet IP range

$vnet = New-AzVirtualNetwork `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $vnetName `
    -AddressPrefix "10.0.0.0/16" `  # Define virtual network IP range
    -Subnet $subnetConfig

# Create Network Security Group with basic rules
Write-Host "Creating Network Security Group with SSH access..." -ForegroundColor Yellow
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "SSH" `
    -Description "Allow SSH access" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1001 `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 22

$nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -Name $nsgName `
    -SecurityRules $nsgRuleSSH

# Create public IP address
Write-Host "Creating public IP address..." -ForegroundColor Yellow
$publicIp = New-AzPublicIpAddress `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AllocationMethod "Static" `
    -Name $publicIpName `
    -Sku "Standard"  # Standard SKU for better availability

# Create network interface card (NIC)
Write-Host "Creating network interface..." -ForegroundColor Yellow
$nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -SubnetId $vnet.Subnets[0].Id `
    -PublicIpAddressId $publicIp.Id `
    -NetworkSecurityGroupId $nsg.Id

# Create VM configuration object
Write-Host "Configuring virtual machine..." -ForegroundColor Yellow
$vmConfig = New-AzVMConfig `
    -VMName $vmName `
    -VMSize $vmSize  # Specifies 2 vCPUs and 4GB RAM

# Set operating system configuration for Linux
$vmConfig = Set-AzVMOperatingSystem `
    -VM $vmConfig `
    -Linux `
    -ComputerName $vmName `
    -Credential (New-Object PSCredential($adminUsername, $adminPassword)) `
    -DisablePasswordAuthentication:$false  # Allow password authentication

# Set VM source image to Ubuntu 22.04 LTS
$vmConfig = Set-AzVMSourceImage `
    -VM $vmConfig `
    -PublisherName "Canonical" `
    -Offer "0001-com-ubuntu-server-jammy" `
    -Skus "22_04-lts-gen2" `
    -Version "latest"  # Use latest Ubuntu 22.04 LTS image

# Configure OS disk with specified size (40GB)
$vmConfig = Set-AzVMOSDisk `
    -VM $vmConfig `
    -Name "$vmName-osdisk" `
    -CreateOption "FromImage" `
    -StorageAccountType "Premium_LRS" `  # Premium SSD for better performance
    -DiskSizeInGB $osDiskSizeGB

# Disable boot diagnostics to avoid additional storage account requirement
$vmConfig = Set-AzVMBootDiagnostic `
    -VM $vmConfig `
    -Disable

# Attach the network interface to the VM
$vmConfig = Add-AzVMNetworkInterface `
    -VM $vmConfig `
    -Id $nic.Id

# Create the virtual machine
Write-Host "Creating virtual machine... This may take several minutes." -ForegroundColor Yellow
$vm = New-AzVM `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -VM $vmConfig `
    -Verbose

# Get the public IP address of the created VM
$publicIpAddress = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $publicIpName

# Display completion information
Write-Host "`n===========================================" -ForegroundColor Green
Write-Host "VM Creation Completed Successfully!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host "VM Name: $vmName" -ForegroundColor White
Write-Host "Resource Group: $resourceGroupName" -ForegroundColor White
Write-Host "Location: $location" -ForegroundColor White
Write-Host "VM Size: $vmSize (2 vCPUs, 4GB RAM)" -ForegroundColor White
Write-Host "OS Disk Size: $osDiskSizeGB GB" -ForegroundColor White
Write-Host "Operating System: Ubuntu 22.04 LTS" -ForegroundColor White
Write-Host "Admin Username: $adminUsername" -ForegroundColor White
Write-Host "Public IP Address: $($publicIpAddress.IpAddress)" -ForegroundColor Cyan
Write-Host "`nSSH Connection Command:" -ForegroundColor Yellow
Write-Host "ssh $adminUsername@$($publicIpAddress.IpAddress)" -ForegroundColor Cyan
Write-Host "`nNote: It may take a few minutes for the VM to fully boot and accept SSH connections." -ForegroundColor Yellow