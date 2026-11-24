param([Parameter(Mandatory=$true, Position=0)][string] $InputPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Invoke-Analysis($data) {
    if ($data['shifts'] -isnot [array]) { throw 'Supply a list of shifts' }
    $periods = foreach ($shift in $data.shifts) {
        if ($shift -isnot [array] -or $shift.Count -ne 2) { throw 'A shift needs a start and an end' }
        $from, $until = $shift | ForEach-Object {
            [DateTime]::ParseExact($_, 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture)
        }
        if ($until -le $from) { throw 'A shift must end after it starts' }
        [pscustomobject]@{Start=$from; End=$until}
    }
    $totals = [ordered]@{}
    $previousEnd = $null
    $total = 0L
    foreach ($period in ($periods | Sort-Object Start)) {
        $cursor = $period.Start
        if ($null -ne $previousEnd -and $cursor -lt $previousEnd) { throw 'Shifts overlap' }
        $previousEnd = $period.End
        while ($cursor -lt $period.End) {
            $end = $period.End
            if ($cursor.Date -lt $end.Date) { $end = $cursor.Date.AddDays(1) }
            $date = $cursor.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
            $minutes = [long]($end - $cursor).TotalMinutes
            $totals[$date] = [long]$totals[$date] + $minutes
            $total += $minutes
            $cursor = $end
        }
    }
    $days = @(foreach ($date in $totals.Keys) { [ordered]@{date=$date;minutes=$totals[$date]} })
    return [ordered]@{days=$days;total_minutes=$total}
}

try {
    $payload = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json -AsHashtable
    if ($payload -isnot [System.Collections.IDictionary]) { throw 'Input must be a JSON object' }
    Invoke-Analysis $payload | ConvertTo-Json -Depth 30 -Compress
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 2
}
