<#
.SYNOPSIS
	Wrapper to automate PowerShell remoting.

.DESCRIPTION
	Two CSV files hold target server names and shortcut cmdlets so you can easily
	mix and match to run without typing much. Emphasis on SharePoint farms,
	but can work on any Windows O/S target machines.
	
	NOTE - MUST MANUALLY UPDATE "Noun" CSV file with target machine names, AD domain,
	and user accout you plan to connect with before any commands can be run.

	Comments and suggestions always welcome!  spjeff@spjeff.com or @spjeff

.PARAMETER install
	Typing "SPLaunch.ps1 -install" will register this PS1 file into the current
	user $profile so it runs automatically when PowerShell starts. Great for full
	time SharePoint admins to have the commands nearby and ready.

.NOTES
	File Name		: SPLaunch.ps1
	Author			: Jeff Jones - @spjeff
	Version			: 1.5.2
	Last Modified	: 07-08-2018
.LINK
	http://splaunch.codeplex.com/
#>

param (
    [switch]$install,
    [switch]$purge
)

#region Internal functions
Function SPLaunchInstaller() {
    # Add to current user profile
    Write-Host "  Installing to $profile..."
	
    # Write to $profile
    if (!(Test-Path $profile)) {
        New-Item $profile -Type File -Force | Out-Null
    }
    ("`n. ""$global:spexec""`n") | Add-Content $profile
    Write-Host "  [OK]" -ForegroundColor Green
    Write-Host
    Write-Host "Close this window and open PowerShell again for ""launch*"" functions to be available" -Foregroundcolor Red
}

Function SPLaunchGetCredential ($domain, $u) {
    # Create registry key (if missing)
    $key = "HKCU:\Software\splaunch"
    if (!(Test-Path $key)) {mkdir $key | Out-Null}
	
    # Do we have saved credentials?
    $user = "$domain\$u"
    $userKey = $user.Replace("\", "-")
    $reg = Get-ItemProperty -Path $key -Name "$userKey" -ErrorAction SilentlyContinue
    if (!$reg) {
        Write-Host "Credential not found for $user" -Foregroundcolor Yellow
		
        # Prompt user for input (if needed)
        $sec = Read-Host "Type password" -AsSecureString
        $hash = $sec | ConvertFrom-SecureString
		
        # Save to registry
        Set-ItemProperty -Path $key -Name "$userKey" -Value $hash -Force
        return $sec
    }
    else {
        # Read from registry
        $reg = Get-ItemProperty -Path $key -Name "$userKey"
        $sec = ConvertTo-SecureString -String $reg."$userKey"
        return $sec
    }
}

function SPLaunchMachines ($machines, $domain, $user, $auth, $port, $ssl) {
    # Open remote PS sessions for each machine by using the given login account
    if ($auth -eq "Kerberos") {
        #Kerberos authenticate as current user
        foreach ($m in $machines) {
            ">> $m"
            $cmd = "New-PSSession -ComputerName `$m"
            if ($port) {$cmd += " -Port $port"}
            if ($ssl -eq "SSL") {$cmd += " -UseSSL"}
            Invoke-Expression $cmd | Out-Null
        }
    }
    else {
        #CredSSP authenticate with user and password (recommend)
        $securePass = SPLaunchGetCredential $domain $user
        if ($securePass -ne $null) {
            $cred = New-Object System.Management.Automation.PSCredential -ArgumentList "$domain\$user", $securePass
            foreach ($m in $machines) {
try {
                ">> $m"
                $cmd = "`$s = New-PSSession -ComputerName `$m -Authentication CredSSP -Credential `$cred -ErrorVariable `$SessionError -ErrorAction Continue"
                if ($port) {$cmd += " -Port $port"}
                if ($ssl -eq "SSL") {$cmd += " -UseSSL"}
                Invoke-Expression $cmd
                if (!$s) {
                    if ($error[0].Exception -like '*auth*' -or $error[0].Exception -like '*Access is denied*') {
                        SPLaunchPurgeSavedCredential $domain $user
                        Write-Host "`nAuthentication failed.  Please verify username, password, and account is not locked." -Foregroundcolor Red
                        #REM break
                    }
                }
} catch {Write-Host $_.Exception.Message}

            }
        }
    }
}

function SPLaunchNoun () {
    # Display all server farms in the CSV configuration file
    $csv = Import-Csv "$global:sppath\SPLaunchNoun.csv"
    $g = $csv | Group-Object -Property Domain
    $g | % {Write-Host $_.Name "-" $_.Count -ForegroundColor Green; $_.Group | select FarmName, Domain, Version, Description, Servers | Format-Table -AutoSize}
    Write-Host $csv.Count "total farms" -ForegroundColor Yellow
}

function SPLaunchVerb ($alias) {
    # Display all shortcut commands in the CSV configuration file
    $csvCommands = Import-Csv "$global:sppath\SPLaunchVerb.csv"
    $csvCommands
    Write-Host $csvCommands.Count "total shortcuts" -ForegroundColor Yellow
}
#endregion

# End user functions
function LaunchAFarm ($farmName, $firstOnly, $callback) {
    # Open all servers in a given farm.  Parameter $firstOnly=1 will open only hte first machine.  
    # Helpful for Central Admin and farm wide tasks (BuildVersion, WSP Deployment, Service Applications, etc.)
	
    # Defaults
    $csv = Import-Csv "$global:sppath\SPLaunchNoun.csv"
    $found = $false
	
    # Title
    if (-not ($callback)) {
        $title = ("$farmName $firstOnly").ToUpper()
        $host.ui.RawUI.WindowTitle = "Farm > $title"
    }
	
    if (-not ($farmName)) {
        # Show options
        Write-Host "Available farms are:" -ForegroundColor Green
        SPLaunchNoun		
    }
    else {
        # Load farm
        if ($farmName.GetType().ToString() -eq "System.String" -and $farmName -like '*,*') {$farmName = $farmName.Split(",")} 

        # All farms
        if ($farmName -like "ALL") {
            $csv | % {LaunchAFarm $_.FarmName $firstOnly $true}
        }
        else {
		
            # Do we have multiple?
            if ($farmName -is [system.array]) {
                # Multiple farms
                foreach ($farm in $farmName) {
                    # Each farm
                    $farm = $farm.ToUpper()
                    $match = $csv |? {$_.FarmName -eq $farm}				
                    if ($match) {
                        Write-Host "$farm - $($match.Notes)" -ForegroundColor Green
                        try {
                            $machines = $match.Servers.Split(",")
                        }
                        catch {
                            $machines = $match.Servers
                        }
                        $d = $match.Domain
                        $u = $match.User
                        $a = $match.Auth
                        $p = $match.Port
                        $s = $match.SSL
						
                       
                        $machines.TrimEnd(",")
                        $machines = $machines.Split(",")

                        # First server only
                        if ($firstOnly) {
                            $machines = $machines[0]
                        }
                        SPLaunchMachines $machines $d $u $a $p $s
                        $found = $true
                    }

 # THIS farm local
                        if ($farm -eq "THIS") {
                            $machines = ""
                            Add-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue | Out-Null
                            $servers = Get-SPServer |? {$_.role -ne "Invalid"}
                            $servers | % {$machines += $_.Address + ","}
$machines = $machines.substring(0, $machines.length-1)
SPLaunchMachines $machines.Split(",") $env:userdomain $env:username $a $p $s
$found = $true
                        }

                }
            }
            else {
                # Single farm
                $farm = $farmName.ToUpper()
                $match = $csv |? {$_.FarmName -eq $farm}
                if ($match) {
                    Write-Host "$farm - $($match.Notes)" -ForegroundColor Green
                    try {
                        $machines = $match.Servers.Split(",")
                    }
                    catch {
                        $machines = $match.Servers
                    }
                    $d = $match.Domain
                    $u = $match.User
                    $a = $match.Auth
                    $p = $match.Port
                    $s = $match.SSL

                    # First server only
                    if ($firstOnly) {
                        $machines = $machines[0]
                    }
                    SPLaunchMachines $machines $d $u $a $p $s
                    $found = $true
                }
 # THIS farm local
                        if ($farm -eq "THIS") {
                            $machines = ""
                            $servers = get-spserver |? {$_.role -ne "Invalid"}
                            $servers | % {$machines += $_.Address + ","}
$machines = $machines.substring(0, $machines.length-1)
SPLaunchMachines $machines.Split(",") $env:userdomain $env:username $a $p $s
$found = $true
                        }

            }
		
            # Not found
            if (-not($found)) {
                $farmName
                $farmName.Length
                Write-Host "Not Found" -ForegroundColor Yellow
            }
        }
		
        # Preload SharePoint and IIS modules
        LaunchCmd {Add-PSSnapIn Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue; Import-Module WebAdministration -ErrorAction SilentlyContinue; }
    }
}

function LaunchAShortcut ($alias, $param1, $param2) {
    # Execute a shortcut command against all open PS remote sessions
    $csvCommands = Import-Csv "$global:sppath\SPLaunchVerb.csv"
    if (-not ($alias)) {
        Write-Host "Available shortcuts are:" -ForegroundColor Green
        $csvCommands
    }
    else {
        $match = $csvCommands |? {$_.Shortcut -eq $alias}
        $cmd = $match.Command
        if ($cmd) {
            if ($param1) {$cmd = $cmd.Replace("[PARAM1]", $param1); }
            if ($param2) {$cmd = $cmd.Replace("[PARAM2]", $param2); }
            if ($cmd.ToLower().StartsWith("#mod")) {
                Write-Host "WARNING - This will modify the target server.  Are you sure? (Y/N)" -ForegroundColor Yellow
                $prompt = Read-Host 
                if ($prompt.ToLower().StartsWith("y")) {
                    $cmd = $cmd.Replace("#mod;", "")
                    Write-Host $cmd -ForegroundColor Yellow
                    return LaunchCmd ([scriptblock]::Create("$cmd"))
                }
                else {
                    Write-Host "Command aborted" -ForegroundColor Red
                }
            }
            else {
                Write-Host $cmd -ForegroundColor Yellow
                return LaunchCmd ([scriptblock]::Create("$cmd"))
            }
        }
    }
}

function LaunchCmd ($cmd) {
    # Execute a manually typed command against all open PS remote sessions
    if (Get-PSSession) {
        Invoke-Command -Session (Get-PSSession) -ScriptBlock $cmd
    }
}

function LaunchEnumSessions ($cmd) {
    # Displays all open PS remote sessions
    Get-PSSession
    $c = (Get-PSSession).Count
    if (!$c) {$c = 0}
    Write-Host "$c total sessions" -ForegroundColor Yellow
}

function LaunchExitSessions ($cmd) {
    # Close all open PS remote sessions
    Get-PSSession | Remove-PSSession
}

function SPLaunchPurgeSavedCredential ($domain, $u) {
    if ($domain) {
        # Purge one saved credential - HKCU
        $key = "HKCU:\Software\splaunch"
        $user = "$domain\$u"
        $userKey = $user.Replace("\", "-")
        if (Test-Path $key) {
            Remove-ItemProperty -path $key -name $userKey | Out-Null
        }
    }
    else {
        # Purge all saved credentials - HKU
        $users = Get-ChildItem Registry::HKEY_USERS
        $key = "\Software\splaunch"
        foreach ($user in $users) {
            $name = $user.Name
            $userKey = "Registry::$name$key"
            if (Test-Path $userKey) {
                $userKey
                Remove-Item $userKey
            }
        }
    }
}

function ent($x) {
    if ($x) {
        (Get-PSSession)[$x] | Enter-PSSession
    }
    else {
        (Get-PSSession)[0] | Enter-PSSession
    }
}
#endregion

# Main
Write-Host "SPLaunch v1.5  (last updated 01-06-2017)`n------`n"
$global:spexec = $MyInvocation.MyCommand.Path
$global:sppath = Split-Path ($MyInvocation.MyCommand.Path)
if ($purge) {
    SPLaunchPurgeSavedCredential
}
if ($install) {
    SPLaunchInstaller
}
else {
    SPLaunchNoun
    SPLaunchVerb
}