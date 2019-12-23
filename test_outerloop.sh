#!/usr/bin/env bash
# Testing outer loop

testSubID='33e681ce-910a-44b4-84b8-d07290144803'
testSAName='storannandale'
testContainerName='testcfg'
tempTestDir='temp/testDefs'
echo Start
blobJSON=`az storage blob list -c $testContainerName --account-name $testSAName --subscription $testSubID | jq '.[].name'`

for curBlobName in $blobJSON
do
    cleanBlobName=`sed 's/"//g' <<< $curBlobName` 
    # download the blob to temp
    curBlobDestFile=$tempTestDir/$cleanBlobName
    echo $curBlobDestFile
    az storage blob download --container-name $testContainerName --account-name $testSAName --subscription $testSubID -n $cleanBlobName -f $curBlobDestFile

done

