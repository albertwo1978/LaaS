#!/usr/bin/env bash
# Testing outer loop

# Debug Settings
doBlobUpdate=0 # 0 = disable

testSubID='33e681ce-910a-44b4-84b8-d07290144803'
testSAName='storannandale'
testContainerName='testcfg'
tempTestDir='temp/testDefs'
testMasterName='currentTests.csv'


echo Start
blobJSON=`az storage blob list -c $testContainerName --account-name $testSAName --subscription $testSubID | jq '.[].name'`

# Download the Test Definitions from Blob Storage
if [ $doBlobUpdate -ne 0 ] 
then
    for curBlobName in $blobJSON
    do
        cleanBlobName=`sed 's/"//g' <<< $curBlobName` 
        # download the blob to temp
        curBlobDestFile=$tempTestDir/$cleanBlobName
        echo $curBlobDestFile
        az storage blob download --container-name $testContainerName --account-name $testSAName --subscription $testSubID -n $cleanBlobName -f $curBlobDestFile

    done
fi
# Read the Master Test Config
testMasterFile=$tempTestDir/$testMasterName
masterConfig=`cat $testMasterFile`
for curTestLine in $masterConfig
do
    # TODO - ignore first line
    echo $curTestLine
    IFS=',' read -ra curTestArray  <<< $curTestLine
    curTestName=${curTestArray[0]}
    curTestEnabled=${curTestArray[1]}
    curTestURL=${curTestArray[2]}
    curTestParam=${curTestArray[3]}
    curTestLoad=${curTestArray[4]}
    
done