<#
#############################################################################  
#                                                                           #  
#   This Sample Code is provided for the purpose of illustration only       #  
#   and is not intended to be used in a production environment.  THIS       #  
#   SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT    #  
#   WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT    #  
#   LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS     #  
#   FOR A PARTICULAR PURPOSE.  We grant You a nonexclusive, royalty-free    #  
#   right to use and modify the Sample Code and to reproduce and distribute #  
#   the object code form of the Sample Code, provided that You agree:       #  
#   (i) to not use Our name, logo, or trademarks to market Your software    #  
#   product in which the Sample Code is embedded; (ii) to include a valid   #  
#   copyright notice on Your software product in which the Sample Code is   #  
#   embedded; and (iii) to indemnify, hold harmless, and defend Us and      #  
#   Our suppliers from and against any claims or lawsuits, including        #  
#   attorneys' fees, that arise or result from the use or distribution      #  
#   of the Sample Code.                                                     # 
#                                                                           # 
#   This posting is provided "AS IS" with no warranties, and confers        # 
#   no rights. Use of included script samples are subject to the terms      # 
#   specified at http://www.microsoft.com/info/cpyright.htm.                # 
#                                                                           #  
#   Author: Donovan du Val                                                  #  
#   Version 1.0         Date Last Modified: 17 August 2022                  #
#                                                                           #  
############################################################################# 

NOTE: Modify the variables with the required application, cert thumbprint and the tenantID.

#>
Set-Location -Path $PSScriptRoot
$CurrentRunDateTime = get-date -Format dd_MM_yyyy
$CurrentExportFileName = "$CurrentRunDateTime.log"
$ProcessLog = "Lockout_Process_$($CurrentRunDateTime).log"
$ProcessLogDateTime = Get-Date
$tenantId = ""
$applicationID = ""
$certThumbPrint = ""

if (test-path $ProcessLog) {
    Add-Content .\$ProcessLog -Value " "
    Add-Content .\$ProcessLog -Value "Process Log exists - $($ProcessLogDateTime)"
}
else {
    New-Item -Type File $ProcessLog
    Add-Content -Path .\$ProcessLog -Value "Process Log Created - $($ProcessLogDateTime)"
}

if (test-path $CurrentExportFileName) {
    Add-Content .\$ProcessLog -Value " "
    Add-Content -Path .\$ProcessLog -Value "Export File Exists"
}
else {
    New-Item -Type File $CurrentExportFileName
    Add-Content -Path .\$CurrentExportFileName -Value $CurrentRunDateTime
    Add-Content -Path .\$ProcessLog -Value "New Export File Created"
}

$AllLockedUsers = (Search-ADAccount -UsersOnly -LockedOut -SearchBase "OU=SyncedUsers,DC=DomainName,DC=Com").userprincipalname

Add-Content -Path .\$ProcessLog -Value "Local AD Locked Out Users Collected: $(($AllLockedUsers | measure-object).count)"

$connection = Connect-MgGraph -TenantId $tenantId -ClientId $applicationID -CertificateThumbprint $certThumbPrint
if ($connection) {
    Add-Content -Path .\$ProcessLog -Value "Graph Logged in Successfully"

    foreach ($onpremUser in $AllLockedUsers) {
        $upn = "UserPrincipalName:$($onpremUser)"
        $isLocked = Get-MgUser -ConsistencyLevel eventual -Search $upn -Property userprincipalname, accountenabled, id, OnPremisesSyncEnabled
        if ($isLocked.AccountEnabled -and $isLocked.OnPremisesSyncEnabled -eq $true) {
            Add-Content -Path .\$ProcessLog -Value "$($isLocked.userprincipalname) is locked. Locking in Azure AD"
            
            Update-MgUser -UserId $isLocked.Id -AccountEnabled:$false
            
            Add-Content -Path .\$CurrentExportFileName -Value $upn
        }
    }
    Disconnect-MgGraph
    
    Add-Content -Path .\$ProcessLog -Value "Graph Disconnected"
}
