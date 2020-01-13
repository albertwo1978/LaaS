#!/usr/bin/env bash 

targetIP=$1
displaytargetIP=`sed 's/\./_/g' <<< $targetIP`
targetPath=$2
IFS=';' read -ra testLines  <<< $3
numLines=${#testLines[@]} 
echo Got $numLines lines to execute
for (( i=0; i<$numLines; i++ ))   
do 
    curLine=${testLines[$i]}
    echo Parsing $curLine
    IFS=',' read -ra lineParts  <<< $curLine
    numUsers=${lineParts[0]}
    duration=${lineParts[1]}
    throughput=${lineParts[2]}
    ramp=${lineParts[3]}
    curTimeString=`date '+%Y%m%d_%H%M_%S%N'`
    outFile="jmeter_""$displaytargetIP""_""$numUsers""users_""$duration""dur_date""$curTimeString"".csv"
    echo OutFile: $outFile
    tmpDir='/tmp/'
    destDir='/mnt/azure/results/'
    
    if [ $numUsers -eq 0 ] && [ $duration -eq 0 ] && [ $throughput -eq 0 ] && [ $ramp -eq 0 ]
    then
        #TODO - need to add an option for Al's sequential tests
        echo "Special Target: CURLing $numUser $duration $throughput $ramp"
        curl $targetIP/$targetPath -o /mnt/azure/curl$curTimeString.txt
    else
        echo Starting JMeter
        jMeterCmd="jmeter -n -t \"/tmp/main.jmx\" -JnumUsers=$numUsers -JtargetIP=\"$targetIP\" -JthroughputPerMin=$throughput -Jduration=$duration -JoutFile=\"$tmpDir$outFile\" -Jramp=$ramp -Jpath=\"$targetPath\"" 
        #jMeterCmd='cat parameterizedramp.jmx'
        echo $jMeterCmd
        #$jMeterCmd
        eval $jMeterCmd
       fi

done

# Upload to storage
echo 1 second sleep
sleep 1
echo Moving Output
#mv $tmpDir*.csv $destDir
echo Copying to BLOB    
blobToken=`cat /etc/azblob/azblobsas`
az storage blob upload-batch --account-name storannandale -s $tmpDir -d aksjmeter --pattern *.csv --sas-token $blobToken
#sleep 60
echo Signal completion
echo Complete >> /tmp/isdone
