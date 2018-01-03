#*================================================================================================
#* Purpose: Sets the full build number ([major].[minor].[build].[revision]) in a consistent global way 
#* for all builds.  We purposefully only use TeamCity to generate the incrementing [build] number.
#* Set 
#*================================================================================================
Task Set-BuildNumber {

	$major = "1"
	$minor = "0"
	#Get buildCounter passed in from TeamCity, if not use zero
	$build = "0"
	if ($buildCounter -ne "")
	{
		$build = $buildCounter
	}

	#Set sensible defaults for revision and branchName in case we can't determine them
	$revision = "0"
	$branchName = "unknown"
	
	#Get SVN/Git revision, if not use zero
        #SvnRevision.cs.SimpleTemplate simply contains "$WCREV$ $WCURL$" on one line, without speech marks
	exec { & "SubWCRev.exe" "$basePath" "SvnRevision.cs.SimpleTemplate" "SvnRevision.txt" }
	
	if ((Test-Path -path $basePath\SvnRevision.txt )) 
	{
		#Here we're grabbing the SVN repo URL and determining the branch name to stamp against the AssemblyInformationalVersion of each compiled assembly
		$repoInformation = (Get-Content "$basePath\Execview.Web\Properties\SvnRevision.txt" -encoding utf8) -replace "https://example.com:80/svn/repoName/", ""
		$repoInformation = $repoInformation -replace "branches/", ""
		$repoInformationSplit = $repoInformation -split " "
		$splitRevision = $repoInformationSplit[0]
		$spiltBranchName = $repoInformationSplit[1]
		
		if ($splitRevision -ne $null -and $splitRevision -ne "")
		{
			$revision = $splitRevision
		}
		
		if ($spiltBranchName -ne $null -and $spiltBranchName -ne "")
		{
			$branchName = $spiltBranchName
		}
		
		Write-Host "Revision is: $revision"
		Write-Host "BranchName is: $branchName"
	}
	else
	{
		Write-Host "Unable to establish revision number from SVN, using 0"
	}	

	#We always set AssemblyVersion to the Major and Minor build numbers only so as to reduce headaches with referencing assemblies. 
	#See http://stackoverflow.com/questions/64602/what-are-differences-between-assemblyversion-assemblyfileversion-and-assemblyin for more details	
	$assemblyVersion = [string]::Format("{0}.{1}.{2}.{3}", $major, $minor, "0", "0") #AssemblyVersion
	$script:buildNumber = [string]::Format("{0}.{1}.{2}.{3}", $major, $minor, $build, $revision) #AssemblyFileVersion
    $buildNumberInformational = [string]::Format("{0}.{1}.{2}.{3} ({4})", $major, $minor, $build, $revision, $branchName.ToLower()) #AssemblyInformationalVersion
	
	$newAssemblyVersion = 'AssemblyVersion("' + $assemblyVersion + '")'
	$newAssemblyFileVersion = 'AssemblyFileVersion("' + $script:buildNumber + '")'
	$newAssemblyInformationalVersion = 'AssemblyInformationalVersion("' + $($buildNumberInformational.ToLower()) + '")'	
	
	Write-Host "Assembly versioning set as follows.."
	Write-Host "$newAssemblyVersion"
	Write-Host "$newAssemblyFileVersion"
	Write-Host "$newAssemblyInformationalVersion"

        #Could loop through individual AssemblyInfo.cs files here if preferable
	(Get-Content "$basePath\Shared\SharedAssemblyInfo.cs" -encoding utf8) | 
		%{ $_ -replace 'AssemblyVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', $newAssemblyVersion }  | 
		%{ $_ -replace 'AssemblyFileVersion\("[0-9]+(\.([0-9]+|\*)){1,3}"\)', $newAssemblyFileVersion } | 
		%{ $_ -replace 'AssemblyInformationalVersion\("[0-9]+(\.([0-9]+|\*)){1,3}(( )(\(?)*[a-z]*(\)?))?"\)', $newAssemblyInformationalVersion } | Set-Content "$basePath\Shared\SharedAssemblyInfo.cs" -encoding utf8
	
	#Forces TeamCity to use a specific buildNumber (substituting in its build counter as we only use {0} in the TeamCity build number format
	#See http://confluence.jetbrains.com/display/TCD7/Build+Script+Interaction+with+TeamCity#BuildScriptInteractionwithTeamCity-ReportingBuildNumber for more details
	Write-Host "##teamcity[buildNumber '$major.$minor.{build.number}.$revision']"
} 