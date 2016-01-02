#Set-ExecutionPolicy RemoteSigned #(todo, for giving script execution rights)
#### PARAMS
param (
	$InputFolder,
	$Includes,
	$Excludes="unknown",
	$Clean = $false
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

function fCopyFile([string] $entry, [string] $filters) {
	if(!(Test-Path -Path $outputFolder)){
		New-Item -ItemType directory -Path $outputFolder > $null
		#fLogger ("directory ["+$output+"] created.")
	}

	$title=GetGameTitle $entry
	$filename=[io.path]::GetFileName($entry)

	fLogger ("CHECK ENTRY ["+$entry+"]...")
	if((Test-Path $entry)) {
		if ($Clean -eq $false) {
			fLogger ("FIND AND COPY FILE ["+$entry+"]!")
			#copy-item -Path $entry -Include @($current) -Destination $outputFolder
			copy-item -Path $entry -Destination $outputFolder
		}
		else {
			# CHECK IF ROM IS ALREADY EXISTS INTO OUTPUT FOLDER
			if ((Test-Path $outputFolder"\"$title"*") -eq $true) {
				fLogger ("WARNING! ["+$outputFolder+"\"+$title+"] already exists.")
				return;
			}
			
			$filtersStr=$filters.split(',')
			foreach ($f in $filtersStr) {
				$current=$title+"*"+$f+"*"
				echo $current
				if (Test-Path $InputFolder"\"$current) {
					fLogger ("FIND AND COPY FILE ["+$InputFolder+"\"+$current+"]!")
					copy-item -Path $InputFolder"\"$current -Destination $outputFolder
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

$outputFolder='./output'
###

if (($args.Count -gt 1) -Or ($args[0] -eq "-h")) {
	#fLogger ("ERROR! [ "+$args.Count+" ] missing or wrong arguments.")
	fLogger ("USAGE: "+$scriptName+" -InputFolder <<roms_folder>> [-Includes '<<include_roms>>'] [-Excludes '<<exclude_roms>>'] [-Clean '$true|$false']")
	exit -1
}

if (Test-Path $InputFolder) {
	"["+$pathToLogFile+" generated at "+[DateTime]::Now.ToString()+"]" > $pathToLogFile
	
	fLogger ("START: FILTER FOLDER ["+$InputFolder+"]")	
	
	$Includes="*"+$Includes+"*"
	$Includes=$Includes.Replace(",", "*,*")
	$IncludesArr=$Includes.split(',')
	
	$Excludes="*"+$Excludes+"*"
	$Excludes=$Excludes.Replace(",", "*,*")
	$ExcludesArr=$Excludes.split(',')
	
	Get-ChildItem $InputFolder"\*" -Include @($IncludesArr) -Exclude @($ExcludesArr) | sort Name | ForEach-Object { fCopyFile $_ $Includes; }
	fLogger ("END: CHECK OUTPUT LOCATION ["+$outputFolder+"].")
}
else {
	fLogger ("ERROR! ["+$InputFolder+"] not found.")
	exit -1
}
