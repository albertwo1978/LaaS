#!/usr/bin/env bash
#Create multiple Jmeter namespaces on an existing kuberntes cluster
#Started On January 23, 2018

working_dir=`pwd`
monitoringTenant='jmeter-monitoring'

echo "checking if kubectl is present"

if ! hash kubectl 2>/dev/null
then
    echo "'kubectl' was not found in PATH"
    echo "Kindly ensure that you can acces an existing kubernetes cluster via kubectl"
    exit
fi

kubectl version --short

echo

#Check If namespace exists

kubectl get namespace $monitoringTenant > /dev/null 2>&1

if [ $? -eq 0 ]
then
  echo "Namespace $monitoringTenant already exists, please delete this namespace and rerun this script"
  echo "Current list of namespaces on the kubernetes cluster"
  sleep 2

 kubectl get namespaces | grep -v NAME | awk '{print $1}'
  exit 1
fi

echo

echo "Creating Namespace: $monitoringTenant"

kubectl create namespace $monitoringTenant

echo "Namspace $monitoringTenant has been created"

echo

echo "Number of worker nodes on this cluster is " $nodes

echo

echo "Creating Influxdb and the service"

kubectl create -n $monitoringTenant -f $working_dir/jmeter_influxdb_configmap.yaml

kubectl create -n $monitoringTenant -f $working_dir/jmeter_influxdb_deploy.yaml

kubectl create -n $monitoringTenant -f $working_dir/jmeter_influxdb_svc.yaml

echo "Creating Grafana Deployment"

kubectl create -n $monitoringTenant -f $working_dir/jmeter_grafana_deploy.yaml

kubectl create -n $monitoringTenant -f $working_dir/jmeter_grafana_svc.yaml

echo "Printout Of the $monitoringTenant Objects"

echo

kubectl get -n $monitoringTenant all

## Create jmeter database automatically in Influxdb

echo "Creating Influxdb jmeter Database"

## Sleep to allow time for pods to deploy

sleep 30

## Wait until Influxdb Deployment is up and running
## influxdb_status=`kubectl get po -n $monitoringTenant | grep influxdb-jmeter | awk '{print $2}' | grep Running

influxdb_pod=`kubectl get po -n $monitoringTenant | grep influxdb-jmeter | awk '{print $1}'`
kubectl exec -ti -n $monitoringTenant $influxdb_pod -- influx -execute 'CREATE DATABASE jmeter'

## Create the influxdb datasource in Grafana

echo "Creating the Influxdb data source"
grafana_pod=`kubectl get po -n $monitoringTenant | grep jmeter-grafana | awk '{print $1}'`

## kubectl cp $working_dir/influxdb-jmeter-datasource.json -n $monitoringTenant $grafana_pod:/influxdb-jmeter-datasource.json

kubectl exec -ti -n $monitoringTenant $grafana_pod -- curl 'http://admin:admin@127.0.0.1:3000/api/datasources' -X POST -H 'Content-Type: application/json;charset=UTF-8' --data-binary '{"name":"jmeterdb","type":"influxdb","url":"http://jmeter-influxdb:8086","access":"proxy","isDefault":true,"database":"jmeter","user":"admin","password":"admin"}'