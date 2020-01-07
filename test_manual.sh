workloadTenant="manual"

jmxFile='jmx/main.jmx'
jmxDestFile='/tmp/main.jmx'

payloadScript="payload_script.sh"
payloadDestFile="/tmp/payload_script.sh"

working_dir='k8sDefs'
echo "Namspace $workloadTenant deleting"
kubectl delete namespace $workloadTenant

echo "Namspace $workloadTenant creating"
kubectl create namespace $workloadTenant
kubectl get secret jmeterlogsecret -o yaml | sed s/"namespace: default"/"namespace: $workloadTenant"/ | kubectl apply -n $workloadTenant -f -
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
