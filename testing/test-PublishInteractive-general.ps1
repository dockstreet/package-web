param($testOutputRoot)
# set-psdebug -strict -trace 0

$script:succeeded = $true
# define all test cases here
function TestGetPathToMSDeploy01 {
    try {
        $expectedMsdeployExe = "C:\Program Files\IIS\Microsoft Web Deploy V2\msdeploy.exe"    
        $actualMsdeployExe = GetPathToMSDeploy
        
        $msg = "TestGetPathToMSDeploy01"
        AssertNotNull $actualMsdeployExe $msg
        AssertEqual $expectedMsdeployExe $actualMsdeployExe
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch{
        $script:succeeded = $false
    }
}

# ExtractZip test cases
function TestExtractZip-Default {
    try {
        # extract the
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SampleZip"

        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        
        $destFolder =  ($destFolder| Resolve-Path).Path
        
        $expectedResults = @("SampleZip",
                             "SampleZip\subfolder01",
                             "SampleZip\subfolder02",
                             "SampleZip\file01.txt",
                             "SampleZip\file02.txt",
                             "SampleZip\subfolder01\file01.txt",
                             "SampleZip\subfolder01\file02.txt",
                             "SampleZip\subfolder02\file01.txt",
                             "SampleZip\subfolder02\file02.txt")
            
        Extract-Zip -zipFilename $zipFile -destination $destFolder
        $extractedItems = Get-ChildItem $destFolder -Recurse
        $actualResults = @()
                
        foreach($item in $extractedItems) {
            $actualResults += $item.FullName.Substring($destFolder.Length + 1)
        }        
        
        AssertNotNull $extractedItems "not-null: extractedItems"
        AssertEqual $expectedResults.Length $actualResults.Length  "$expectedResults.Length $actualResults.Length"
        for($i = 0; $i -lt $expectedResults.Length; $i++) {
            AssertEqual $expectedResults[$i] $actualResults[$i] ("exp-actual loop index {0}" -f $i)
        }
                
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch{
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestExtractZip-ZipDoesntExist {
    $exceptionThrown = $false
    try {
        $destFolder = (Join-Path $testOutputRoot -ChildPath "psout\SampleZip" | Resolve-Path).Path
        # -Intent $Intention.ShouldFail
        $zipFile = "C:\some\non-existing-path\123454545454545.zip"
        Extract-Zip -zipFilename $zipFile -destination $destFolder
    }
    catch {
        $exceptionThrown = $true
        AssertEqual "System.IO.FileNotFoundException" $_.Exception.GetType().FullName "TestExtractZip-ZipDoesntExist exception type check"
    }
    
    AssertEqual $true $exceptionThrown "$true $exceptionThrown"    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

function TestExtractZip-DestDoesntExist {
    $exceptionThrown = $false
    
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = "C:\some\non-existing-path\12345454545454577777d454545\"
        Extract-Zip -zipFilename $zipFile -destination $destFolder
    }
    catch {
        $exceptionThrown = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("destination not found at") "TestExtractZip-DestDoesntExist: checking exception msg"
    }
    
    AssertEqual $true $exceptionThrown "TestExtractZip-DestDoesntExist: $true $exceptionThrown"    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

# GetZipFileForPublishing test cases

function TestGetZipFileForPublishing-1ZipInFolder {
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SampleZip"
        
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        $destFolder =  ($destFolder| Resolve-Path).Path
        
        Copy-Item -Path $zipFile -Destination $destFolder
        
        $zipResult = GetZipFileForPublishing -rootFolder $destFolder
        AssertNotNull $zipResult "TestGetZipFileForPublishing-1ZipInFolder: zipResult"        
        AssertEqual (Get-Item $zipFile).Name $zipResult.Name "TestGetZipFileForPublishing-1ZipInFolder: zipFile.Name zipResult.Name"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestGetZipFileForPublishing-NoZipInFolder {
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleZip.zip" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SomeEmptyFolder"
        
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        $destFolder =  ($destFolder| Resolve-Path).Path
        
        $zipResult = GetZipFileForPublishing -rootFolder $destFolder
    }
    catch {
        AssertEqual $true $_.Exception.Message.ToLower().Contains("no web package (.zip file) found in folder") "TestGetZipFileForPublishing-NoZipInFolder: Exception msg"
    }
    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

# GetTransforms test cases
function TestGetTransforms-TransformsExist {
    try {
        $srcFolder = ((Join-Path $testOutputRoot -ChildPath "test-resources\\transforms" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SomeEmptyFolder"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        
        # copy sample config transforms into that folde
        Get-ChildItem -Path $srcFolder | Copy-Item -Destination $destFolder
        $result = GetTransforms -deployTempFolder $destFolder
        
        $expectedResult = @("Debug",
                            "Prod",
                            "Release",
                            "Test")
        AssertNotNull $result "TestGetTransforms-TransformsExist: result not null"
        AssertEqual $expectedResult.Length $result.Length "TestGetTransforms-TransformsExist: result length"
        for($i=0; $i -lt $expectedResult.Length; $i++){
            AssertEqual $result[$i] $expectedResult[$i] ("TestGetTransforms-TransformsExist: exp-actual loop index [{0}]" -f $i)
        }
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestGetTransforms-TransformsDoNotExist {
    try {
        $srcFolder = ((Join-Path $testOutputRoot -ChildPath "test-resources\\transforms" | Get-Item).FullName | Resolve-Path).Path
        $destFolder = Join-Path $testOutputRoot -ChildPath "psout\SomeEmptyFolder"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $destFolder) {
            Remove-Item -Path $destFolder -Recurse
        }
        New-Item -Path $destFolder -type directory
        
        $result = GetTransforms -deployTempFolder $destFolder
        
        AssertNull $result "TestGetTransforms-TransformsDoNotExist: result is null"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

# GetParametersFromPackage related tests
function TestGetParametersFromPackage-Default {
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleWebPackage-Default.zip" | Get-Item).FullName | Resolve-Path).Path
        $tempFolder = Join-Path $testOutputRoot -ChildPath "psout\TestGetParametersFromPackage-Default"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $tempFolder) {
            Remove-Item -Path $tempFolder -Recurse
        }
        New-Item -Path $tempFolder -type directory

        $parameters = GetParametersFromPackage -packagePath $zipFile -tempPublishFolder $tempFolder
        AssertNotNull $parameters "TestGetParametersFromPackage-Default: parameters not null"
        AssertEqual 2 $parameters.length "TestGetParametersFromPackage-Default: parameters length"
        
        AssertEqual "IIS Web Application Name" $parameters[0].name "TestGetParametersFromPackage-Default: parameter 0 name"
        AssertEqual "Default Web Site/SampleWeb_deploy" $parameters[0].defaultValue "TestGetParametersFromPackage-Default: parameter 0 defaultValue"
        
        AssertEqual "ApplicationServices-Web.config Connection String" $parameters[1].name "TestGetParametersFromPackage-Default: parameter 1 name"
        AssertEqual "data source=.\SQLEXPRESS;Integrated Security=SSPI;AttachDBFilename=|DataDirectory|\aspnetdb.mdf;User Instance=true" $parameters[1].defaultValue "TestGetParametersFromPackage-Default: parameter 1 value"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestGetParametersFromPackage-PackageDoesntExist {
    $raisedException = $false
    
    try {
        $zipFile = "C:\temp\somepath\which\doesnt\exist\foo.zip"
        $tempFolder = Join-Path $testOutputRoot -ChildPath "psout\TestGetParametersFromPackage-PackageDoesntExist"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $tempFolder) {
            Remove-Item -Path $tempFolder -Recurse
        }
        New-Item -Path $tempFolder -type directory
        
        $parameters = GetParametersFromPackage -packagePath $zipFile -tempPublishFolder $tempFolder
    }
    catch {
        $raisedException = $true
        AssertEqual "System.IO.FileNotFoundException" $_.Exception.GetType().FullName "TestGetParametersFromPackage-PackageDoesntExist: exception type check"
    }
    
    AssertEqual $true $raisedException "TestGetParametersFromPackage-PackageDoesntExist: raisedException"
    
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

function TestGetParametersFromPackage-NoValForPackagePath {
    $raisedException = $false
    try {
        $tempFolder = Join-Path $testOutputRoot -ChildPath "psout\TestGetParametersFromPackage-PackageDoesntExist"
        # delete the dest folder and re-create it to ensure there is only 1 zip file
        if(Test-Path $tempFolder) {
            Remove-Item -Path $tempFolder -Recurse
        }
        New-Item -Path $tempFolder -type directory
        $parameters = GetParametersFromPackage -tempPublishFolder $tempFolder
    }
    catch {
        $raisedException = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("packagepath is a required") "TestGetParametersFromPackage-NoValForPackagePath: exception text"
    }
    
    AssertEqual $true $raisedException "TestGetParametersFromPackage-NoValForPackagePath: raisedException"
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

function TestGetParametersFromPackage-NoValForTempFolder {
    $raisedException = $false
    try {
        $zipFile = ((Join-Path $testOutputRoot -ChildPath "test-resources\SampleWebPackage-Default.zip" | Get-Item).FullName | Resolve-Path).Path

        $parameters = GetParametersFromPackage -packagePath $zipFile
    }
    catch {
        $raisedException = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("temppublishfolder is a required") "TestGetParametersFromPackage-NoValForTempFolder: exception text"
    }
    
    AssertEqual $true $raisedException "TestGetParametersFromPackage-NoValForTempFolder: raisedException"
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}


# ConvertTo-PlainText test cases
function TestConvertTo-PlainText {
    try {
        $plainText = "some random string(#99393 here"
        $secureString = ConvertTo-SecureString $plainText -asplaintext -force
        
        $actualResult = ConvertTo-PlainText -secureString $secureString
        AssertEqual $plainText $actualResult "TestConvertTo-PlainText: conversion"
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestConvertTo-PlainText-NoValueForSecureString {
    $raisedException = $false
    
    try {
        ConvertTo-PlainText
        AssertEqual $plainText $actualResult "TestConvertTo-PlainText: conversion"       
    }
    catch {
        $raisedException = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("securestring is a required") "TestConvertTo-PlainText-NoValueForSecureString: exception message"
    }
    
    AssertEqual $true $raisedException "TestConvertTo-PlainText-NoValueForSecureString: raisedException"
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

# CreateSetParametersFile test cases
function TestCreateSetParametersFile-DefaultCase {
    try {
        $allParams = @()
        
        $allParams += @{name="IIS Web Application Name";Value="Default Web Site/TestCreateSetParametersFile"}
        $allParams += @{name="ApplicationServices-Web.config Connection String";value="data source=.\SQLEXPRESS;Integrated Security=SSPI;AttachDBFilename=|DataDirectory|\aspnetdb.mdf;User Instance=true"}
        $allParams += @{name="Custom parameter 01";value="custom parameter 01 value here"}
        
        $tempDirectory = Join-Path $testOutputRoot -ChildPath "psout\TestCreateSetParametersFile"
        if(!(Test-Path $tempDirectory)){
            New-Item -Path $tempDirectory -type directory
        }
        $tempDirectory = Resolve-Path -Path $tempDirectory        
        
        $fileToCreate = Join-Path $tempDirectory -ChildPath "file01.xml"
        if(Test-Path $fileToCreate){ Remove-Item $fileToCreate }        
        
        CreateSetParametersFile -setParametersFilePath $fileToCreate -paramValues $allParams
        
        AssertEqual $true (Test-Path $fileToCreate) "TestCreateSetParametersFile-DefaultCase: file was created"
        # now read file and verify the content
        [xml]$paramXml = Get-Content $fileToCreate
        AssertNotNull $paramXml "TestCreateSetParametersFile-DefaultCase: xml result not null"
        AssertEqual $allParams.length $paramXml.parameters.setParameter.length "TestCreateSetParametersFile-DefaultCase: number of parameters"        
        
        for($i = 0; $i -lt $allParams.length; $i++){
            $expectedName = $allParams[$i].name
            $expectedValue = $allParams[$i].value
            
            $actualName = $paramXml.parameters.setParameter[$i].name
            $actualValue = $paramXml.parameters.setParameter[$i].value
            
            AssertEqual $expectedName $actualName ("TestCreateSetParametersFile-DefaultCase: name check index [{0}]" -f $i)
            AssertEqual $expectedValue $actualValue ("TestCreateSetParametersFile-DefaultCase: value check index [{0}]" -f $i)
        }
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

function TestCreateSetParametersFile-NoSetParamFileValue {
    $exceptionRaised = $false
    try {
        $allParams = @()
        
        $allParams += @{name="IIS Web Application Name";Value="Default Web Site/TestCreateSetParametersFile"}
        $allParams += @{name="ApplicationServices-Web.config Connection String";value="data source=.\SQLEXPRESS;Integrated Security=SSPI;AttachDBFilename=|DataDirectory|\aspnetdb.mdf;User Instance=true"}
        $allParams += @{name="Custom parameter 01";value="custom parameter 01 value here"}
        
        CreateSetParametersFile -paramValues $allParams
    }
    catch {
        $exceptionRaised = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("setParametersFilePath is a required parameter".ToLower()) "TestCreateSetParametersFile-NoSetParamFileValue: exception message"
    }
    
    AssertEqual $true $exceptionRaised "TestCreateSetParametersFile-NoSetParamFileValue: exception check"
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

function TestCreateSetParametersFile-NoParamValuesValue {
    $exceptionRaised = $false
    try {
        $tempDirectory = Join-Path $testOutputRoot -ChildPath "psout\TestCreateSetParametersFile"
        if(!(Test-Path $tempDirectory)){
            New-Item -Path $tempDirectory -type directory
        }
        $tempDirectory = Resolve-Path -Path $tempDirectory        
        
        $fileToCreate = Join-Path $tempDirectory -ChildPath "file01.xml"
        if(Test-Path $fileToCreate){ Remove-Item $fileToCreate }        
        CreateSetParametersFile -setParametersFilePath $fileToCreate
    }
    catch {
        $exceptionRaised = $true
        AssertEqual $true $_.Exception.Message.ToLower().Contains("paramValues is a required parameter".ToLower()) "TestCreateSetParametersFile-NoParamValuesValue: exception message"
    }
    
    AssertEqual $true $exceptionRaised "TestCreateSetParametersFile-NoParamValuesValue: exception check"
    if(!(RaiseAssertions)) { $script:succeeded = $false }
}

# PromptUserForParameterValues test cases
function TestPromptUserForParameterValues-DefaultCase {
    try {
        $pkgParams = @()
        $pkgParams += @{name="IIS Web Application Name";defaultValue="Default Web Site/2893EBF8-94FF-4083-89DF-918377154675"}
        $pkgParams += @{name="ApplicationServices-Web.config Connection String";defaultValue="data source=foo;initial catalog=1D209B80FCF64114BD4FB97216EAC4E4"}
        
        $userParams = @()
        $userParams += @{name="Computer name";value="{C25B9535-1165-418A-A91E-82C72C32FF2E}"}
        $userParams += @{name="Username";value="{766FF0FD-3BF0-4C2D-B4FD-9AF2674B9EA6}"}
        $userParams += @{name="Password";value="{3196F5DB-85FC-484E-A05B-E4C47138E8FF}"}
        $userParams += @{name="Allow untrusted certificate";value="false"}
        $userParams += @{name="whatif";value="false"}
        $userParams += @{name="IIS Web Application Name";value="Default Web Site/8EAF21DD-46D6-4622-8035-8AA2C5AAB8F1"}
        $userParams += @{name="ApplicationServices-Web.config Connection String";value="data source=foo;initial catalog=06D3461A268D4347908AED3505C48253"}
        $userParams += @{name="TransformName";value="release"}
        
        $paramResult = PromptUserForParameterValues -paramValues $pkgParams -paramsFromUser $userParams
        
        AssertNotNull $paramResult "TestPromptUserForParameterValues-DefaultCase"
        # now test the values
        
        # TODO: after fixing the bug https://github.com/sayedihashimi/package-web/issues/8 we should verify length of the result and don't index with [0] below
        # ($paramResult | Where-Object{$_.name -eq "Computer name"})[0]
        $index = 0
        foreach($p in $userParams) {
            $expectedValue = $p.value
            $actualName = ($paramResult | Where-Object{$_.name -eq $p.name})[0].value
            
            # AssertEqual $expectedValue $actualName ("TestPromptUserForParameterValues-DefaultCase: param value check [{0}]" -f $index)
            $index++
        }
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}


# G:\Data\Development\My Code\package-web\OutputRoot\tests\psout\empty
function Test-Template {
    try {
        
        
        
        
        if(!(RaiseAssertions)) { $script:succeeded = $false }
    }
    catch {
        $script:succeeded = $false
        $_.Exception | Write-Error | Out-Null
    }
}

$currentDirectory = split-path $MyInvocation.MyCommand.Definition -parent
# Run the initilization script
& (Join-Path -Path $currentDirectory -ChildPath "setup-testing.ps1")
$global:NonInteractive = $true
# start running test cases
TestExtractZip-Default
TestExtractZip-ZipDoesntExist
TestExtractZip-DestDoesntExist

TestGetZipFileForPublishing-1ZipInFolder
TestGetZipFileForPublishing-NoZipInFolder

TestGetTransforms-TransformsExist
TestGetTransforms-TransformsDoNotExist

TestGetParametersFromPackage-Default
TestGetParametersFromPackage-PackageDoesntExist

TestGetParametersFromPackage-NoValForPackagePath
TestGetParametersFromPackage-NoValForTempFolder

TestConvertTo-PlainText
TestConvertTo-PlainText-NoValueForSecureString

TestCreateSetParametersFile-DefaultCase
TestCreateSetParametersFile-NoSetParamFileValue
TestCreateSetParametersFile-NoParamValuesValue

TestPromptUserForParameterValues-DefaultCase

# Run the tear-down script
& (Join-Path -Path $currentDirectory -ChildPath "teardown-testing.ps1")
ExitScript -succeeded $script:succeeded -sourceScriptFile $MyInvocation.MyCommand.Definition