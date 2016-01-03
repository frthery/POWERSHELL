#Set-ExecutionPolicy RemoteSigned #(todo, for giving script execution rights)
#### PARAMS
param (
	$InputFolder,
	$OutputFolder="./output",
	$Includes,
	$Excludes="unknown",
	$Clean=$false
)

# Method to trace
function fLogger([string] $str) {
	$line = [DateTime]::Now.ToString() +" --> "+ $str
	if ($line -match "ERROR! *")
		{ write-host -FOREGROUND RED $line }
	elseif ($line -match "WARNING! *")
		{ write-host -FOREGROUND YELLOW $line }
	else
		{ write-host $line }
  
	if ($activeOutputTraces)
		{ "$line" >> $pathToLogFile }
}

function fCopyFile([string] $entry, [array] $includes, [array] $excludes) {
	if(!(Test-Path -Path $OutputFolder)){
		New-Item -ItemType directory -Path $OutputFolder > $null
	}

	$title=GetGameTitle $entry
	$filename=[io.path]::GetFileName($entry)

	fLogger ("CHECK ENTRY ["+$entry+"]...")
	if(Test-Path -literalpath "$entry") {
		if ($Clean -eq $false) {
			fLogger ("FIND AND COPY FILE ["+$entry+"]!")
			#copy-item -Path $entry -Include @($current) -Destination $OutputFolder
			copy-item -literalpath "$entry" -Destination $OutputFolder
		}
		else {
			foreach ($f in $includes) {
				$current=$title+" "+$f.Trim("*")+"*"
				#echo $current
				
				# CHECK IF A ROM IS ALREADY EXISTING INTO OUTPUT FOLDER
				if (Test-Path "$OutputFolder\$current") {
					fLogger ("WARNING! ["+$OutputFolder+"\"+$title+"] ALREADY EXISTS.")
					break;
				}
			
				# CHECK AND COPY ROMS
				if (Test-Path "$InputFolder\$current" -Exclude $excludes) {
					fLogger ("FIND AND COPY FILE ["+$InputFolder+"\"+$current+"]!")
					copy-item -Path "$InputFolder\$current" -Exclude $excludes -Destination $OutputFolder
					break;
				}
			}
		}
	}
	else {
		#fLogger ("WARNING! ["+$entry+"] NOT EXISTS.")
	}
}

function GetGameTitle($game) {
	$tgame=$game
	
	$ext=[System.IO.Path]::GetExtension($game)
	if ($ext -ne "") {
		$tgame=[io.path]::GetFileNameWithoutExtension($game)
	}
	
	$tgame=$tgame -replace "(\((.*?)\))", ""
	$tgame=$tgame -replace "(\[(.*?)\])", ""
	$tgame=$tgame.Trim()
	
	#write-host [$game] [$tgame]
	return $tgame
}

###################################################### Variables Declaration
$scriptFullPath 	= ($MyInvocation.MyCommand).Definition
$scriptName			= ($MyInvocation.MyCommand).Name
$scriptPath 		= ($MyInvocation.MyCommand).Definition.Replace(($MyInvocation.MyCommand).Name, "")

$activeOutputTraces = $true
$pathToLogFile = $scriptName+".log.txt"

$IncludesArr=$null
$ExcludesArr=$null
###

if (($args.Count -gt 1) -Or ($args[0] -eq "-h")) {
	#fLogger ("ERROR! [ "+$args.Count+" ] missing or wrong arguments.")
	fLogger ("USAGE: "+$scriptName+" -InputFolder <<roms_folder>> [-OutputFolder <<roms_destination_folder>>] [-Includes '<<include_roms>>'] [-Excludes '<<exclude_roms>>'] [-Clean '$true|$false']")
	exit -1
}

if (Test-Path $InputFolder) {
	"["+$pathToLogFile+" generated at "+[DateTime]::Now.ToString()+"]" > $pathToLogFile
	
	fLogger ("START: CLEAN ROMS FOLDER ["+$InputFolder+"]")	
	
	$Includes="*"+$Includes+"*"
	$Includes=$Includes.Replace(",", "*,*")
	$IncludesArr=$Includes.split(',')
	
	$Excludes="*"+$Excludes+"*"
	$Excludes=$Excludes.Replace(",", "*,*")
	$ExcludesArr=$Excludes.split(',')
	
	Get-ChildItem $InputFolder"\*" -Include @($IncludesArr) -Exclude @($ExcludesArr) | sort Name | ForEach-Object { fCopyFile $_ $IncludesArr $ExcludesArr; }
	fLogger ("END: CHECK OUTPUT LOCATION ["+$OutputFolder+"].")
}
else {
	fLogger ("ERROR! ["+$InputFolder+"] not found.")
	exit -1
}
