$namespace = "elk"
$labelSelector = "app=elasticsearch"
$KibanaconfigMapFile = "kibana-config.yaml"
$FleetconfigMapFile = "fleet-server-config.yaml"

function Create-Token {
    param (
        [string]$tokenType  # Accepts either "kibana" or "fleet"
    )
    switch ($tokenType) {
        "kibana" { $tokenOutput = kubectl exec -it $podName -n $namespace -- bin/elasticsearch-service-tokens create elastic/kibana kibana-token  }
        "fleet" { $tokenOutput = kubectl exec -it $podName -n $namespace -- bin/elasticsearch-service-tokens create elastic/fleet-server fleet-server-token  }
        default { throw "Invalid token type specified. Use 'kibana' or 'fleet'." }
    }
    Write-Host $tokenPath
    return $tokenOutput
}
function Delete-Token {
    param (
        [string]$tokenType  # Accepts either "kibana" or "fleet"
    )
    switch ($tokenType) {
        "kibana" { kubectl exec -it $podName -n $namespace -- bin/elasticsearch-service-tokens delete elastic/kibana kibana-token }
        "fleet" { kubectl exec -it $podName -n $namespace -- bin/elasticsearch-service-tokens delete elastic/fleet-server fleet-server-token }
        default { throw "Invalid token type specified. Use 'kibana' or 'fleet'." }
    }
}
function Extract-Token {
    param (
        [string]$tokenOutput,
        [string]$tokenType  # Accepts either "kibana" or "fleet"
    )
    switch ($tokenType) {
        "kibana" { $pattern = "SERVICE_TOKEN elastic/kibana/kibana-token = (.+)" }
        "fleet" { $pattern = "SERVICE_TOKEN elastic/fleet-server/fleet-server-token = (.+)" }
        default { throw "Invalid token type specified. Use 'kibana' or 'fleet'." }
    }
    if ($tokenOutput -match $pattern) {
        return $matches[1].Trim()
    }
    return $null
}


kubectl apply -f elasticsearch-configmap.yaml
kubectl apply -f elasticsearch-secret.yaml
kubectl apply -f elasticsearch-pvc.yaml
kubectl apply -f elasticsearch-service.yaml
kubectl apply -f elasticsearch-deployment.yaml

Write-Output "Waiting for Elasticsearch pod to be ready..."
while ($true) {
    $podStatus = kubectl get pods -n $namespace -l $labelSelector -o jsonpath="{.items[0].status.conditions[?(@.type=='Ready')].status}"
        if ($podStatus -eq "True") {
        break
    }
    Start-Sleep -Seconds 1
}
$podName = kubectl get pods -n $namespace -l $labelSelector -o jsonpath="{.items[0].metadata.name}"
Write-Output "Elasticsearch pod is ready: $podName"

$tokenOutput = Create-Token -tokenType "kibana"

if ($tokenOutput -like "*already exists*") {
    Write-Host "Token already exists. Deleting the old token."
    Delete-Token  -tokenType "kibana"
    $tokenOutput = Create-Token  -tokenType "kibana"
}
Write-Host $tokenOutput
$token = $tokenOutput.Trim()
$token = Extract-Token -tokenOutput $tokenOutput  -tokenType "kibana"

if ($null -eq $token) {
    Write-Error "Failed to extract the token from the output."
    exit 1
}

Write-Host "Kibana Token obtained: $token"

$KibanaconfigMapYaml = Get-Content $KibanaconfigMapFile -Raw
$FleetconfigMapYaml = Get-Content $FleetconfigMapFile -Raw

$KibanaconfigMapYaml = $KibanaconfigMapYaml -replace 'elasticsearch.serviceAccountToken: ".*"', "elasticsearch.serviceAccountToken: `"$token`""
$FleetconfigMapYaml = $FleetconfigMapYaml -replace 'KIBANA_SERVICE_TOKEN: ".*"', "KIBANA_SERVICE_TOKEN: `"$token`""

Set-Content $FleetconfigMapFile -Value $FleetconfigMapYaml
Set-Content $KibanaconfigMapFile -Value $KibanaconfigMapYaml


kubectl apply -f kibana-config.yaml
kubectl apply -f kibana-deployment.yaml
kubectl apply -f kibana-service.yaml

$tokenOutput = Create-Token -tokenType "fleet"
Write-Host $tokenOutput
if ($tokenOutput -like "*already exists*") {
    Write-Host "Token already exists. Deleting the old token."
    Delete-Token  -tokenType "fleet"
    $tokenOutput = Create-Token  -tokenType "fleet"
}

$token = $tokenOutput.Trim()
$token = Extract-Token -tokenOutput $tokenOutput  -tokenType "fleet"

if ($null -eq $token) {
    Write-Error "Failed to extract the token from the output."
    exit 1
}

Write-Host "Fleet Token obtained: $token"


$FleetconfigMapYaml = $FleetconfigMapYaml -replace 'FLEET_SERVER_SERVICE_TOKEN: ".*"', "FLEET_SERVER_SERVICE_TOKEN: `"$token`""

Set-Content $FleetconfigMapFile -Value $FleetconfigMapYaml


kubectl apply -f fleet-server-config.yaml
kubectl apply -f fleet-server-deployment.yaml
kubectl apply -f fleet-server-service.yaml



kubectl apply -f ubuntu-deployment.yaml
kubectl apply -f ubuntu-service.yaml

Start-Sleep -Seconds 1
kubectl get pods --namespace elk -o wide