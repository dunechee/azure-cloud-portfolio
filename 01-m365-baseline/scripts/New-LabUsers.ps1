Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All"
$domain = "dunechee.onmicrosoft.com"   # your tenant's primary domain
$users  = Import-Csv "$PSScriptRoot/users.csv"

# One security group per department, created once
$groups = @{}
foreach ($dept in ($users.Department | Sort-Object -Unique)) {
    $groups[$dept] = New-MgGroup -DisplayName "SG-$dept-Staff" -SecurityEnabled `
        -MailEnabled:$false -MailNickname "sg-$($dept.ToLower())-staff"
}

# Create each user, then add them to their department's group
foreach ($u in $users) {
    $alias = "$($u.FirstName).$($u.LastName)".ToLower()
    $tempPassword = "Lab-" + [guid]::NewGuid().ToString("N").Substring(0,12) + "!"
    $newUser = New-MgUser -DisplayName "$($u.FirstName) $($u.LastName)" `
        -UserPrincipalName "$alias@$domain" -MailNickname $alias `
        -Department $u.Department -UsageLocation "GB" -AccountEnabled `
        -PasswordProfile @{ Password = $tempPassword; ForceChangePasswordNextSignIn = $true }
    New-MgGroupMember -GroupId $groups[$u.Department].Id -DirectoryObjectId $newUser.Id
    Write-Host "Created $alias@$domain  temporary password: $tempPassword"
}