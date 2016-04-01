#Set-ExecutionPolicy RemoteSigned #(todo, for giving script execution rights)
#### PARAMS
param (
	#[parameter(Mandatory=$true)]
	$System,
	$GameTitle,
	$GameId,
	$InputFolder,
	$InputFile,
	$UpdateDatabase,
	$OptPrompt = $false,
	$OptBreak = $true
)
	
# Method Logger
function fLogger([string] $str) {
	$line = [DateTime]::Now.ToString() +" --> "+ $str
	if ($line -match "ERROR! *") { write-host -FOREGROUND RED $line }
	elseif ($line -match "WARNING! *") { write-host -FOREGROUND YELLOW $line }
	else { write-host $line }
 
	if ($activeOutputTraces) { "$line" >> $pathToLogFile }
}

# Method to analyze scripts arguments
function fAnalyzeAgrs([Object] $argsList, [string] $arg) {
  $argsList = " "+$argsList+" " 
  $filter = "* "+$arg.Trim()+" *";
  #write-host "-->[$argsList] [$filter]"

  if (([string]$argsList) -like $filter) { 
	#write-host "True -->["$argsList"] "$arg
	return $true 
  }

  return $false
}

function UpdateDatabaseGamesInfos($system, $inputFile, $oXMLRoot) {
	ClearFiles
		
	# 0 : ID thegamesdb.net, 1 : Title, 2 : RomName, 3 : HashMD5
	Get-Content $inputFile | ForEach-Object { $array=$_.Split(';'); $id=UpdateGameInfos $system $array[0] $array[1] $oXMLRoot; TraceLine $id $array[1] $array[2] $array[3]; }
}

function GetFileGamesInfos($system, $inputFile, $oXMLRoot) {
	ClearFiles
	
	Get-Content $inputFile | ForEach-Object { $array=$_.Split(';'); $id=GetGameInfos $system $array[0] $oXMLRoot; TraceLine $id $array[0] $array[1]; }
}

function GetFolderGamesInfos($system, $inputFolder, $oXMLRoot) {
	ClearFiles
	
	Get-ChildItem $inputFolder"\*" | sort Name | ForEach-Object { $game=$_.basename.Trim(); $id=GetGameInfos $system $game $oXMLRoot; TraceFile $inputFolder $id $_; }
}

function ClearFiles() {
	echo '' > $outputWarningFile
	Clear-Content $outputWarningFile
	echo '' > $outputDatabase
	Clear-Content $outputDatabase
}

function TraceLine($id, $title, $romname, $hash) {
	if ($romname -ne $null) {
		$line=[string]$id+";"+$title+";"+$romname+";"+$hash
	} else {
		$line=[string]$id+";"+$title+";;"+$hash
	}

	$line | Out-File -Encoding "UTF8" $outputDatabase -Append
}

function TraceFile($inputFolder, $id, $file) {
	$romname=$file.basename+""+$file.extension
	$hash=GetGameHashMD5 $inputFolder $romname

	$line=[string]$id+";"+$romname+";;"+$hash
	$line | Out-File -Encoding "UTF8" $outputDatabase -Append
}

function TraceWarning($trace) {
	fLogger ($trace)
	echo $trace >> $outputWarningFile
}

function UpdateGameInfos($system, $id, $title, $oXMLRoot) {
	if ($id -eq -1) {
		fLogger ("--- CHECK: " + $id + " / " + $title + " ---")
		$id=GetGameInfos $system $title $oXMLRoot
	} elseif ($id -eq -2) {
		fLogger ("--- NO-CHECK: " + $id + " / " + $title + " ---")
	} else {
		fLogger ("--- UPDATE: " + $id + " / " + $title + " ---")
		$id=GetGameInfosById $id $title $oXMLRoot
	}
	
	#write-host "RESULT ID:[" $id "]"
	return $id
}

function GetGameHashMD5($inputFolder, $romname) {
	$path=$InputFolder+"/"+$romname
	if (Test-Path $path) {
		$hash=Get-FileHash $path -Algorithm MD5
		$hashMD5=$hash.Hash
	}
	else {
		$hashMD5=""
	}
	
	#write-host "RESULT HashMD5:[" $hashMD5 "]"
	return $hashMD5
}

function GetGameInfosById($id, $title, $oXMLRoot) {
	$qGetGame=[string]::Format($queryGetGame, $id)
							
	Do
	{
		$qGetGame_error=0
		fLogger ("[REQUEST:GAME] [ " + $qGetGame + " ]")
		#[xml]$gameDetail = Invoke-WebRequest -ContentType 'text/xml; charset=utf-8' -Uri $qGetGame
		
		[net.httpwebrequest]$httpwebrequest = [net.webrequest]::create($qGetGame)
		[net.httpWebResponse]$httpwebresponse = $httpwebrequest.getResponse()
		
		if ($?) {
			$reader = new-object IO.StreamReader($httpwebresponse.getResponseStream())
			[xml]$gameDetail = $reader.ReadToEnd()
			$reader.Close()
		
			if (($gameDetail -ne $null) -and ($gameDetail.Data.Game.id -ne $null)) {
				fLogger ("FIND_DETAIL_GAME: " + $gameDetail.Data.Game.id + " / " + $gameDetail.Data.Game.GameTitle + " / " + $gameDetail.Data.Game.Platform)
									
				$newNode = $xml.ImportNode($gameDetail.Data.Game, $true)
				$oXMLRoot.AppendChild($newNode) > $null
										
				if ($OptBreak) { return $id }
			}
		}
		else {
			fLogger ("ERROR! [" + $id + "][" + $title + "] [ " + $qGetGame + " ]")
			$qGetGame_error=1
		}
	} While ($qGetGame_error -eq 1)  # WHILE ERRORS, RETRY
}

function GetGameInfos($system, $gameName, $oXMLRoot) {
	$name=GetGameTitle($gameName)
	
	$systems=$system.split(',')
	
	foreach($system in $systems)
	{
		#write-host $system
		$qGetGamesList=[string]::Format($queryGetGamesList, $system, $name)
		
		Do
		{
			$qGetGamesList_error=0
			
			fLogger ("--- [REQUEST:GAMESLIST] [ " + $qGetGamesList + " ] ---")
			#$gamesList = Invoke-WebRequest $queryGetGamesList -OutFile database.xml
			[xml]$gamesList = Invoke-WebRequest $qGetGamesList
			
			if ($?) {
				if ($gamesList -ne $null) {
					#[xml]$database = Get-Content database.xml
					if ($gamesList.Data.Game.length -ne 0) {
						foreach($game in $gamesList.Data.Game) {
							# TAKE FIRST
							#fLogger ("FIND_GAME[" + $name + "]: " + $game.id + " / " + $game.GameTitle + " / " + $game.Platform)
							
							# TODO CHECK GAME NAME
							$gamedb=$game.GameTitle
							
							$prompt = CompareGameTitles $name $gamedb
							if(($OptPrompt -eq $true) -and ($prompt -eq $false)) {
								write-host -FOREGROUND YELLOW "--- GAME MISMATCH ["$name.Trim()"] ["$gamedb.Trim()"] ---"
								$prompt = Read-Host "(y/n)"
							}
							
							if (($prompt -eq $true) -or ($prompt -eq 'y')) {
								fLogger ("FIND_GAME[" + $name + "]: " + $game.id + " / " + $game.GameTitle + " / " + $game.Platform)
								
								# SET GAME ID, TITLE
								$id=$game.id
								$title=$game.GameTitle
								
								$id=GetGameInfosById $id $title $oXMLRoot
								if ($OptBreak) { return $id }
							}
							else {
								TraceWarning ("WARNING! FIND_GAME[" + $name + "]: " + $game.id + " / " + $game.GameTitle + " / " + $game.Platform)
								if ($OptBreak) { break; } #return -1 }
							}
						}
					} else {
						TraceWarning ("WARNING! FIND_GAME[" + $name + "]: " + $system)
					}
				}
			}
			else {
				fLogger ("ERROR! [" + $gameName + "] [ " + $qGetGamesList + " ]")
				$qGetGamesList_error=1
			}
		} While ($qGetGamesList_error -eq 1) # WHILE ERRORS, RETRY
	}
	
	return -1
}

function CompareGameTitles($game, $gamedb) {
	#TODO
	$a = [System.Text.RegularExpressions.Regex]::Replace($game, "[^1-9a-zA-Z_]"," ").Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
	#$a = $game.ToUpper().Replace("/",' ').Replace(":",' ').Replace("'",' ').Replace('.',' ').Replace('-',' ').Replace(',',' ').Replace('&',' ').Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
	$b = [System.Text.RegularExpressions.Regex]::Replace($gamedb, "[^1-9a-zA-Z_]"," ").Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
	#$b = $gamedb.ToUpper().Replace("/",' ').Replace(":",' ').Replace("'",' ').Replace('.',' ').Replace('-',' ').Replace(',',' ').Replace('&',' ').Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
	
	#write-host "COMPARE: ["$game.Trim().ToUpper()"] ["$gamedb.Trim().ToUpper()"]"
	foreach ($w in $a) { $tabA+="[$w]:" } write-host $a.length"-"$tabA.TrimEnd(':')
	foreach ($w in $b) { $tabB+="[$w]:" } write-host $b.length"-"$tabB.TrimEnd(':')
	
	if ($b.length -gt $a.length) { return $false; }
	
	$targetWords1 = 0
	foreach ($w in $a) {
		if (($w.length -gt 1) -and ($b -notcontains $w)) {
			#write-host "MISSMATCH 1: "$w
			$targetWords1++
		}
	}
	
	$targetWords2 = 0
	foreach ($w in $b) {
		if (($w.length -gt 1) -and ($a -notcontains $w)) {
			#write-host "MISSMATCH 2: "$w
			$targetWords2++
		}
	}
	
	#write-host "COUNT1: "$targetWords1 ">=" ($a.count / 2) " -or COUNT2: "$targetWords2 ">=" ($b.count / 2)
	if (($targetWords1 -ge ($a.count / 2)) -or ($targetWords2 -ge ($b.count / 2))) { return $false; }
	
	return $true
}

function GetGameTitle($game) {
	$tgame=$game
	
	$ext=[System.IO.Path]::GetExtension($game)
	if ($ext -ne "") {
		$tgame=[io.path]::GetFileNameWithoutExtension($game)
	}
	
	$tgame=$tgame -replace "(\((.*?)\))", ""
	#$tgame=$tgame -replace "(\[(.*?)\])", ""
	$tgame=$tgame.Trim()
	
	#write-host [$game] [$tgame]
	return $tgame
}

# Method show Help
function fHelp() {
	write-host "`r`nUsage:"
	write-host "SCRAP GAME-TITLE: ./"$ScriptName" [-System '<<system>>'] -GameTitle '<<game_title>>'"
	write-host "SCRAP GAME-ID: ./"$ScriptName" [-System '<<system>>'] -GameId '<<game_id>>'"
	write-host "GENERATE SYSTEM DATABASE: ./"$ScriptName" -System '<<system>>' -InputFolder '<<rom_folder>>'"
	write-host "UPDATE SYSTEM DATABASE: ./"$ScriptName" -System '<<system>>' -UpdateDatabase '<<database_file>>'"
	write-host ("`r`n[SUPPORTED_SYSTEMS]: Nintendo Entertainment System (NES), Super Nintendo (SNES), Nintendo Game Boy, Nintendo Game Boy Color, Nintendo Game Boy Advance, Sega Mega Drive, Sega Genesis, Sega Master System, Amiga, Arcade, TurboGrafx 16")
}

###################################################### Variables Declaration
$scriptFullPath = ($MyInvocation.MyCommand).Definition
$scriptName = ($MyInvocation.MyCommand).Name
$scriptPath = ($MyInvocation.MyCommand).Definition.Replace(($MyInvocation.MyCommand).Name, "")

if (((fAnalyzeAgrs $args "-h") -eq $true) -Or ((fAnalyzeAgrs $args "-?") -eq $true)) {
	fHelp; exit 0;
}

$activeOutputTraces = $true
if ($GameId -ne $null) { $prefix=$GameId }
elseif ($GameTitle -ne $null) {	$prefix=$GameTitle }
elseif ($System -ne $null) { $prefix=$System.split(',')[0] }

$outputWarningFile=$scriptPath+"\"+$prefix+"_warning.log.txt"
$outputDatabase=$scriptPath+"\"+$prefix+"_database.log.txt"
$outputXmlFile=$scriptPath+"\"+$prefix+"_database.xml"
	
$pathToLogFile='./logger.txt'
echo '' > $pathToLogFile
Clear-Content $pathToLogFile
###

fLogger ("[PARAM]System         = [" + $System + "]")
fLogger ("[PARAM]GameTitle      = [" + $GameTitle + "]")
fLogger ("[PARAM]InputFolder    = [" + $InputFolder + "]")
fLogger ("[PARAM]UpdateDatabase = [" + $UpdateDatabase + "]")
fLogger ("[PARAM]OptBreak       = [" + $OptBreak + "]")

if ($System -ne $null) {
	$queryGetGamesList="http://thegamesdb.net/api/GetGamesList.php?platform={0}&name={1}"
}
else {
	$System='unknown'
	$queryGetGamesList="http://thegamesdb.net/api/GetGamesList.php?name={1}"
}
$queryGetGame='http://thegamesdb.net/api/GetGame.php?id={0}'

# INIT OUTPUT FILE
[System.XML.XMLDocument]$xml=New-Object System.XML.XMLDocument

$XmlDeclaration = $Xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
$Xml.AppendChild($XmlDeclaration) | Out-Null

#$encoding="UTF-8" # most encoding should work
#$dec=$xml.CreateXmlDeclaration("1.0", $encoding, "")
#$xml.AppendChild($dec) > $null

[System.XML.XMLElement]$oXMLRoot=$xml.CreateElement("Data")
$xml.AppendChild($oXMLRoot) > $null
[System.XML.XMLElement]$oBaseImgUrl=$xml.CreateElement("baseImgUrl")
$oBaseImgUrl.InnerText = "http://thegamesdb.net/banners/"
$oXMLRoot.AppendChild($oBaseImgUrl) > $null

#if (($System -ne $null) -and ($GameTitle -ne $null)) {
if ($GameId -ne $null) {
	$count=1
	$res=GetGameInfosById $GameId '' $oXMLRoot
} elseif ($GameTitle -ne $null) {
	$count=1
	$res=GetGameInfos $System $GameTitle $oXMLRoot
} elseif (($InputFolder -ne $null) -and (Test-Path $InputFolder)) {
	$count=[System.IO.Directory]::GetFiles("$InputFolder", "*.*").Count
	GetFolderGamesInfos $System $InputFolder $oXMLRoot
} elseif (($InputFile -ne $null) -and (Test-Path $InputFile)) {
	$count=@(Get-Content "$InputFile").Length
	GetFileGamesInfos $System $InputFile $oXMLRoot
} elseif (($UpdateDatabase -ne $null) -and (Test-Path $UpdateDatabase)) {
	$count=@(Get-Content "$UpdateDatabase").Length
	UpdateDatabaseGamesInfos $System $UpdateDatabase $oXMLRoot
}

# SAVE OUTPUTFILE
$count_nodes=$xml.selectnodes("//Data/Game").count
if ($count_nodes -ne "") {
	fLogger ("GAMES FOUND: [" + $count_nodes + "]/[" + $count + "]")
	$xml.Save($outputXmlFile)
}

exit 0
