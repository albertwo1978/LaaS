myNamespace='orchestrator'
deployYAML='k8sDefs/kubeorchestrator.yaml'

kubectl delete namespace $myNamespace
kubectl create namespace $myNamespace
kubectl create -n $myNamespace -f $deployYAML

