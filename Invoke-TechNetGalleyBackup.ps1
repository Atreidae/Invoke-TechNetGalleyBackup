<#
    .SYNOPSIS

    This is a tool to backup content from the TechNet gallery before it is taken offline.

    .DESCRIPTION

    Created by James Arber. www.UcMadScientist.com
    
    .NOTES

    Version                : 1.0
    Date                   : 01/08/2020
    Lync Version           : Tested against Lync 2013, Skype4B 2015, Skype4b 2019
    Author                 : James Arber
    Header stolen from     : Greig Sheridan who stole it from Pat Richard's amazing "Get-CsConnections.ps1"


    :v1.0: Initial Release

    Disclaimer: Whilst I take considerable effort to ensure this script is error free and wont harm your enviroment.
    I have no way to test every possible senario it may be used in. I provide these scripts free
    to the Lync and Skype4B community AS IS without any warranty on it's appropriateness for use in
    your environment. I disclaim all implied warranties including,
    without limitation, any implied warranties of merchantability or of fitness for a particular
    purpose. The entire risk arising out of the use or performance of the sample scripts and
    documentation remains with you. In no event shall I be liable for any damages whatsoever
    (including, without limitation, damages for loss of business profits, business interruption,
    loss of business information, or other pecuniary loss) arising out of the use of or inability
    to use the script or documentation.

    Acknowledgements 	
    : Testing and Advice
    Greig Sheridan https://greiginsydney.com/about/ @greiginsydney

    : Auto Update Code
    Pat Richard https://ucunleashed.com @patrichard

    : Proxy Detection
    Michel de Rooij	http://eightwone.com

    .LINK
    https://www.UcMadScientist.com/preparing-for-teams-export-your-on-prem-lis-data-for-cqd/

    .KNOWN ISSUES
    Check https://github.com/Atreidae/Export-LisDataForCQD/issues/

    .EXAMPLE
    Exports all the contributions in the Lync category.
    PS C:\> Invoke-TechNetGalleyBackup.ps1 -Category Lync

#>

[CmdletBinding(DefaultParametersetName = 'Common')]
param
(
  [switch]$SkipUpdateCheck,
  [String]$Category = $null,
  [int]$StartAtPost = 0,
  [String]$script:LogFileLocation = $null
)

If (!$script:LogFileLocation) 
{
  $script:LogFileLocation = $PSCommandPath -replace '.ps1', '.log'
}

#region config
[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'
$StartTime                          = Get-Date
$VerbosePreference                  = 'SilentlyContinue'
[String]$ScriptVersion              = '1.0.0'
[string]$GithubRepo                 = 'Invoke-TechNetGalleyBackup'
[string]$GithubBranch               = 'master'
[string]$BlogPost                   = 'technet-is-doomed!-how-to-save-your-favourite-tools-easily' 

Function Write-Log
{
  <#
      .SYNOPSIS
      Function to output messages to the console based on their severity and create log files

      .DESCRIPTION
      It's a logger.

      .PARAMETER Message
      The message to write

      .PARAMETER Path
      The location of the logfile.

      .PARAMETER Severity
      Sets the severity of the log message, Higher severities will call Write-Warning or Write-Error

      .PARAMETER Component
      Used to track the module or function that called "Write-Log" 

      .PARAMETER LogOnly
      Forces Write-Log to not display anything to the user

      .EXAMPLE
      Write-Log -Message 'This is a log message' -Severity 3 -component 'Example Component'
      Writes a log file message and displays a warning to the user

      .NOTES
      N/A

      .LINK
      http://www.UcMadScientist.com

      .INPUTS
      This function does not accept pipelined input

      .OUTPUTS
      This function does not create pipelined output
  #>
  [CmdletBinding()]
  PARAM
  (
    [String]$Message,
    [String]$Path = $script:LogFileLocation,
    [int]$Severity = 1,
    [string]$Component = 'Default',
    [switch]$LogOnly
  )
  $Date             = Get-Date -Format 'HH:mm:ss'
  $Date2            = Get-Date -Format 'MM-dd-yyyy'
  $MaxLogFileSizeMB = 10
  
  If(Test-Path -Path $Path)
  {
    if(((Get-ChildItem -Path $Path).length/1MB) -gt $MaxLogFileSizeMB) # Check the size of the log file and archive if over the limit.
    {
      $ArchLogfile = $Path.replace('.log', "_$(Get-Date -Format dd-MM-yyy_hh-mm-ss).lo_")
      Rename-Item -Path ren -NewName $Path -Path $ArchLogfile
    }
  }
         
  "$env:ComputerName date=$([char]34)$Date2$([char]34) time=$([char]34)$Date$([char]34) component=$([char]34)$Component$([char]34) type=$([char]34)$Severity$([char]34) Message=$([char]34)$Message$([char]34)"| Out-File -FilePath $Path -Append -NoClobber -Encoding default
  If (!$LogOnly) 
  {
    #If LogOnly is set, we dont want to write anything to the screen as we are capturing data that might look bad onscreen
      
      
    #If the log entry is just Verbose (1), output it to verbose
    if ($Severity -eq 1) 
    {
      "$Date $Message"| Write-Verbose
    }
      
    #If the log entry is just informational (2), output it to write-host
    if ($Severity -eq 2) 
    {
      "Info: $Date $Message"| Write-Host -ForegroundColor Green
    }
    #If the log entry has a severity of 3 assume it's a warning and write it to write-warning
    if ($Severity -eq 3) 
    {
      "$Date $Message"| Write-Warning
    }
    #If the log entry has a severity of 4 or higher, assume it's an error and display an error message (Note, critical errors are caught by throw statements so may not appear here)
    if ($Severity -ge 4) 
    {
      "$Date $Message"| Write-Error
    }
  }
}

Function Get-IEProxy
{
  $function = 'Get-IEProxy'
  Write-Log -component $function -Message 'Checking for IE First Run' -severity 1
  if ((Get-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').Property -NotContains 'ProxyEnable')
  {
    $null = New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0
  }
  

  Write-Log -component $function -Message 'Checking for Proxy' -severity 1
  If ( (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').ProxyEnable -ne 0)
  {
    $proxies = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings').proxyServer
    if ($proxies) 
    {
      if ($proxies -ilike '*=*')
      {
        return $proxies -replace '=', '://' -split (';') | Select-Object -First 1
      }
      
      Else 
      {
        return ('http://{0}' -f $proxies)
      }
    }
    
    Else 
    {
      return $null
    }
  }
  Else 
  {
    return $null
  }
}

Function Get-ScriptUpdate 
{
  $function = 'Get-ScriptUpdate'
  Write-Log -component $function -Message 'Checking for Script Update' -severity 1
  Write-Log -component $function -Message 'Checking for Proxy' -severity 1
  $ProxyURL = Get-IEProxy
  
  If ($ProxyURL)
  
  {
    Write-Log -component $function -Message "Using proxy address $ProxyURL" -severity 1
  }
  
  Else
  {
    Write-Log -component $function -Message 'No proxy setting detected, using direct connection' -severity 1
  }

  Write-Log -component $function -Message "Polling https://raw.githubusercontent.com/atreidae/$GithubRepo/$GithubBranch/version" -severity 1
  $GitHubScriptVersion = Invoke-WebRequest -Uri "https://raw.githubusercontent.com/atreidae/$GithubRepo/$GithubBranch/version" -TimeoutSec 10 -Proxy $ProxyURL -UseBasicParsing
  
  If ($GitHubScriptVersion.Content.length -eq 0) 
  {
    #Empty data, throw an error
    Write-Log -component $function -Message 'Error checking for new version. You can check manually using the url below' -severity 3
    Write-Log -component $function -Message $BlogPost -severity 3 
    Write-Log -component $function -Message 'Pausing for 5 seconds' -severity 1
    Start-Sleep -Seconds 5
  }
  else
  {
    #Process the returned data
    #Symver support!
    [string]$Symver = ($GitHubScriptVersion.Content)
    $splitgitver = $Symver.split('.') 
    $splitver = $ScriptVersion.split('.')
    $needsupdate = $false
    #Check for Major version

    if ([single]$splitgitver[0] -gt [single]$splitver[0])
    {
      $Needupdate = $true
      #New Major Build available, #Prompt user to download
      Write-Log -component $function -Message 'New Major Version Available' -severity 3
      $title = 'Update Available'
      $Message = 'a major update to this script is available, did you want to download it?'
    }

    if (([single]$splitgitver[1] -gt [single]$splitver[1]) -and ([single]$splitgitver[0] -eq [single]$splitver[0]))
    {
      $Needupdate = $true
      #New Major Build available, #Prompt user to download
      Write-Log -component $function -Message 'New Minor Version Available' -severity 3
      $title = 'Update Available'
      $Message = 'a minor update to this script is available, did you want to download it?'
    }

    if (([single]$splitgitver[2] -gt [single]$splitver[2]) -and ([single]$splitgitver[1] -gt [single]$splitver[1]) -and ([single]$splitgitver[0] -eq [single]$splitver[0]))
    {
      $Needupdate = $true
      #New Major Build available, #Prompt user to download
      Write-Log -component $function -Message 'New Bugfix Available' -severity 3
      $title = 'Update Available'
      $Message = 'a bugfix update to this script is available, did you want to download it?'
    }

    If($Needupdate)
    {
      $yes = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes', `
      'Update the installed PowerShell Module'

      $no = New-Object -TypeName System.Management.Automation.Host.ChoiceDescription -ArgumentList '&No', `
      'No thanks.'

      $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

      $result = $host.ui.PromptForChoice($title, $Message, $options, 0) 

      switch ($result)
      {
        0 
        {
          #User said yes
          Write-Log -component $function -Message 'User opted to download update' -severity 1
          #start $BlogPost
          Repair-BsInstalledModules -ModuleName 'BounShell' -Operation 'Update'
          Write-Log -component $function -Message 'Exiting Script' -severity 3
          Pause
          exit
        }
        #User said no
        1 
        {
          Write-Log -component $function -Message 'User opted to skip update' -severity 1
        }
      }
    }
    
    #We already have the lastest version
    Else
    {
      Write-Log -component $function -Message 'Script is upto date' -severity 1
    }
  }
}

Write-Log -Message "Invoke-TechNetGalleryBackup.ps1 Version $ScriptVersion" -severity 2


#Get Proxy Details
$ProxyURL = Get-IEProxy
If ($ProxyURL) 
{
  Write-Log -Message "Using proxy address $ProxyURL" -severity 2
}
Else 
{
  Write-Log -Message 'No proxy setting detected, using direct connection' -severity 1
}

#Check for Script update
if ($SkipUpdateCheck -eq $false) 
{
  Get-ScriptUpdate
}


If ($Category -eq "" )
{
  Write-Log -Message "Script called without a category, Please run again with the -Category parameter set" -severity 2
  Write-Log -Message "For example to backup the Lync category run PS> Invoke-TechNetGalleryBackup -Category Lync" -severity 2
  Write-Log -Message "PS> ./Invoke-TechNetGalleryBackup.ps1 -Category Lync" -severity 2
  Throw "Missing Category"
}
$testpath = ($PSCommandPath -replace 'Invoke-TechNetGalleyBackup.ps1', 'TechNet-Gallery-to-GitHub-Migrator.ps1')
If (!(Test-Path -Path $testpath))
{
  Write-Log -Message "TechNet-Gallery-to-GitHub-Migrator.ps1 not found in the same folder as this script. Please download it from myskypelab.com" -severity 2
  Write-Log -Message "https://www.myteamslab.com/2020/05/technet-gallery-to-github-migration-tool.html" -severity 2
  
  Throw "Missing required script"

}

Write-Log -Message "Scraping index for $Category from TechNet" -severity 2

#Pull the category
Write-Progress -Activity "Scraping Index" -Status 'Downloading Index'
$Pages = Invoke-WebRequest "https://gallery.technet.microsoft.com/site/search?f%5B0%5D.Type=RootCategory&f%5B0%5D.Value=$Category&f%5B0%5D.Text=Lync&sortBy=Date&pageIndex=1"


#Figure out how many pages we need to scrape

#Find the last page link
$LastPage = ($Pages.links | where-object {$_.innertext -eq "Last »"}).href

#Match the last number in that link
$Search = $Lastpage | select-string -pattern '(\d{1,3}$)'
$lastpage = $search.matches.Value

Write-Log -Message "Found $lastPage pages worth of content" -severity 2


#Pull all the gallery links from the pages into an array
$currentPage = 1
$ContentURLs = @()
While ($CurrentPage -le $LastPage)
{
  Write-Progress -Activity Scraping -Status "Page $currentpage of $lastpage" -CurrentOperation Scraping -PercentComplete ((($CurrentPage) / $LastPage) * 100)
  Write-Log -Message "Scraping page $CurrentPage" -severity 2
  $CurrentPageContent = Invoke-WebRequest "https://gallery.technet.microsoft.com/site/search?f%5B0%5D.Type=RootCategory&f%5B0%5D.Value=$Category&f%5B0%5D.Text=Lync&sortBy=Date&pageIndex=$CurrentPage"
  $ContentURLs += ($CurrentPageContent.links.href | select-string -Pattern '-.{8}$')
  $currentPage ++

   #Sleep for 10 seconds to give the gallery a break
    For ($i=10; $i -gt 1; $i--) 
    {  
    Write-Progress -id 1 -Activity "Waiting to scrape next page" -SecondsRemaining $i
    Start-Sleep 1
    }
  
}

#Fix the URL's for James C's tool
$ContentURLs = ($ContentURLs -replace "/", "https://gallery.technet.microsoft.com/")

$PostCount = ($ContentURLs.Count)
Write-Log -Message "Found $PostCount Posts, downloading" -severity 2

#Invoke James Cussens Tool.
Write-Log -Message "Starting at post $StartAtPost" -severity 2
$CurrentPost = $StartAtPost
While ($CurrentPost -lt $PostCount)
{
  Write-Progress -Activity Downloading -Status "Post $CurrentPost of $PostCount" -CurrentOperation Scraping -PercentComplete ((($CurrentPost) / $PostCount) * 100)
  Write-Log -Message "Post $CurrentPost of $PostCount" -severity 2
  Write-Log -Message "Downloading Post $($ContentURLs[$CurrentPost])" -severity 2
  .\TechNet-Gallery-to-GitHub-Migrator.ps1 -TechNetURLs ($ContentURLs[$CurrentPost]) -GitHubAccount "OfflineBackup"
  
  #Sleep for 15 seconds to calm google down
    For ($i=15; $i -gt 1; $i--) 
    {  
    Write-Progress -id 1 -Activity "Waiting to download next post" -SecondsRemaining $i
    Start-Sleep 1
    }
  
  $CurrentPost ++
  
}

Write-Log -Message "Script complete, Thank you for saving a piece of Internet history!" -severity 2
