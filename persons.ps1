$c = $configuration | ConvertFrom-Json
$user = $c.user
$pass = $c.pass
$tenant = $c.tenant
$layout = $c.layout

$uri = "https://$tenant.swp.nl:8800/doc?Function=GetData&Library=Data&SessionToken=$user%3B$pass&Layout=$layout&Parameters=&Type=CSV&Encoding=ANSI"

Write-Verbose -Verbose "Retrieving data from API..."

try {
    $result = Invoke-WebRequest -Method GET -Uri $uri -UseBasicParsing
}
catch {
    Write-Verbose -Verbose "Error retrieving source data, aborting..."
    Write-Verbose -Verbose $_
    exit;
}

$data = $result.content

$csv = ConvertFrom-Csv $data -Delimiter ";"

Write-Verbose -Verbose "Data records converted to CSV: $($csv.Count)"

if ($csv.Count -eq 0) {
    Write-Verbose -Verbose "Empty CSV data, aborting..."
    exit;
}

Write-Verbose -Verbose "Augmenting data..."

$csv | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
$csv | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
$csv | Add-Member -MemberType NoteProperty -Name "NamingConvention" -Value $null -Force
$csv | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
$csv | ForEach-Object {
    $_.ExternalId = $_.Stamnr
    $_.DisplayName = "$($_.FIRSTNAME) $($_.PREFIX) $($_.LASTNAME) ($($_.Stamnr))" -replace "  ", " "
    $_.NamingConvention = "B"

    # Compose contract start/enddate from the study enrollment
    if ([string]::IsNullOrEmpty($_.STUDYPERIOD)) { continue; }
    $studyPeriodYears = $_.STUDYPERIOD.Split("- ")
    $studyStartYear = $studyPeriodYears[0]
    $studyEndYear = $studyPeriodYears[1]

    # Create a 'contract' from the study enrollment data
    $contract = [PSCustomObject]@{
        ExternalId         = $_.Stamnr
        StartDate          = "$studyStartYear/08/01"
        EndDate            = "$studyEndYear/07/31"
        Class              = $_.CLASS
        ProfileCode        = $_.PROFILECODE
        ProfileDescription = $_.PROFILEDESC
        Study              = $_.STUDY
        Location           = $_.LOCATION
        Year               = $_.STUDYYEAR
        MentorCode         = $_.CMENTORCODE
        MentorName         = $_.CMENTORNAME
    }

    $_.Contracts = @($contract)
}

# Skip the first line containing the column headers
$csv = $csv | Where-Object { $_.ExternalId -notlike "*Stamnr" }
$csv = $csv | Sort-Object ExternalId -Unique

Write-Verbose -Verbose "Exporting data..."

$json = $csv | ConvertTo-Json -Depth 10
$json = $json.Replace("Loginaccount.Naam", "Loginaccount_Naam")

Write-Output $json
