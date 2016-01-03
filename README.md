# POWERSHELL
This folder contains some usefull powershell scripts.

GetCleanRomset.ps1
=======================
Open powershell prompt, then:<br/>
wget https://raw.githubusercontent.com/frthery/POWERSHELL/master/GetCleanRomset.ps1 -OutFile GetCleanRomset.ps1

Sample:<br/>
.\GetCleanRomset.ps1 -InputFolder "./roms" -OutputFolder "./clean_roms" -Includes "(France),(Europe),(Usa)" -Excludes "(Rev 1),(Proto)" -Clean $true

Arguments:<br/>
-InputFolder  : roms folder<br/>
-Includes     : files to includes<br/>
-Excludes     : files to excludes (Optional)<br/>
-Clean        : delete duplicated roms (Optional)<br/>
-OutputFolder : roms destination folder (Optional)<br/>
