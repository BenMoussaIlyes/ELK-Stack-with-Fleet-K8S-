
kubectl delete all --all -n elk --force
kubectl delete configmaps --all -n elk --force
kubectl delete secrets --all -n elk --force
kubectl delete pvc --all -n elk --force
kubectl delete pv --all -n elk --force
kubectl delete ingress --all -n elk --force
kubectl delete pods --all -n elk --force
kubectl delete deployment --all -n elk --force