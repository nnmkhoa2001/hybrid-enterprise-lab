# ==============================================================================
# Script Name: Provision-Users.ps1 (v2)
# Description: Bulk imports users from CSV into Active Directory OUs,
#              adds each user to their department security group,
#              and writes a log file of created / skipped / failed users.
# ==============================================================================

# Where the CSV lives, where the log will be written, and the root of the domain
$CSVPath = "C:\Users\Administrator\Desktop\employees.csv"
$LogPath = "C:\Users\Administrator\Desktop\provisioning-log.txt"
$DomainDN = "DC=corp,DC=local"

# Read the whole CSV into memory. $Employees is the whole spreadsheet.
$Employees = Import-Csv -Path $CSVPath

# Go through the spreadsheet one row at a time. $Emp is the one row in hand.
foreach ($Emp in $Employees) {
    $FirstName = $Emp.FirstName
    $LastName = $Emp.LastName
    $Dept = $Emp.Department
    $SamAccount = $Emp.Username

    # AD will not accept a plain-text password, so convert it to a SecureString
    $SecurePassword = ConvertTo-SecureString $Emp.Password -AsPlainText -Force

    # Build the address of the folder this user belongs in
    # Example for IT: OU=IT,OU=Employees,DC=corp,DC=local
    $TargetOU = "OU=$Dept,OU=Employees,$DomainDN"

    # The department security group has the same pattern for every department
    # IT -> IT-Users, HR -> HR-Users, Sales -> Sales-Users
    $GroupName = "$Dept-Users"

    # Safety check: does this username already exist?
    $ExistingUser = Get-ADUser -Filter "SamAccountName -eq '$SamAccount'" -ErrorAction SilentlyContinue

    if ($null -eq $ExistingUser) {
        try {
            New-ADUser -Name "$FirstName $LastName" -GivenName $FirstName -Surname $LastName -SamAccountName $SamAccount -UserPrincipalName "$SamAccount@corp.local" -Path $TargetOU -AccountPassword $SecurePassword -Enabled $true -ChangePasswordAtLogon $true

            # Only add to the group after the user was actually created
            Add-ADGroupMember -Identity $GroupName -Members $SamAccount

            $Message = "[SUCCESS] Created user: $FirstName $LastName in OU: $Dept, group: $GroupName"
            Write-Host $Message -ForegroundColor Green
            Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
        }
        catch {
            $Message = "[ERROR] Failed to create user $SamAccount : $_"
            Write-Host $Message -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
        }
    }
    else {
        $Message = "[SKIPPED] User $SamAccount already exists."
        Write-Host $Message -ForegroundColor Yellow
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"

        # A skipped user can still be missing from their group. That is exactly
        # what happens with your original 5: they were created by v1 before the
        # groups existed, so re-running v2 would skip them without ever adding
        # them to a group. Fix it here so the end state is always right.
        try {
            $InGroup = Get-ADGroupMember -Identity $GroupName | Where-Object { $_.SamAccountName -eq $SamAccount }
            if ($null -eq $InGroup) {
                Add-ADGroupMember -Identity $GroupName -Members $SamAccount
                $GMessage = "[GROUP] Added existing user $SamAccount to $GroupName"
                Write-Host $GMessage -ForegroundColor Cyan
                Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $GMessage"
            }
        }
        catch {
            $GMessage = "[ERROR] Could not check/add $SamAccount in $GroupName : $_"
            Write-Host $GMessage -ForegroundColor Red
            Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $GMessage"
        }
    }
}

Write-Host "User provisioning completed! Log written to $LogPath" -ForegroundColor Cyan
