# kubectl delete -f elasticsearch-configmap.yaml
# kubectl delete -f elasticsearch-secret.yaml
# kubectl delete -f elasticsearch-service.yaml
# kubectl delete -f elasticsearch-deployment.yaml

# kubectl delete -f logstash-configmap.yaml
# kubectl delete -f logstash-service.yaml
# kubectl delete -f logstash-deployment.yaml


kubectl delete -f kibana-config.yaml
kubectl delete -f kibana-deployment.yaml
kubectl delete -f kibana-service.yaml

kubectl delete -f fleet-server-deployment.yaml
kubectl delete -f fleet-server-service.yaml