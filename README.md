# Mass Acquisition of KAPE Triages

## Introduction

This is a PowerShell script that automates the process of performing KAPE triages and memory captures across multiple remote machines at once. The script establishes a remote PowerShell session with the remote machines, and if the PowerShell version on the remote machine is compatible (version 4 or higher), copies a compressed archive of KAPE to the remote machine, extracts it, and starts the capture process. This is all accomplished as a WinRM session background job for each machine. The script then monitors the job status of the captures across all machines, and retrieves the captured data when complete. Data is compressed on the endpoint prior to retrieval.

By collecting data from multiple machines, the threat hunter can have a larger pool of data to analyze, leading to a better understanding of the attack surface and the nature of the security incidents.

## Example Use Case:
- Capturing baseline forensic data of several critical servers or suspicious endpoints at the beginning of an engagement.

## Prerequisites
- Windows operating system with PowerShell 4.0 or later installed
- Access to a file named computers.txt containing a list of computer names
- A valid set of credentials for establishing remote PowerShell sessions
- The computers you want to perform memory captures on must be in the same domain as the machine you are running the script on.
- The user account running the script must have administrator privileges on the remote machines.
- The computers.txt file containing a list of the computer names must be located in the deployment_package folder.
- The KAPE package must be located in a folder named deployment_package. This can be changed by editing $source_dir and $computers_file variables

## Mandatory Group Policy prerequisites:
- Computer Configuration -> Administrative Templates -> Windows Components -> Windows Remote Management (WinRM)/WinRM Service:
    - Allow Remote Server Management through WinRM: Enabled
        - IPV4 filter: *
        - IPV6 filter: *

- Set the following setting Computer Configuration -> Administrative Templates -> Windows Components -> Windows Remote Management (WinRM)/WinRM Client to the following:
    - Trusted Hosts: 
        - Client1 IP you want to remote to
        - Client2 IP you want to remote to

- Set the following setting Computer Configuration -> Policies -> Windows Settings -> Security Settings -> Windows Firewall with Advanced Security to the following:
    - Inbound Rule: Windows Remote Management (HTTP-In): Allow

- Set the following setting Computer Configuration -> Policies -> Windows Settings -> Security Settings -> System Services to the following:
    - Windows Remote Management (WS-Management): Startup Mode: Automatic

## Usage
- Open PowerShell as an administrator on the machine you want to run the script on.
- Run the script. You may need to change execution policy to run, or can make this setting in GPO.
- Enter your credentials when prompted.
- The script will establish remote PowerShell sessions with the remote machines, copy KAPE to the remote machines, start the captures, and retrieve the captured data when the captures are complete.

## Notes
- Memory captures are performed via magnet ram capture. Upgrading to WinPMEM in the future
- The script writes the output of each capture to the remotecapturelog.txt file located in the deployment_package folder for troubleshooting.
- The script removes the KAPE package and the captured data from the remote machines after the data has been retrieved.
- If you made changes in group policy for WinRM, give machines time to recieve GP update. GP refresh is 90 mins by default. You may also update them manually using gpupdate /force on the endpoints.
