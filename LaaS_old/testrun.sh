#!/usr/bin/env bash
# Create multiple Jmeter namespaces on an existing kuberntes cluster
# Started On January 23, 2018

working_dir=`pwd`
integerCheck='^[0-9]+$'
jmxFile='jmx/baseline.jmx'
testRunConfig='test_runs/testRunConfig.txt'
jmxRunFile='temp/currentJmxRun.jmx'
jmxTextFile='temp/currentJmxText.txt'
index=0

sed -n -e 'H;${x;s/\n/;;/g;s/^,//;p;}' $testRunConfig > $jmxTextFile
IFS=';;' read -ra configArray <<< $(cat $jmxTextFile)

# Loop through each config and run JMeter set to that config
for newConfig in $configArray
do 
  # Remove whitespaces from string then convert to array
  testRun="$(echo -e "${newConfig}" | tr -d '[:space:]')"
  echo $testRun
  IFS=',' read -ra testArray <<< "$testRun"

  # Feed integer string into jmx file and run test
  if ! [[ ${testArray[0]} =~ $integerCheck && ${testArray[1]} =~ $integerCheck && ${testArray[2]} =~ $integerCheck ]]
  then
    echo "Non-integer input detected. Skipping line." 
  else
    # Script created to launch Jmeter tests directly from the current terminal without accessing the jmeter master pod.
    # It requires that you supply the path to the jmx file

    echo "Loop output"
    echo ${testArray[0]}
    echo ${testArray[1]}
    echo ${testArray[2]}

  fi
done

# Delete jmeter test namespace when complete
