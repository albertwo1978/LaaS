#!/usr/bin/env bash 
# Testing outer loop

# Debug Settings
doBlobUpdate=0 # 0 = disable
doK8s=0 # 0 = disable


integerCheck='^[0-9]+$'

testSubID='33e681ce-910a-44b4-84b8-d07290144803'
testSAName='storannandale'
testContainerName='testcfg'
tempTestDir='temp/testDefs'
testMasterName='currentTests.csv'

jmxRunFile='temp/currentJmxRun.jmx'
jmxFile='jmx/baseline.jmx'

if [ $doK8s -ne 0 ]
then 
    ./start_jmeterPods.sh
fi

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
IFS=$'\n'
masterConfig=`cat $testMasterFile`
for curTestLine in $masterConfig
do
    # TODO - ignore first line
    echo $curTestLine
    if [[ $curTestLine == CurTest* ]]
    then
        echo Skipping First Line of Test List
    else
        IFS=',' read -ra curTestArray  <<< $curTestLine
        curTestName=${curTestArray[0]}
        curTestEnabled=${curTestArray[1]}
        curTestURL=${curTestArray[2]}
        curTestParam=${curTestArray[3]}
        curTestLoadName=${curTestArray[4]}
        curTestFile=$tempTestDir/$curTestLoadName
        curTestFile=`echo $curTestFile | tr --delete '\r'`  # Windows line endings are the devil
        echo "Reading definition from $curTestFile"

        IFS=$'\n'
        curTestDefText=`cat $curTestFile`
        for curTestDefLine in $curTestDefText
        do
            IFS=',' read -ra testArray <<< "$curTestDefLine"
            numUsers=`echo ${testArray[0]} | tr --delete '\r'`
            duration=`echo ${testArray[1]} | tr --delete '\r'`
            ramp=`echo ${testArray[2]} | tr --delete '\r'`
            
            if [[ $numUsers == NumUsers* ]]
            then
                echo Skipping First Line of Test Def
            else
               

                #DEBUG
                duration=10
                echo $curTestDefLine
            
                # Feed integer string into jmx file and run test
                if ! [[ $numUsers =~ $integerCheck && $duration =~ $integerCheck && $ramp =~ $integerCheck ]]
                then
                    echo "Non-integer input detected. Skipping line." 
                else
                    # Script created to launch Jmeter tests directly from the current terminal without accessing the jmeter master pod.
                    # It requires that you supply the path to the jmx file
                    ((throughputPerMin=$numUsers*60)) 
                    echo $numUsers
                    echo $duration
                    echo $ramp
                    echo $throughputPerMin
                
                


                    sedString="s/{numUsers}/$numUsers/g;s/{duration}/$duration/g;s/{ramp}/$ramp/g;s/{throughputPerMin}/$throughputPerMin/g"
                    
                    
                    echo $sedString

                    sed $sedString $jmxFile > $jmxRunFile

                    test_name="$(basename "$jmxRunFile")"


                    if [ $doK8s -ne 0 ]
                    then 
                        # Get Master pod details

                        kubectl cp "$jmxRunFile" -n $workloadTenant "$master_pod:/$test_name"

                        # Starting Jmeter load test

                        kubectl exec -ti -n $workloadTenant $master_pod -- /bin/bash /load_test "$test_name"
                    fi
                fi
            fi
        done
    fi


done