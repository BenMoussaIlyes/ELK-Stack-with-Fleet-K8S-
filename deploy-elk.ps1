$namespace = "elk"
$labelSelector = "app=elasticsearch"
$KibanaconfigMapFile = "kibana-config.yaml"
$FleetconfigMapFile = "fleet-server-config.yaml"

kubectl apply -f elasticsearch-configmap.yaml
kubectl apply -f elasticsearch-secret.yaml
kubectl apply -f elasticsearch-pvc.yaml
kubectl apply -f elasticsearch-service.yaml
kubectl apply -f elasticsearch-deployment.yaml

# Wait for the Elasticsearch pod to be in the running state
Write-Output "Waiting for Elasticsearch pod to be ready..."
while ($true) {
    $podStatus = kubectl get pods -n $namespace -l $labelSelector -o jsonpath="{.items[0].status.conditions[?(@.type=='Ready')].status}"
        if ($podStatus -eq "True") {
        break
    }
    Start-Sleep -Seconds 5
}
$podName = kubectl get pods -n $namespace -l $labelSelector -o jsonpath="{.items[0].metadata.name}"
Write-Output "Elasticsearch pod is ready: $podName"

function Create-Token {
    $tokenOutput = kubectl exec -it $podName -n $namespace -- bin/elasticsearch-service-tokens create elastic/kibana kibana-token 2>&1
    return $tokenOutput
}
function Delete-Token {
    kubectl exec -it $podName -n $namespace -- bin/elasticsearch-service-tokens delete elastic/kibana kibana-token
}
function Extract-Token {
    param (
        [string]$tokenOutput
    )
    if ($tokenOutput -match "SERVICE_TOKEN elastic/kibana/kibana-token = (.+)") {
        return $matches[1].Trim()
    }
    return $null
}

$tokenOutput = Create-Token

if ($tokenOutput -match "ERROR: Service token \[elastic/kibana/kibana-token\] already exists") {
    Write-Host "Token already exists. Deleting the old token."
    Delete-Token
    $tokenOutput = Create-Token
}

$token = $tokenOutput.Trim()
$token = Extract-Token -tokenOutput $tokenOutput

if ($null -eq $token) {
    Write-Error "Failed to extract the token from the output."
    exit 1
}

Write-Host "Token obtained: $token"

$KibanaconfigMapYaml = Get-Content $KibanaconfigMapFile -Raw
$FleetconfigMapYaml = Get-Content $FleetconfigMapFile -Raw

$KibanaconfigMapYaml = $KibanaconfigMapYaml -replace 'elasticsearch.serviceAccountToken: ".*"', "elasticsearch.serviceAccountToken: `"$token`""
$FleetconfigMapYaml = $FleetconfigMapYaml -replace 'KIBANA_SERVICE_TOKEN: ".*"', "KIBANA_SERVICE_TOKEN: `"$token`""

Set-Content $FleetconfigMapFile -Value $FleetconfigMapYaml
Set-Content $KibanaconfigMapFile -Value $KibanaconfigMapYaml



kubectl apply -f kibana-config.yaml
kubectl apply -f kibana-deployment.yaml
kubectl apply -f kibana-service.yaml


kubectl apply -f fleet-server-config.yaml
kubectl apply -f fleet-server-deployment.yaml
kubectl apply -f fleet-server-service.yaml



kubectl apply -f ubuntu-deployment.yaml
kubectl apply -f ubuntu-service.yaml
