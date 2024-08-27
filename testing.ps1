# Define necessary variables
$KIBANA_HOST = "http://localhost:5601"
$SERVICE_ACCOUNT_TOKEN = "AAEAAWVsYXN0aWMva2liYW5hL2tpYmFuYS10b2tlbjp5Tm9BcnExcVNJMm5TQi15RkJDajdB"  # Replace with your actual service account token
$FLEET_SERVER_POLICY_ID = "fleet-server-policy"  # Provided policy ID
$MaxRetries = 30  # Maximum number of retries
$DelayBetweenRetries = 5  # Delay between retries in seconds
# Function to check if Kibana is up and running
function Wait-ForKibana {
    $attempt = 0
    $success = $false

    while ($attempt -lt $MaxRetries -and -not $success) {

        try {

            $response = Invoke-RestMethod -Uri "$KIBANA_HOST/api/status" -Method Get -TimeoutSec 5 -ErrorAction Stop
            $jsonResponse = $response | ConvertTo-Json
            $levelStatus = $response.status.overall.level
            if ($levelStatus -eq "green" -or $levelStatus -eq "yellow" -or $levelStatus -eq "available" ) {
                Write-Host "Kibana is up and running."
                $success = $true
            }

        } catch {
            Write-Host "Kibana is not ready yet. Retrying in $DelayBetweenRetries seconds..."
            Start-Sleep -Seconds $DelayBetweenRetries
            $attempt++
        }
    }

    if (-not $success) {
        Write-Host "Kibana did not respond in time. Exiting script."
        Exit 1
    }
}

# Function to generate a Fleet server service token

# Function to create an enrollment token for the Fleet server
function Create-EnrollmentToken {
    param (
        [string]$policyId
    )

    $response = Invoke-RestMethod -Uri "$KIBANA_HOST/api/fleet/enrollment-api-keys" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "kbn-xsrf" = "true"
            "Authorization" = "Bearer $SERVICE_ACCOUNT_TOKEN"
        } `
        -Body (@{ "policy_id" = $policyId } | ConvertTo-Json) `
        -ErrorAction Stop

    return $response.item.api_key
}

# Check if Kibana is up and running before proceeding
Wait-ForKibana

# Generate the Fleet server service token
$FLEET_SERVER_SERVICE_TOKEN = curl -X POST "$KIBANA_HOST/api/fleet/service-tokens" -H "Content-Type: application/json" -H "kbn-xsrf: true" -H "Authorization: Bearer $SERVICE_ACCOUNT_TOKEN"

Write-Host "Generated Fleet Server Service Token: $FLEET_SERVER_SERVICE_TOKEN"

# Create the enrollment token for the Fleet server
$ENROLLMENT_TOKEN = Create-EnrollmentToken -policyId $FLEET_SERVER_POLICY_ID
Write-Host "Created Enrollment Token: $ENROLLMENT_TOKEN"

# Now you can use the tokens to configure and start the Fleet server
Write-Host "Fleet server configuration completed. Use the above tokens to start the Fleet server."
