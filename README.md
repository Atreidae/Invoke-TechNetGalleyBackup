# Invoke-TechNetGalleyBackup
This is a tool to backup content from the TechNet gallery before it is taken offline.



## Installation
Download Invoke-TechNetGalleyBackup.zip from the releases page and unzip. You will also need to download James Cussens Technet migration tool from here https://www.myteamslab.com/2020/05/technet-gallery-to-github-migration-tool.html

More information is available over <a href="https://www.UcMadScientist.com/technet-is-doomed!-how-to-save-your-favourite-tools-easily/">here</a> 

## Usage
Place both Invoke-TechNetGalleyBackup.ps1 and James Cussens TechNet-Gallery-to-GitHub-Migrator.ps1 in the folder you want to store the archive of the TechNet Gallery.
From a PowerShell window run Invoke-TechNetGalleyBackup.ps1 -Category <Category here>. 
You may need to adjust the category name depending on the URL
2 notes on that

For App-V there is a bug in the TechNet Gallery preventing the page loading when we sort by date, thus nothing is downloaded.

For Enterprise Mobility & Security use "enterprisemobility%2Bsecurity"


## Known Issues

There is currently a bug with James's script and externally hosted images, these will fail if linked to via HTTP. (<a href="https://github.com/jamescussen/TechNet-Gallery-to-GitHub-Migrator/pull/1">See this PR for the fix)

The App-V category currently has an issue were I cant scrape the data when sorting by date. Thus the script doesn't download anything.


There is an issue with non-English characters getting mapped to a mess in the file structure. I've yet to look into this one.
<img src="https://www.UcMadScientist.com/wp-content/uploads/2020/07/image-5-1024x105.png"/>


Some post names cause issues with invalid filenames. I've been meaning to look into it and send James C a PR but that's not super high on the list of tasks at the moment.
<img src="https://www.UcMadScientist.com/wp-content/uploads/2020/07/image-10.png"/>

## Fork me!
This script is free, open source and licensed under the MIT Licence. Feel free to view the source, fork it, raise issues and submit your improvements via pull requests.

