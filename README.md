# POWERSHELL
This folder contains some usefull powershell scripts.

GetCleanRomset.ps1
=======================
Open powershell prompt, then:
Get file: wget https://raw.githubusercontent.com/frthery/POWERSHELL/master/GetCleanRomset.ps1 -OutFile GetCleanRomset.ps1

Sample:
Execution: .\GetCleanRomset.ps1 -InputFolder ./roms -Includes "(France),(Europe),(Usa)" -Excludes "(Rev 1),(Proto)" -Clean $true
