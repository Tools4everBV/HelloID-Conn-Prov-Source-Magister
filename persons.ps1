#####################################################
# HelloID-Conn-Prov-Source-Magister-Students
#
# Version: 2.0.0
#####################################################

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$c = $configuration | ConvertFrom-Json

$baseUri = $c.BaseUrl
$username = $c.Username
$password = $c.Password
$layout = $c.Layout

$uri = "$baseUri/doc?Function=GetData&Library=Data&SessionToken=$username%3B$password&Layout=$layout&Parameters=&Type=CSV&Encoding=ANSI"

# Set debug logging
switch ($($c.isDebug)) {
        $true { $VerbosePreference = 'Continue' }
        $false { $VerbosePreference = 'SilentlyContinue' }
}

Write-Information "Start person import: Base URL: [$baseUri], Using username: $username"

#region functions
function Resolve-HTTPError {
        [CmdletBinding()]
        param (
                [Parameter(Mandatory,
                        ValueFromPipeline
                )]
                [object]$ErrorObject
        )
        process {
                $httpErrorObj = [PSCustomObject]@{
                        FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
                        MyCommand             = $ErrorObject.InvocationInfo.MyCommand
                        RequestUri            = $ErrorObject.TargetObject.RequestUri
                        ScriptStackTrace      = $ErrorObject.ScriptStackTrace
                        ErrorMessage          = ''
                }
                if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
                        $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
                }
                elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
                        $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                }
                Write-Output $httpErrorObj
        }
}
#endregion functions

#region query persons
try {    
        Write-Verbose "Querying Persons"

        $result = Invoke-WebRequest -Method GET -Uri $uri -UseBasicParsing
        $data = $result.content

        $persons = ConvertFrom-Csv $data -Delimiter ";"    

        Write-Information "Succesfully queried Persons. Result count: $($persons.count)"

        # test single student:
        # $persons = $persons | where-object stamnr -eq '<stamnr student>'
        # Write-verbose -verbose "$($persons | convertto-json)"

        if ($persons.Count -eq 0) {
                throw "Empty Persons data, aborting..."
        }
}
catch {
        $ex = $PSItem
        if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
                $errorObject = Resolve-HTTPError -Error $ex

                $verboseErrorMessage = $errorObject.ErrorMessage

                $auditErrorMessage = $errorObject.ErrorMessage
        }

        # If error message empty, fall back on $ex.Exception.Message
        if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
                $verboseErrorMessage = $ex.Exception.Message
        }
        if ([String]::IsNullOrEmpty($auditErrorMessage)) {
                $auditErrorMessage = $ex.Exception.Message
        }

        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"        
        throw "Could not query Persons. Error: $auditErrorMessage"
}
#endregion query persons

#region query enhancing and exporting person
try {
        Write-Verbose 'Enhancing and exporting person objects to HelloID'

        $employments = $persons | Group-Object Stamnr -AsHashTable

        $persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
        $persons | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
        $persons | Add-Member -MemberType NoteProperty -Name "NamingConvention" -Value $null -Force
        $persons | Add-Member -MemberType NoteProperty -Name "PersonType" -Value $null -Force
        $persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
        $persons | ForEach-Object {
                $_.ExternalId = $_.Stamnr
                $_.DisplayName = "$($_.FIRSTNAME) $($_.PREFIX) $($_.LASTNAME) ($($_.Stamnr))" -replace "  ", " "
                $_.NamingConvention = "B"
                $_.PersonType = "Leerling"

                $contracts = [System.Collections.ArrayList]::new()
                $personEmployments = $employments[$_.Stamnr]

                foreach ($personEmployment in $personEmployments) {
                        # Compose contract start/enddate from the study enrollment
                        if (![string]::IsNullOrEmpty($personEmployment.STUDYPERIOD)) { 

                                # Select Mentor with preference for CMentor
                                if ([string]::IsNullOrEmpty($personEmployment.CMENTORCODE)) {
                                        $mentorCode = $personEmployment.PMENTORCODE
                                        $mentorName = $personEmployment.PMENTORNAME
                                }
                                else {
                                        $mentorCode = $personEmployment.CMENTORCODE
                                        $mentorName = $personEmployment.CMENTORNAME
                                }
                                $contract = [PSCustomObject]@{
                                        ExternalId         = "$($personEmployment.Stamnr)_$($personEmployment.STUDYPERIOD)_$($personEmployment.CLASS)_$($personEmployment.PROFILECODE)_$($personEmployment.studiebegindatum)"
                                        StartDate          = $personEmployment.studiebegindatum
                                        EndDate            = $personEmployment.studieeinddatum
                                        Class              = $personEmployment.CLASS
                                        ProfileCode        = $personEmployment.PROFILECODE
                                        ProfileDescription = $personEmployment.PROFILEDESC
                                        Study              = $personEmployment.STUDY
                                        Location           = $personEmployment.LOCATION
                                        Year               = $personEmployment.STUDYYEAR
                                        StudyPeriod        = $personEmployment.STUDYPERIOD
                                        MentorCode         = $mentorCode
                                        MentorName         = $mentorName
                                }
                                
                                [void]$contracts.Add($contract)                              
                        }
                        else {
                            write-warning "Stamnr $($_.Stamnr) has no STUDYPERIOD"
                        }       
                }
                $_.Contracts = $contracts
        }
        
        $persons = $persons | Select-Object -Property ExternalId, DisplayName, NamingConvention, Stamnr, INITIALS, FIRSTNAME, PREFIX, LASTNAME, Email, GENDER, BIRTHDATE, STREET, HOUSENR, HOUSENRSUFIX, POSTALCODE, CITY, Loginaccount.Naam, email_1, Mobiel_nr, Contracts
                 
        # Skip the first line containing the column headers
        $persons = $persons | Where-Object { $_.ExternalId -notlike "*Stamnr" }
        # Remove duplicate persons
        $persons = $persons | Sort-Object ExternalId -Unique

        # Sanitize and export the json
        $output =  $persons | ConvertTo-Json -Depth 10
        $output = $output.Replace("Loginaccount.Naam", "Loginaccount_Naam")

        Write-Output $output
 
        Write-Information "Succesfully enhanced and exported person objects to HelloID. Result count: $($persons.count)"
        Write-Information "Person import completed"
}
catch {
        $ex = $PSItem
        if ( $($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
                $errorObject = Resolve-HTTPError -Error $ex

                $verboseErrorMessage = $errorObject.ErrorMessage

                $auditErrorMessage = $errorObject.ErrorMessage
        }

        # If error message empty, fall back on $ex.Exception.Message
        if ([String]::IsNullOrEmpty($verboseErrorMessage)) {
                $verboseErrorMessage = $ex.Exception.Message
        }
        if ([String]::IsNullOrEmpty($auditErrorMessage)) {
                $auditErrorMessage = $ex.Exception.Message
        }

        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($verboseErrorMessage)"        
        throw "Could not enhance and export person objects to HelloID. Error: $auditErrorMessage"
}
#endregion query enhancing and exporting person