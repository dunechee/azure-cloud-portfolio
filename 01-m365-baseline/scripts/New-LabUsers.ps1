Connect-MgGraph -Scopes "User.ReadWrite.All","Group.ReadWrite.All"
$domain = "dunechee.onmicrosoft.com"   # your tenant's primary domain
$users  = Import-Csv "$PSScriptRoot/users.csv"

# Stop early if the CSV isn't what we expect
if (-not $users) { throw "users.csv has no rows." }
$required = "FirstName", "LastName", "Department"
$found    = $users[0].PSObject.Properties.Name
$missing  = $required | Where-Object { $_ -notin $found }
if ($missing) {
    throw "users.csv is missing column(s): $($missing -join ', '). Found: $($found -join ', ')"
}

# One security group per department; reuse it if it already exists
$groups = @{}
foreach ($dept in ($users.Department | Sort-Object -Unique)) {
    $name     = "SG-$dept-Staff"
    $existing = Get-MgGroup -Filter "displayName eq '$name'"
    if ($existing) {
        $groups[$dept] = $existing | Select-Object -First 1
    } else {
        $groups[$dept] = New-MgGroup -DisplayName $name -SecurityEnabled `
            -MailEnabled:$false -MailNickname "sg-$($dept.ToLower())-staff"
    }
}

# Create each user (skip any that already exist), then add them to their group
foreach ($u in $users) {
    $alias = "$($u.FirstName).$($u.LastName)".ToLower()
    $upn   = "$alias@$domain"
    if (Get-MgUser -Filter "userPrincipalName eq '$upn'") {
        Write-Host "Skipped $upn (already exists)"
        continue
    }
    $tempPassword = "Lab-" + [guid]::NewGuid().ToString("N").Substring(0,12) + "!"
    try {
        $newUser = New-MgUser -DisplayName "$($u.FirstName) $($u.LastName)" `
            -UserPrincipalName $upn -MailNickname $alias `
            -Department $u.Department -UsageLocation "GB" -AccountEnabled `
            -PasswordProfile @{ Password = $tempPassword; ForceChangePasswordNextSignIn = $true } `
            -ErrorAction Stop
        New-MgGroupMember -GroupId $groups[$u.Department].Id `
            -DirectoryObjectId $newUser.Id -ErrorAction Stop
        Write-Host "Created $upn  temporary password: $tempPassword"
    } catch {
        Write-Warning "Failed for $($u.FirstName) $($u.LastName): $($_.Exception.Message)"
    }
}