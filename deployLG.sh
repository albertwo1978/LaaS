myNamespace='orchestrator'
accountYAML='k8sDefs/kubeorchestratoraccount.yaml'
deployYAML='k8sDefs/kubeorchestrator.yaml'

kubectl delete namespace $myNamespace
kubectl create namespace $myNamespace
kubectl delete clusterrolebinding overseer
kubectl create -n $myNamespace -f $accountYAML
kubectl create -n $myNamespace -f $deployYAML
