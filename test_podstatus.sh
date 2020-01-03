kubectl -n azcatsynthappbaseline get pods
podStatus=`kubectl -n azcatsynthappbaseline get pods`
if [[ $podStatus == *Running* ]]
then
    echo Yes
else
    echo No
fi
echo 'Done'
