## Description
Wrapper to automate PowerShell remoting. Two CSV files hold target server names and shortcut cmdlets so you can easily mix and match to run without typing much.

![image](https://raw.githubusercontent.com/spjeff/splaunch/master/doc/splaunch.png)

[![](https://raw.githubusercontent.com/spjeff/splaunch/master/doc/download.png)](https://github.com/spjeff/splaunch/releases/download/SPLaunch/SPLaunch.zip)

## Business Challenge
* Growing list of servers
* Inconsistent configuration (DEV has, TEST lacks, PROD just crazy)
* Need to reduce admin time. Make room for business analysis, teach how to use, evangelize features

## Technical Solution
* PowerShell remoting + automation wrapper = rapid fire commands
* PS1 with functions
* Noun CSV with server farms and login user
* Verb CSV with "shortcut" alias PowerShell commands
* Mix and match Noun/Verb CSV with automation wrapper (New-PSSession / Invoke-Command)

## Examples
Open all servers in the "DCO" farm (Development Collaboration) and show total RAM size with percent used:
* `LaunchFarm DCO`
* `LaunchShortcut ram | ft -a`

Open just the first server across all farms and show the SharePoint build number:
* `LaunchFarm ALL 1`
* `LaunchShortcut spver | ft -a`

**NOTE - Must update "Noun" CSV file with target machine names, AD domain, and user account before any commands can be run**

**NOTE - Must run `Enable-WSManCredSSP -Role client -DelegateComputer *` locally before trying to open remote sessions**

![image](https://raw.githubusercontent.com/spjeff/splaunch/master/doc/splaunch-context.png)

## Screenshots
![image](https://raw.githubusercontent.com/spjeff/splaunch/master/doc/1.png)
![image](https://raw.githubusercontent.com/spjeff/splaunch/master/doc/2.png)
![image](https://raw.githubusercontent.com/spjeff/splaunch/master/doc/3.png)
![image](https://raw.githubusercontent.com/spjeff/splaunch/master/doc/4.png)

## Getting Started
* Enable PowerShell remoting and WSMan CredSSP on all target servers. `Enable-PSRemoting -Force` and `Enable-WSManCredSSP -Role Server` http://dustinhatch.tumblr.com/post/24589312635/enable-powershell-remoting-with-credssp-using-group
* Enable PowerShell client with `Enable-PSRemoting -Force` and `Set-Item wsman:\localhost\client\trustedhosts * -Force`
* Update `NounCSV` with servers and user names
* Run `SPLaunch.ps1 -install` to add to $profile so it starts with new PowerShell windows
* Run `LaunchAFarm` to see farms
* Run `LaunchAFarm DCO` to connect to that farm (comma separated allows multiple farms)
* Run `LaunchAShortcut` to see shortcuts
* Run `LaunchAShortcut RAM` to execute the "RAM" command (end with " | ft" to format as table)
* Enjoy!

## Warnings
* Account lockout - Possible if typing the password wrong and open many sessions at once.
* System update - Verb CSV can modify configuration on many servers quickly. Use carefully for changes.
* Desktop O/S must be Windows 7 or higher. Windows XP cannot run `Enable-WSManCredSSP -Role client -DelegateComputer *`

## Contact
Please drop a line to [@spjeff](https://twitter.com/spjeff) or [spjeff@spjeff.com](mailto:spjeff@spjeff.com)
Thanks!  =)

![image](http://img.shields.io/badge/first--timers--only-friendly-blue.svg?style=flat-square)

## License

The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.