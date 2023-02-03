#Previous jobs and sessions must be cleared for proper tracking of captures.

Remove-PSSession *
Remove-Job -name *
enable-psremoting -skipnetworkprofilecheck -force
$cred = get-credential
$user= 'Administrator'
$computers_file = "C:\Users\$user\Documents\deployment_package\computers.txt"
$iterative = Get-Content $computers_file
set-variable -name 'source_dir' -value ("C:\Users\$user\Documents\deployment_package\") -Scope global -PassThru | Out-Null

<#Populate target machines in coomputers.txt using the follwing command:
get-adcomputer -Filter * -properties dnshostname, enabled, lastlogondate, ipv4address, operatingsystem, operatingsystemservicepack | out-gridview
Review this listing, select desired endpoints, and review/gain approval from customer prior to execution#>

ForEach ($computer in $iterative) {
    #$session = New-PSSession -computername $computer -Credential $cred #-ConfigurationName microsoft.powershell32 
    Write-Host ("Attempting to open WINRM session on $computer")
    Set-Variable -Name 'session' -value (New-PSSession -name $computer -computername $computer -Credential $cred)
    $powershellversioncheck = Invoke-Command -Session $session -ScriptBlock {$PSVersionTable.PSVersion}
    if ($powershellversioncheck.major -ge 4){
    Write-Host ("WinRM tunnel opened and powershell version compatible. Copying Kape to endpoint")
    Copy-Item -Path "$source_dir\kape.zip" -Destination ('C:\windows\Temp\') -tosession $session -Recurse -Force}
    Invoke-Command -Session $session -ScriptBlock {
    if ((Test-Path -Path 'C:\Windows\Temp\kape.zip') -and (Get-CimInstance -classname win32_logicaldisk -filter "deviceid='C:'" | ?{$_.FreeSpace -ge 9000MB})){
    $hostname = hostname
    Expand-Archive -literalpath C:\windows\temp\kape.zip -DestinationPath C:\windows\temp\kape\ -Force
    start-process -filepath 'C:\windows\temp\kape\kape.exe' -ArgumentList ( "--tsource C: --tdest C:\Windows\Temp\kape\$hostname\ --target !SANS_Triage,Antivirus,CloudStorage_Metadata,CloudStorage_OneDriveExplorer,CombinedLogs,EvidenceOfExecution,Exchange,FileSystem,RegistryHives,RemoteAdmin,ServerTriage,WebServers --zip $hostname --msource C:\windows\temp\KAPE\Modules\bin --mdest C:\windows\temp\KAPE\$hostname\memory.raw --module MagnetForensics_RAMCapture ") -Wait}
    } -AsJob -JobName "$computer" #comment this line just after the }, to remain inside sessions and recieve output of script for troubleshooting/testing. This will significantly slow the deployment process.
   Write-Host ("Memory capture started $computer. Looping to the next machine")
}
Write-Host ("Monitoring captures. Initiating retievals immediately upon completion")
while ((Get-job -State Completed -HasMoreData $true) -or (get-job -state Running)) {
if (Get-job -State Completed -HasMoreData $true ) {
$job_to_session_link = get-Job -State Completed -HasMoreData $true | select -property name 
$trimmed_name = $job_to_session_link.Name
$session = Get-PSSession -Name $trimmed_name
Write-Host ("Initiating retieval on $trimmed_name")
Copy-Item -FromSession $session -literalpath C:\windows\Temp\kape\$trimmed_name\*.zip -Destination $source_dir -Recurse -Force
Copy-Item -FromSession $session -literalpath C:\windows\Temp\kape\$trimmed_name\*.txt -Destination $source_dir -Recurse -Force
Invoke-Command -Session $session -ScriptBlock {
remove-item -recurse -force 'C:\Windows\Temp\kape'
remove-item -recurse -force 'C:\Windows\Temp\kape.zip'
} -AsJob -JobName "cleanup"
Get-job -Name $trimmed_name | Receive-Job *>&1 >> $source_dir\remotecapturelog.txt}
}

<#Remove-PSSession *
Remove-Job -name *#>