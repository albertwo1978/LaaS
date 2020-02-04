#!/usr/bin/env bash 
# Testing outer loop

# Debug Settings
doBlobUpdate=1 # 0 = disable
doK8s=1 # 0 = disable
doParallelRuns=1 #0= disable

integerCheck='^[0-9]+$'

testSubID='33e681ce-910a-44b4-84b8-d07290144803'
testSAName='storannandale'
testContainerName='testcfg'
tempTestDir='temp/testDefs'
testMasterName='currentTests.csv'

jmxFile='jmx/main.jmx'
jmxDestFile='/tmp/main.jmx'

payloadScript="payload_script.sh"
payloadDestFile="/tmp/payload_script.sh"

working_dir='k8sDefs'


# Download the Test Definitions from Blob Storage
if [ $doBlobUpdate -ne 0 ] 
then    
    blobToken=`cat /etc/azblob/azblobsas`
    az storage blob download-batch --account-name $testSAName -d $tempTestDir -s $testContainerName --sas-token $blobToken
    #blobJSON=`az storage blob list -c $testContainerName --account-name $testSAName --subscription $testSubID | jq '.[].name'`
    #for curBlobName in $blobJSON
    #do
    #    cleanBlobName=`sed 's/"//g' <<< $curBlobName` 
    #    # download the blob to temp
    #    curBlobDestFile=$tempTestDir/$cleanBlobName
    #    echo $curBlobDestFile
    #    az storage blob download --container-name $testContainerName --account-name $testSAName --subscription $testSubID -n $cleanBlobName -f $curBlobDestFile
    #
    #   done
fi
# Read the Master Test Config
testMasterFile=$tempTestDir/$testMasterName
IFS=$'\n'
masterConfig=`cat $testMasterFile`
for curTestLine in $masterConfig
do
    testParamString=""
    # TODO - ignore first line
    echo $curTestLine
    if [[ $curTestLine == CurTest* ]]
    then
        echo Skipping First Line of Test List
    else
        IFS=',' read -ra curTestArray  <<< $curTestLine
        curTestName=${curTestArray[0],,} 
        curTestEnabled=${curTestArray[1]}
        curTestURL=${curTestArray[2]}
        curTestParam=${curTestArray[3]}
        curTestLoadName=${curTestArray[4]}
        curTestFile=$tempTestDir/$curTestLoadName
        curTestFile=`echo $curTestFile | tr --delete '\r'`  # Windows line endings are the devil

        if [[ $curTestEnabled != TRUE ]]
        then
            echo Skipping Disabled Test
        else

            # Build the script to be injected
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
                    
                        testParamString=$testParamString$numUsers,$duration,$throughputPerMin,$ramp\;


                        
                    fi
                fi
            done
            # Remove the last character (trailing ;)
            testParamString=${testParamString%?}
            echo Test Params: $testParamString
            # Create K8s & Inject script
            if [ $doK8s -ne 0 ]
            then 
                # TODO - check to see if the namespace already exists
                workloadTenant=$curTestName
                # DEBUG

                # Check if job is currently running
                kubectl -n $workloadTenant get pods
                podStatus=`kubectl -n $workloadTenant get pods`
                if [[ $podStatus == *Running* || $podStatus == *Image* ]]
                then
                    echo Job is still running in $workloadTenant
                else 
                    echo No Job in $workloadTenant
                    echo "Namspace $workloadTenant deleting"
                    kubectl delete namespace $workloadTenant

                    echo "Namspace $workloadTenant creating"
                    kubectl create namespace $workloadTenant

                    echo Cloning Secret # TODO - Talk to Al if this is reasonable. Note assumption that there is a secret to clone from. Al says I can do this with permissions across namespaces
                    kubectl get secret azblob -n default -o yaml | sed s/"namespace: default"/"namespace: $workloadTenant"/ | kubectl apply -n $workloadTenant -f -

                    # Create  Master pod details
                    echo "Creating Jmeter Master"
                    kubectl create -n $workloadTenant -f $working_dir/jmeter_master_configmap.yaml

                    kubectl create -n $workloadTenant -f $working_dir/jmeter_master_deploy.yaml


                    #TODO - make this check on the status of master instead of arbitrary...
                    echo Waiting for master pod to be ready
                    sleep 60
                    master_pod=`kubectl get po -n $workloadTenant | grep jmeter-master | awk '{print $1}'`

                    echo Copying payload to master pod
                    # Copy the jmx template to the pod
                    kubectl cp "$jmxFile" -n $workloadTenant "$master_pod:/$jmxDestFile"

                    # Copy the script to the pod
                    kubectl cp "$payloadScript" -n $workloadTenant "$master_pod:/$payloadDestFile"


                    kubectl exec -ti -n $workloadTenant $master_pod -- chmod 755 $payloadDestFile


                    # TODO - Talk to Al about this - should probably be done in the image. Al agrees
                    # Moved to the image
                    #kubectl exec -i -n $workloadTenant $master_pod -- apt-get update
                    #kubectl exec -i -n $workloadTenant $master_pod -- apt install curl -y --fix-missing
                    # Not needed - using Azure Files to upload rather than blob kubectl exec -i -n $workloadTenant $master_pod -- curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

                    # run the script
                    # TODO - Talk to Al about this - it gets messy in the output!
                    curDate=`date '+%Y%m%d_%H%M_%S'`
                    curLogName="/tmp/payloadlog_"$workloadTenant"_"$curDate".txt"
                    if [ $doParallelRuns -ne 0 ] 
                    then
                            cmdToExecute=`kubectl exec -it -n $workloadTenant $master_pod -- nohup $payloadDestFile "$curTestURL" "$curTestParam" "$testParamString" >> $curLogName &`
                    else
                            cmdToExecute=`kubectl exec -it -n $workloadTenant $master_pod --  $payloadDestFile "$curTestURL" "$curTestParam" "$testParamString"`
                    fi
                    echo $cmdToExecute
                    eval $cmdToExecute
                fi
            fi
        fi
    fi


done
echo "Complete - sleeping for 30 seconds"
sleep 30