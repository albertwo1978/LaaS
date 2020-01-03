kubectl cp -n koreaignite payload_script.sh jmeter-master-988fc59-dgbv4:tmp/payload_script.sh
kubectl exec -ti -n koreaignite jmeter-master-988fc59-dgbv4 -- chmod 755 /tmp/payload_script.sh
kubectl exec -ti -n koreaignite jmeter-master-988fc59-dgbv4 -- chown root:root /tmp/parameterizedramp.jmx

kubectl exec -ti -n koreaignite jmeter-master-988fc59-dgbv4 -- ./tmp/payload_script.sh "10.0.0.1" "?marco" "1,2,3,4;5,6,7,8;9,10,11,12"
echo done


