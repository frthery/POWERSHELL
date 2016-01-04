#Set-ExecutionPolicy RemoteSigned #(todo, for giving script execution rights)
#### PARAMS
param (
	$GameDbSource="theGamesDbnet",
	$ES_System,
	$Database
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

function GenerateDatabaseGamesInfos($gameDbSource, $system, $inputFile, $oXMLRoot) {
	# 0 : ID, 1 : Title, 2 : RomName, 3 : HashMD5
	Get-Content $inputFile | ForEach-Object { $array=$_.Split(';'); $id=GetGameInfos $gameDbSource $oXMLRoot $system $array[0] $array[1] $array[2]; }
}

function GetGameInfos($gameDbSource, $oXMLRoot, $system, $id, $title, $romname) {
	if ($id -eq -1) {
		fLogger ("--- NO-CHECK: " + $id + " / " + $title + " ---")
	} elseif ($id -eq -2) {
		fLogger ("--- NO-CHECK: " + $id + " / " + $title + " ---")
	} else {
		if ($gameDbSource -eq "screenscraper") {
			fLogger ("--- UPDATE[ScreenScraper]: " + $id + " / " + $title + " ---")
			$id=GetGameInfosByMD5 $oXMLRoot $system $id $title $romname
		}
		else {
			fLogger ("--- UPDATE[theGamesDbnet]: " + $id + " / " + $title + " ---")
			$id=GetGameInfosById $oXMLRoot $system $id $title $romname
		}
	}
	
	#write-host "RESULT [" $id "]"
	return $id
}

function GetGameInfosByHashMD5($oXMLRoot, $system, $id, $title, $romname, $hash) {
	
}

function GetGameInfosById($oXMLRoot, $system, $id, $title, $romname) {
	$qGetGame=[string]::Format($queryGetGame, $id)

	# Get TITLE AND ROMNAME
	if ($romname -eq $null -Or $romname -eq '') {
		$romname=$title
		$ext=[System.IO.Path]::GetExtension($title)
		if ($ext -ne "") {
			$title=[io.path]::GetFileNameWithoutExtension($title)
		}
	}
	
	Do
	{
		$qGetGame_error=0
		fLogger ("[REQUEST:GAME] [ " + $qGetGame + " ]")
		[xml]$gameDetail = Invoke-WebRequest -ContentType 'text/xml; charset=utf-8' -Uri $qGetGame
		
		[net.httpwebrequest]$httpwebrequest = [net.webrequest]::create($qGetGame)
		[net.httpWebResponse]$httpwebresponse = $httpwebrequest.getResponse()
		
		if ($?) {
			$reader = new-object IO.StreamReader($httpwebresponse.getResponseStream())
			#$reader = new-object IO.StreamReader(".\arcade_database.xml")
			[xml]$gameDetail = $reader.ReadToEnd()
			$reader.Close()
		
			if (($gameDetail -ne $null) -and ($gameDetail.Data.Game.id -ne $null)) {
				fLogger ("FIND_DETAIL_GAME: " + $gameDetail.Data.Game.id + " / " + $gameDetail.Data.Game.GameTitle + " / " + $gameDetail.Data.Game.Platform)

# SAMPLE
#<gameList>
#    <game>
#        <path>/home/pi/ROMs/nes/mm2.nes</path>
#        <name>Mega Man 2</name>
#        <desc>Mega Man 2 is a classic NES game which follows Mega Man as he murders eight robot masters in cold blood.</desc>
#        <image>~/.emulationstation/downloaded_images/nes/Mega Man 2-image.png</image>
#    </game>
#</gameList>
				
				[System.XML.XMLElement]$oGame=$xml.CreateElement("game")

				[System.XML.XMLElement]$oPath=$xml.CreateElement("path")
				$oPath.InnerText = "[ROMS_PATH]/"+$romname
				$oGame.AppendChild($oPath) > $null
				
				[System.XML.XMLElement]$oName=$xml.CreateElement("name")
				$oName.InnerText = $title
				$oGame.AppendChild($oName) > $null
				
				[System.XML.XMLElement]$oDesc=$xml.CreateElement("desc")
				$oDesc.InnerText = $gameDetail.Data.Game.Overview
				$oGame.AppendChild($oDesc) > $null
				
				if (($gameDetail.Data.Game.Images -ne $null) -and ($gameDetail.Data.Game.Images.boxart -ne $null)) {
					#$path=$gameDetail.Data.Game.Images.screenshot.thumb | Select-Object -first 1
					#$path=$gameDetail.Data.Game.Images.boxart.InnerText | Select-Object -first 1
					
					$path = Select-Xml "//boxart[@side='front']" $gameDetail.Data.Game.Images
					#write-host "[PATH_PICTURE]"$path
					if ($path -ne $null) {
						$url="http://thegamesdb.net/banners/_gameviewcache/"+$path
						#$url="http://thegamesdb.net/banners/"+$path
						#write-host "[URL_PICTURE]"$url
						$name=[System.IO.Path]::GetFileName($path)
						#write-host "[NAME]"$name
						
						[System.XML.XMLElement]$oImage=$xml.CreateElement("image")
						$oImage.InnerText = "[PICTURES_PATH]/"+$name
						$oGame.AppendChild($oImage) > $null

						$outputimg=$outputPath+"/"+$name
						wget -outf $outputimg $url
						if ($?) {
							fLogger ("FIND_DETAIL_GAME_PICTURE: " + $url)
						}
						else {
							fLogger ("ERROR! FIND_DETAIL_GAME_PICTURE: " + $url)
						}
					}
					
					$pathLogo = Select-Xml "//clearlogo" $gameDetail.Data.Game
					#write-host "[PATH_LOGO]"$pathLogo
					if ($pathLogo -ne $null) {
						$urlLogo="http://thegamesdb.net/banners/"+$pathLogo
						#write-host "[URL_LOGO]"$urlLogo
						$nameLogo=[System.IO.Path]::GetFileName($pathLogo)
						#write-host "[NAME_LOGO]"$nameLogo
						
						$outputLogo=$outputPathLogos+"/"+$nameLogo
						wget -outf $outputLogo $urlLogo
						if ($?) {
							fLogger ("FIND_DETAIL_GAME_LOGO: " + $urlLogo)
						}
						else {
							fLogger ("ERROR! FIND_DETAIL_GAME_LOGO: " + $urlLogo)
						}
					}
				}
				
				$oXMLRoot.AppendChild($oGame) > $null

				return $id
			}
		}
		else {
			fLogger ("ERROR! [" + $id + "][" + $title + "] [ " + $qGetGame + " ]")
			$qGetGame_error=1
		}
	} While ($qGetGame_error -eq 1)  # WHILE ERRORS, RETRY
}

# Method show Help
function fHelp() {
	write-host "`r`nUsage:"
	write-host "GENERATE ES DATABASE: ./"$ScriptName" -GameDbSource '<<thegamesdb.net|screenscraper>>' -ES_System '<<es_system>>' -Database '<<database_file>>'"
	write-host ("`r`n[SUPPORTED_SYSTEMS]: Nintendo Entertainment System (NES), Super Nintendo (SNES), Nintendo Game Boy, Nintendo Game Boy Color, Nintendo Game Boy Advance, Sega Mega Drive, Sega Genesis, Sega Master System, Amiga, Arcade, TurboGrafx 16")
	write-host ("`r`n[SUPPORTED_ES_SYSTEMS]: nes, snes, gb, gbc, gba, megadrive, mastersystem, amiga, fba, pcengine")
}

###################################################### Variables Declaration
$scriptFullPath = ($MyInvocation.MyCommand).Definition
$scriptName = ($MyInvocation.MyCommand).Name
$scriptPath = ($MyInvocation.MyCommand).Definition.Replace(($MyInvocation.MyCommand).Name, "")

if ((fAnalyzeAgrs $args "-h") -eq $true) { 
	fHelp; exit 0;
}

$activeOutputTraces = $true

$outputPath=$scriptPath+"\"+$ES_System
$outputPathLogos=$scriptPath+"\"+$ES_System+"\logos"
$outputXmlFile=$outputPath+"\gamelist.xml"

$pathToLogFile='./logger.txt'
# CLEAR LOG FILE
echo '' > $pathToLogFile
Clear-Content $pathToLogFile
###

fLogger ("[PARAM]ES_System = [" + $ES_System + "]")
fLogger ("[PARAM]Database  = [" + $Database + "]")

$queryGetGame='http://thegamesdb.net/api/GetGame.php?id={0}'

# SAMPLE
#[SYSTEM_PATH]/gamelist.xml
#~/.emulationstation/gamelists/[SYSTEM_NAME]/gamelist.xml
#/etc/emulationstation/gamelists/[SYSTEM_NAME]/gamelist.xml

# INTI OUTPUT DIR
if (!(Test-Path $outputPath)) {
	New-Item -Path $outputPath -ItemType directory > $null
	fLogger ("CREATE OUTPUT DIR: [" + $outputPath + "]")
}
if (!(Test-Path $outputPathLogos)) {
	New-Item -Path $outputPathLogos -ItemType directory > $null
	fLogger ("CREATE OUTPUT DIR: [" + $outputPathLogos + "]")
}

# INIT OUTPUT FILE
[System.XML.XMLDocument]$xml=New-Object System.XML.XMLDocument

$XmlDeclaration = $Xml.CreateXmlDeclaration("1.0", "UTF-8", $null)
$Xml.AppendChild($XmlDeclaration) | Out-Null

[System.XML.XMLElement]$oXMLRoot=$xml.CreateElement("gameList")
$xml.AppendChild($oXMLRoot) > $null

GenerateDatabaseGamesInfos $GameDbSource $ES_System $Database $oXMLRoot

# SAVE OUTPUTFILE
$count_nodes=$xml.selectnodes("//gameList/game").count
fLogger ("GAMES FOUND: [" + $count_nodes + "]")
$xml.Save($outputXmlFile)

exit 0
