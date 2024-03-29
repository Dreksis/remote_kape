﻿# Description: Automates management of PowerShell jobs and sessions, enables remoting, and handles deployment packages.
# Author: SEER
# Created: Q1 2023
# Version: 1.0
# Usage: Run in a privileged PowerShell session. Update `$computers_file` with the path to the target computers list.
# Warning: This script alters system state. Use with caution in controlled environments.

# Clear any previous jobs and sessions for proper tracking of captures.
Remove-PSSession *
Remove-Job -name *

# Enable PowerShell remoting and get credentials for authentication.
enable-psremoting -skipnetworkprofilecheck -force
$cred = get-credential

# Define variables for deployment package and target computers.
$user= 'Administrator'
$computers_file = "C:\Users\$user\Documents\deployment_package\computers.txt"
$iterative = Get-Content $computers_file
set-variable -name 'source_dir' -value ("C:\Users\$user\Documents\deployment_package\") -Scope global -PassThru | Out-Null

<# Populate target machines in computers.txt using the following command:
get-adcomputer -Filter * -properties dnshostname, enabled, lastlogondate, ipv4address, operatingsystem, operatingsystemservicepack | out-gridview
# Review this listing, select desired endpoints, and review/gain approval from customer prior to execution#>
# Use ONLY HOSTNAMES for computers.txt. There should be no empty space or characters in the listing and the hostnames should be layered each on their own line.
# Test using just localhost in computers.txt first.

# Loop through each target computer and initiate a PowerShell session.
ForEach ($computer in $iterative) {
    Write-Host ("Attempting to open WINRM session on $computer")
    Set-Variable -Name 'session' -value (New-PSSession -name $computer -computername $computer -Credential $cred)

    # Check the PowerShell version on the target computer and copy Kape to the endpoint if compatible.
    $powershellversioncheck = Invoke-Command -Session $session -ScriptBlock {$PSVersionTable.PSVersion}
    if ($powershellversioncheck.major -ge 4){
        Write-Host ("WinRM tunnel opened and powershell version compatible. Copying Kape to endpoint")
        Copy-Item -Path "$source_dir\kape.zip" -Destination ('C:\windows\Temp\') -tosession $session -Recurse -Force
    }

    # Initiate memory capture on the target computer.
    Invoke-Command -Session $session -ScriptBlock {
        if ((Test-Path -Path 'C:\Windows\Temp\kape.zip') -and (Get-CimInstance -classname win32_logicaldisk -filter "deviceid='C:'" | ?{$_.FreeSpace -ge 9000MB})){
            $hostname = hostname
            Expand-Archive -literalpath C:\windows\temp\kape.zip -DestinationPath C:\windows\temp\kape\ -Force
            start-process -filepath 'C:\windows\temp\kape\kape.exe' -ArgumentList ( "--tsource C: --tdest C:\Windows\Temp\kape\$hostname\ --target !SANS_Triage,Antivirus,CloudStorage_Metadata,CloudStorage_OneDriveExplorer,CombinedLogs,EvidenceOfExecution,Exchange,FileSystem,RegistryHives,RemoteAdmin,ServerTriage,WebServers --zip $hostname --msource C:\windows\temp\KAPE\Modules\bin --mdest C:\windows\temp\KAPE\$hostname\memory.raw --module MagnetForensics_RAMCapture ") -Wait
        }
    } -AsJob -JobName "$computer"

    Write-Host ("Memory capture started $computer. Looping to the next machine")
}

# Monitor captures and initiate retrievals immediately upon completion.
Write-Host ("Monitoring captures. Initiating retrievals immediately upon completion")
while ((Get-job -State Completed -HasMoreData $true) -or (get-job -state Running)) {
    if (Get-job -State Completed -HasMoreData $true ) {
        $job_to_session_link = get-Job -State Completed -HasMoreData $true | select -property name 
        $trimmed_name = $job_to_session_link.Name
        $session = Get-PSSession -Name $trimmed_name
        Write-Host ("Initiating retrieval on $trimmed_name")

        # Copy captured data from the target computer to the deployment package directory.
        Copy-Item -FromSession $session -literalpath C:\windows\Temp\kape\$trimmed_name\*.zip -Destination $source_dir -Recurse -Force
        Copy-Item -FromSession $session -literalpath C:\windows\Temp\kape\$trimmed_name\*.txt -Destination $source_dir -Recurse -Force

        # Remove captured data and cleanup temporary files on the target computer.
        Invoke-Command -Session $session -ScriptBlock {
            remove-item -recurse -force 'C:\Windows\Temp\kape'
            remove-item -recurse -force 'C:\Windows\Temp\kape.zip'
        } -AsJob -JobName "cleanup"

        # Write the output of the script to a log file.
        Get-job -Name $trimmed_name | Receive-Job *>&1 >> $source_dir\remotecapturelog.txt
    }
}

<# Clear any remaining jobs and sessions.
Remove-PSSession *
Remove-Job -name *
#>