# Define variables
$KIBANA_HOST="http://localhost:5601"
$ELASTICSEARCH_HOST="http://elasticsearch-service.elk.svc:9200"
$FLEET_SERVER_URL="https://fleet-server.elk.svc:8220"
$SERVICE_ACCOUNT_TOKEN="AAEAAWVsYXN0aWMva2liYW5hL2tpYmFuYS10b2tlbjp1ZGw4R0owclJsT09yeUdRcEtjLUVn"  # Replace with your actual Service Account Token

# Create a JSON payload using a hashtable
$body = @{
    name               = "Fleet Server Policy2"
    description        = "Policy for Fleet Server2"
    namespace          = "default"
    monitoring_enabled = @("logs", "metrics")
    has_fleet_server   = $true
    elasticsearch      = @{
        hosts = @($ELASTICSEARCH_HOST)
    }
    fleet_server_hosts = @($FLEET_SERVER_URL)
}

# Convert hashtable to JSON string
$jsonBody = $body | ConvertTo-Json -Depth 10

# Output JSON for debugging
Write-Output "JSON Body: $jsonBody"

# Make the POST request using Invoke-RestMethod
try {
    $response = Invoke-RestMethod -Uri "$KIBANA_HOST/api/fleet/agent_policies" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "kbn-xsrf"     = "true"
            "Authorization" = "Bearer $SERVICE_ACCOUNT_TOKEN"
        } `
        -Body $jsonBody
    $response
} catch {
    Write-Output "Error: $($_.Exception.Message)"
    if ($_.Exception.Response -ne $null) {
        $errorResponse = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $errorBody = $reader.ReadToEnd()
        Write-Output "Response Body: $errorBody"
    }
}