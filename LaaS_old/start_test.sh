#!/usr/bin/env bash
#Script created to launch Jmeter tests directly from the current terminal without accessing the jmeter master pod.
#It requires that you supply the path to the jmx file
#After execution, test script jmx file may be deleted from the pod itself but not locally.

working_dir="`pwd`"

#Get namesapce variable
workloadTenant=`awk '{print $NF}' "$working_dir/workloadTenant_export"`

jmx="$1"
[ -n "$jmx" ] || read -p 'Enter path to the jmx file to run ' jmx

if [ ! -f "$jmx" ];
then
    echo "Test script file was not found in PATH"
    echo "Kindly check and input the correct file path"
    exit
fi

test_name="$(basename "$jmx")"

echo $test_name

#Get Master pod details

master_pod=`kubectl get po -n $workloadTenant | grep jmeter-master | awk '{print $1}'`

kubectl cp "$jmx" -n $workloadTenant "$master_pod:/$test_name"

## Echo Starting Jmeter load test

kubectl exec -ti -n $workloadTenant $master_pod -- /bin/bash /load_test "$test_name"