<#
  .SYNOPSIS
    This module contains functions for working with the PowerSchool API in PowerShell
  
  .DESCRIPTION
    
  .LINK
    https://support.powerschool.com/developer/#/
  .NOTES
    Authors: Charles Crossan
  
  .VERSION 
    1.0.1

#>

function Connect-PowerSchoolService {
<#

.PARAMETER Username
    ClientID for OAUTH pplugin
.PARAMETER Password
    $password = ConvertTo-SecureString –String "password" –AsPlainText -Force

#>
    param (
        [parameter(Mandatory=$true)]
        [String]
        $ClientID,
        [String]
        $ClientSecret,
        [String]
        $PowerSchoolURL
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Content-Type", 'application/x-www-form-urlencoded;charset=UTF-8')
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientID,$ClientSecret)))

    $headers.add("Authorization","Basic $base64AuthInfo")

    $body = "grant_type=client_credentials"

    $Response = Invoke-RestMethod -Uri $PowerSchoolURL"/oauth/access_token" -Method Post -Headers $headers -Body $body

    Set-Variable -Scope Global -Name "PowerSchoolURL" -Value $PowerSchoolURL
    Set-Variable -Scope Global -Name "PowerSchoolAccessToken" -Value $Response.access_token
    Set-Variable -Scope Global -Name "PowerSchoolAccessTokenExpiration" -Value $(Get-Date).AddSeconds($Response.expires_in)
}

function Invoke-PowerSchoolRESTMethod {
    param(
        $EndpointURL,
        $Method,
        $PageNumber=0,
        $PageSize=0,
        $Body = $null
    )

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.add("Authorization","Bearer $($(Get-Variable -Name "PowerSchoolAccessToken").Value)")
    $headers.Add("Accept", 'application/json')
    $headers.Add("Content-Type",'application/json')
    if($PageNumber -gt 0)
    {
        if ($EndpointURL.Contains("?"))
        {
           $EndpointURL +="&page=$PageNumber"
        }
        else {
             $EndpointURL +="?page=$PageNumber"
        }
    }
    if ($PageSize -lt 100 -and $PageSize -gt 0)
    {
        if ($EndpointURL.Contains("?"))
        {
           $EndpointURL +="&pagesize=$PageSize"
        }
    }
    
    $uri ="$($(Get-Variable -Name 'PowerSchoolURL').value)$($EndpointURL)"
    Write-Host $uri
    Write-Host $Body
    $Response = Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -Body $Body
    $Response
}

function Get-PowerSchoolRecordCount {
    param(
        $EndpointURL
    )
    $split = $EndpointURL.split('?')
    $URL = "$($split[0])/count?$($split[1])"
    Invoke-PowerSchoolRESTMethod -EndpointURL $URL  -Method "GET" | Select-Object -ExpandProperty Resource | Select-Object -ExpandProperty Count

}

function Get-PowerSchoolAttendanceRecords {
    param(
        $Date = $(get-date),
        $AttendanceCodes = "1"
    )

    $attendanceRecords = @()
    $postBody = '{ "date": "11-29-2016" }'
    $pageCounter = 0
    $hasMore = $true
    While ( $hasMore )
    {

        $qr = Execute-PowerSchoolPowerQuery -queryName "org.bucksiu.powershellpowerschool.api.dailyattendance" -PageNumber $pageCounter -postBody $postBody
        $qr
        break
        if ($qr.record.count -lt 100)
        {
            $hasMore = $false
        }   
        Foreach ($attendanceRecord in $qr.record)
        {
            $attendanceRecords += $attendanceRecord.tables.students
        } 
        $pageCounter +=1
    }

}

function Get-PowerSchoolStudents {
    <#

    .LINK
        https://support.powerschool.com/developer/#/page/student-resources
    .LINK
        https://support.powerschool.com/developer/#/page/data-dictionary#student
    .LINK
        https://support.powerschool.com/developer/#studentextensionresource

    #>
   param(
       [int16]
       $MaxResults=0,
       [int16]
       $SchoolID = 3,
       [String[]]
       $EnrollmentStatus = @("A","P"),
       [String[]]
       $Expansions = @("demographics","addresses","alerts","phones","school_enrollment","ethnicity_race","contact","contact_info","initial_enrollment","schedule_setup","fees", "lunch"),
       [String[]]
       $Extensions=@("s_pa_stu_x","s_stu_crdc_x","c_studentlocator","s_stu_ncea_x","studentcorefields"),
       [Switch]
       $UseQuery,
       [string]
       $QueryName = "org.bucksiu.powershellpowerschool.api.students"
   )

   $studentResults = @()
   if( $UseQuery )
   {
        $pageCounter = 0
        $hasMore = $true
        While ( $hasMore )
        {

            $qr = Execute-PowerSchoolPowerQuery -queryName $QueryName -PageNumber $pageCounter
            if ($qr.record.count -lt 100)
            {
                $hasMore = $false
            }   
            Foreach ($Student in $qr.record)
            {
                $studentResults += $student.tables.students
            } 
            $pageCounter +=1
        }
           

   }
   else {
    $URL = "/ws/v1/district/student?q=school_enrollment.enroll_status==($($EnrollmentStatus -join ','))"
    if ($Expansions.count -gt 0)
    { 
        $URL ="$URL&expansions=$($Expansions -join ',')"
    }
    if ($Extensions.count -gt 0)
    {
        $URL ="$URL&extensions=$($Extensions -join ',')"
    }
    $count = Get-PowerSchoolRecordCount -EndpointURL $URL    
    $pageCounter = 0
    While ( $studentResults.Count -lt $count)
    {
        $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
        Foreach ($student in $response.students.student)
        {
            $studentResults += $student
        }
        $pageCounter +=1
    }
   }
    $studentResults
}

function Get-PowerSchoolDatabaseTables {
    $URL = "/ws/schema/table"
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    $response
}

Function Get-PowerSchoolTableSchema {
    param(
        $tableName
    )
    $URL = "/ws/schema/table/$tableName/metadata"
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    $response

}

function Get-PowerSchoolTableRecord {
    param(
        $tableName,
        $id,
        [string[]]
        $columns=@("*")
    )
    $URL = "/ws/schema/table/$tableName/$($id)?projection=$($columns -join ',')"
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    $response
}

function Get-PowerSchoolCourses {
    param(
        $SchoolID= 3,
        [String[]]
       $Extensions=@("s_pa_crs_x","s_crs_crdc_x")
    )
    $URL = "/ws/v1/school/$SchoolId/course"
    if ($Extensions.count -gt 0)
    {
        $URL ="$($URL)?extensions=$($Extensions -join ',')"
    }
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "GET" -PageNumber $pageCounter -PageSize $MaxResults
    $response
}


function Execute-PowerSchoolPowerQuery {
    <#
        .LINK
            https://support.powerschool.com/developer/#/page/powerqueries
    #>
    param (
        $queryName,
        $PageNumber=0,
        $postBody
    )
     $URL = "/ws/schema/query/$queryName"
    $response = Invoke-PowerSchoolRESTMethod -EndpointURL $URL -Method "POST" -PageNumber $PageNumber -Body $postBody
    $response
}