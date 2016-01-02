# POWERSHELL
This folder contains some usefull powershell scripts.

GetCleanRomset.ps1
=======================
Open powershell prompt, then:<br/>
wget https://raw.githubusercontent.com/frthery/POWERSHELL/master/GetCleanRomset.ps1 -OutFile GetCleanRomset.ps1

Sample:<br/>
.\GetCleanRomset.ps1 -InputFolder ./roms -Includes "(France),(Europe),(Usa)" -Excludes "(Rev 1),(Proto)" -Clean $true

arguments:<br/>
-InputFolder : roms folder<br/>
-Includes    : files to includes<br/>
-Excludes    : files to excludes<br/>
-Clean       : delete duplicated roms<br/>
