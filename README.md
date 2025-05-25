# Azure_Powershell_Script
Automation Script to Create Azure VM
Key Features for Multi-Organization Use:

No hardcoded values - All organization-specific details are prompted from the user
Automatic Azure login - Prompts for credentials regardless of the account
Subscription selection - Handles multiple subscriptions automatically
Module installation - Checks and installs the Azure PowerShell module if missing
Resource group flexibility - Creates new or uses existing resource groups

VM Specifications (as requested):

2 CPU cores and 4GB RAM (Standard_B2s VM size)
40GB storage (Premium SSD for better performance)
Ubuntu 22.04 LTS (latest stable version)

Detailed Line-by-Line Explanations:
The script includes comprehensive comments explaining each section's purpose, from initial setup and authentication through network configuration and final VM creation.
To use this script:

Save it as a .ps1 file
Run it in PowerShell (may need to run Set-ExecutionPolicy RemoteSigned first)
Follow the prompts for your specific Azure environment
The script will output connection details when complete

The script creates all necessary Azure resources (virtual network, security group, public IP, etc.) and provides the SSH connection command at the end. It's designed to be completely self-contained and work in any Azure environment without modification.
