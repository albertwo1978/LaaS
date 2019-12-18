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

echo "checking if kubectl is present"

if ! hash kubectl 2>/dev/null
then
    echo "'kubectl' was not found in PATH"
    echo "Kindly ensure that you can acces an existing kubernetes cluster via kubectl"
    exit
fi

kubectl version --short

echo "Current list of namespaces on the kubernetes cluster:"

echo

kubectl get namespaces | grep -v NAME | awk '{print $1}'

echo

echo "Enter the name of the new tenant unique name, this will be used to create the namespace"
read workloadTenant
echo

# Check If namespace exists

kubectl get namespace $workloadTenant > /dev/null 2>&1

if [ $? -eq 0 ]
then
  echo "Namespace $workloadTenant already exists, please select a unique name"
  echo "Current list of namespaces on the kubernetes cluster"
  sleep 2

 kubectl get namespaces | grep -v NAME | awk '{print $1}'
  exit 1
fi

echo
echo "Creating Namespace: $workloadTenant"

kubectl create namespace $workloadTenant

echo "Namspace $workloadTenant has been created"

echo

echo "Creating Jmeter slave nodes"

nodes=`kubectl get no | egrep -v "master|NAME" | wc -l`

echo

echo "Number of worker nodes on this cluster is " $nodes

echo

echo "Creating $nodes Jmeter slave replicas and service"

echo

kubectl create -n $workloadTenant -f $working_dir/jmeter_slaves_deploy.yaml

kubectl create -n $workloadTenant -f $working_dir/jmeter_slaves_svc.yaml

echo "Creating Jmeter Master"

kubectl create -n $workloadTenant -f $working_dir/jmeter_master_configmap.yaml

kubectl create -n $workloadTenant -f $working_dir/jmeter_master_deploy.yaml

echo "Printout Of the $workloadTenant Objects"

echo

kubectl get -n $workloadTenant all

echo namespace = $workloadTenant > $working_dir/workloadTenant_export

## Make load test script in Jmeter master pod executable

echo 

echo "Configuring load test settings in Master"

sleep 30

# Get Master pod details

master_pod=`kubectl get po -n $workloadTenant | grep jmeter-master | awk '{print $1}'`

#kubectl exec -ti -n $workloadTenant $master_pod -- cp -r /load_test /jmeter/load_test

#kubectl exec -ti -n $workloadTenant $master_pod -- chmod 755 /jmeter/load_test

sed -n -e 'H;${x;s/\n/;;/g;s/^,//;p;}' $testRunConfig > $jmxTextFile
IFS=';;' read -ra configArray <<< $(cat $jmxTextFile)

# Loop through each config and run JMeter set to that config
for newConfig in $configArray
do 
  # Remove whitespaces from string then convert to array
  testRun="$(echo -e "${newConfig}" | tr -d '[:space:]')"
  IFS=',' read -ra testArray <<< "$testRun"

  # Feed integer string into jmx file and run test
  if ! [[ ${testArray[0]} =~ $integerCheck && ${testArray[1]} =~ $integerCheck && ${testArray[2]} =~ $integerCheck ]]
  then
    echo "Non-integer input detected. Skipping line." 
  else
    # Script created to launch Jmeter tests directly from the current terminal without accessing the jmeter master pod.
    # It requires that you supply the path to the jmx file

    ((throughputPerMin=${testArray[0]}*60))

    sed "s/{numUsers}/${testArray[0]}/g;s/{duration}/${testArray[1]}/g;s/{ramp}/${testArray[2]}/g;s/{throughputPerMin}/$throughputPerMin/g" $jmxFile > $jmxRunFile

    test_name="$(basename "$jmxRunFile")"

    # Get Master pod details

    kubectl cp "$jmxRunFile" -n $workloadTenant "$master_pod:/$test_name"

    # Starting Jmeter load test

    kubectl exec -ti -n $workloadTenant $master_pod -- /bin/bash /load_test "$test_name"
  fi
done

# Delete jmeter test namespace when complete

sleep 30

kubectl delete namespace $workloadTenant