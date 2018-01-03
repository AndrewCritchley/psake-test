#This build assumes the following directory structure
#
#  \Build          - This is where the project build code lives
#  \BuildArtifacts - This folder is created if it is missing and contains output of the build
#  \Code           - This folder contains the source code or solutions you want to build
#

## REFERENCES:
## http://www.trycatchfail.com/2011/06/24/building-and-publishing-nuget-packages-with-psake/


Properties {
    $build_dir = Split-Path $psake.build_script_file
    $build_artifacts_dir = "$build_dir\..\BuildArtifacts\"
    $code_dir = "$build_dir\..\Code"
	$nuspecFiles = @( 'HelloPsake.Utilities\HelloPsake.Utilities.nuspec' )
	$build_number = "99.0.0.0"
}

FormatTaskName (("-"*25) + "[{0}]" + ("-"*25))

Task Default -Depends BuildHelloWorld

Task BuildHelloWorld -Depends Clean, Build, Pack

Task Build -Depends Clean {
    Write-Host "Building HelloPsake.sln" -ForegroundColor Green
   # Exec { msbuild "$code_dir\HelloPsake\HelloPsake.sln" /t:Build /p:Configuration=Release /v:quiet /p:OutDir=$build_artifacts_dir }
   Exec { msbuild "$code_dir\HelloPsake\HelloPsake.sln" /t:Build /p:Configuration=Release /v:quiet }
}

Task Clean {
    Write-Host "Creating BuildArtifacts directory" -ForegroundColor Green
    if (Test-Path $build_artifacts_dir)
    {
        rd $build_artifacts_dir -rec -force | out-null
    }

    mkdir $build_artifacts_dir | out-null

    Write-Host "Cleaning HelloPsake.sln" -ForegroundColor Green
    Exec { msbuild "$code_dir\HelloPsake\HelloPsake.sln" /t:Clean /p:Configuration=Release /v:quiet }
}

Task Pack -Depends Build {
Write-Warning $build_number
	$filename = $nuspecFiles[0]
	$nuspecFileName = "$code_dir\HelloPsake\$filename"
	$libraryOutputDirectory = "$code_dir\NugetPackages\Libraries"
    $Spec = [xml](get-content "$NuSpecFileName")
    $Spec.package.metadata.version = ([string]$Spec.package.metadata.version).Replace("{Version}",$build_number)
    $Spec.Save("$NuSpecFileName")

    exec { nuget pack "$NuSpecFileName" -OutputDirectory $libraryOutputDirectory }
}

task Publish -depends Pack {
    $PackageName = gci *.nupkg
    #We don't care if deleting fails..
    nuget delete $NuGetPackageName $Version -NoPrompt
    exec { nuget push $PackageName }
}