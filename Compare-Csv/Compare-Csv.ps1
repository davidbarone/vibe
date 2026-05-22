Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

enum DataTypeEnum {
    BOOLEAN  = 1
    INTEGER  = 2
    DECIMAL  = 3
    DATETIME = 5
    STRING   = 6
}

enum CompareTypeEnum {
    KEY_LEFT_ONLY  = 4
    KEY_RIGHT_ONLY = 5
    DIFFERENT      = 6
}

class SchemaComparisonResult {
    [string]      $ColumnName
    [DataTypeEnum]$LeftType
    [DataTypeEnum]$RightType

    SchemaComparisonResult([string]$columnName, [DataTypeEnum]$leftType, [DataTypeEnum]$rightType) {
        $this.ColumnName = $columnName
        $this.LeftType   = $leftType
        $this.RightType  = $rightType
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $oldColor = $Host.UI.RawUI.ForegroundColor
    try {
        $Host.UI.RawUI.ForegroundColor = 'Cyan'
        Write-Host $Message
    }
    finally {
        $Host.UI.RawUI.ForegroundColor = $oldColor
    }
}

function Parse-List {
<#
.SYNOPSIS
Parses a delimited string into a string array.

.DESCRIPTION
Takes a string input that represents a set of values delimited by a character.
Returns an array in all cases, including empty or single-value inputs.

.PARAMETER Value
The input string.

.PARAMETER Delimiter
The delimiter character. Defaults to ','.

.OUTPUTS
String[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $false)]
        [string]$Delimiter = ','
    )

    Write-Log "BEGIN Parse-List"
    try {
        if ([string]::IsNullOrWhiteSpace($Value)) {
            return @()
        }

        if ($Value -notlike "*$Delimiter*") {
            return @($Value)
        }

        return @($Value.Split($Delimiter))
    }
    finally {
        Write-Log "END Parse-List"
    }
}

function Test-Path {
<#
.SYNOPSIS
Validates that a file exists.

.DESCRIPTION
Checks that the file at the specified path exists. Throws if it does not.

.PARAMETER Path
The path of the file.

.OUTPUTS
Boolean
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Write-Log "BEGIN Test-Path"
    try {
        if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $Path)) {
            throw "The file: $Path does not exist!"
        }
        return $true
    }
    finally {
        Write-Log "END Test-Path"
    }
}

function Read-Csv {
<#
.SYNOPSIS
Reads a CSV file.

.DESCRIPTION
Uses Import-Csv to read a CSV file into an array of PSCustomObject.

.PARAMETER Path
The path to the CSV file.

.PARAMETER Delimiter
The delimiter character. Defaults to ','.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [string]$Delimiter = ','
    )

    Write-Log "BEGIN Read-Csv"
    try {
        $data = Import-Csv -LiteralPath $Path -Delimiter $Delimiter -Encoding utf8
        if (-not $data -or $data.Count -eq 0) {
            throw 'Csv file contains no data!'
        }
        return @($data)
    }
    finally {
        Write-Log "END Read-Csv"
    }
}

function Concatenate-Values {
<#
.SYNOPSIS
Concatenates multiple column values from a row.

.DESCRIPTION
Builds a single string key from multiple column values, escaping the delimiter.

.PARAMETER Row
The input row.

.PARAMETER columnArray
The columns to include.

.PARAMETER Delimiter
The delimiter used between values. Defaults to '|' (ASCII 124).

.OUTPUTS
String
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Row,
        [Parameter(Mandatory = $true)]
        [string[]]$columnArray,
        [Parameter(Mandatory = $false)]
        [string]$Delimiter = '|'
    )

    Write-Log "BEGIN Concatenate-Values"
    try {
        $values = @()
        foreach ($col in $columnArray) {
            $val = $Row.$col
            if ($null -eq $val) {
                $s = ''
            } else {
                $s = [string]$val
            }
            if ($s -like "*$Delimiter*") {
                $s = $s -replace [regex]::Escape($Delimiter), ('\' + $Delimiter)
            }
            $values += $s
        }
        return ($values -join $Delimiter)
    }
    finally {
        Write-Log "END Concatenate-Values"
    }
}

function Add-Key {
<#
.SYNOPSIS
Adds a __key metadata column.

.DESCRIPTION
Adds a '__key' property to each row based on the key columns.

.PARAMETER Dataset
The input dataset.

.PARAMETER KeyColumns
The key columns.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$KeyColumns
    )

    Write-Log "BEGIN Add-Key"
    try {
        foreach ($row in @($Dataset)) {
            $key = Concatenate-Values -Row $row -columnArray $KeyColumns
            $row.__key = $key
        }
        return @($Dataset)
    }
    finally {
        Write-Log "END Add-Key"
    }
}

function Get-ColumnNames {
<#
.SYNOPSIS
Gets column names from a dataset.

.DESCRIPTION
Reads the first row and returns its property names.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
String[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    Write-Log "BEGIN Get-ColumnNames"
    try {
        if (-not $Dataset -or $Dataset.Count -eq 0) {
            return @()
        }
        return @($Dataset[0].PSObject.Properties.Name)
    }
    finally {
        Write-Log "END Get-ColumnNames"
    }
}

function Get-RowCount {
<#
.SYNOPSIS
Gets row count of a dataset.

.DESCRIPTION
Returns the number of elements in the dataset array.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
Int32
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    Write-Log "BEGIN Get-RowCount"
    try {
        return ($Dataset.Count)
    }
    finally {
        Write-Log "END Get-RowCount"
    }
}

function Get-DistinctValues {
<#
.SYNOPSIS
Gets distinct concatenated values for specified columns.

.DESCRIPTION
Uses Concatenate-Values to build keys and returns distinct keys.

.PARAMETER Dataset
The input dataset.

.PARAMETER Columns
The columns to use.

.OUTPUTS
String[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$Columns
    )

    Write-Log "BEGIN Get-DistinctValues"
    try {
        $datasetColumns = Get-ColumnNames -Dataset $Dataset
        foreach ($column in $Columns) {
            if ($datasetColumns -notcontains $column) {
                throw "Column `$column` does not exist in dataset."
            }
        }

        $ht = @{}
        foreach ($row in @($Dataset)) {
            $value = Concatenate-Values -Row $row -columnArray $Columns
            $ht[$value] = $row
        }
        return @($ht.Keys)
    }
    finally {
        Write-Log "END Get-DistinctValues"
    }
}

function Check-KeyUnique {
<#
.SYNOPSIS
Checks that __key is unique.

.DESCRIPTION
Compares row count to distinct key count.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
Boolean
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    Write-Log "BEGIN Check-KeyUnique"
    try {
        $datasetRowCount = Get-RowCount -Dataset $Dataset
        $keys = Get-DistinctValues -Dataset $Dataset -Columns @('__key')
        $keyRowCount = $keys.Count
        if ($datasetRowCount -ne $keyRowCount) {
            throw 'The key column does not contain all unique values!'
        }
        return $true
    }
    finally {
        Write-Log "END Check-KeyUnique"
    }
}

function Remove-Columns {
<#
.SYNOPSIS
Removes unwanted columns.

.DESCRIPTION
Removes specified columns from each row, except '__key'.

.PARAMETER Dataset
The input dataset.

.PARAMETER ExcludeColumns
The columns to remove.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$ExcludeColumns
    )

    Write-Log "BEGIN Remove-Columns"
    try {
        foreach ($column in $ExcludeColumns) {
            if ($column -eq '__key') { continue }
            foreach ($row in @($Dataset)) {
                if ($row.PSObject.Properties.Name -contains $column) {
                    $row.PSObject.Properties.Remove($column) | Out-Null
                }
            }
        }
        return @($Dataset)
    }
    finally {
        Write-Log "END Remove-Columns"
    }
}

function Trim-Dataset {
<#
.SYNOPSIS
Trims all string cells.

.DESCRIPTION
Trims whitespace from all string-valued properties.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    Write-Log "BEGIN Trim-Dataset"
    try {
        foreach ($row in @($Dataset)) {
            foreach ($prop in $row.PSObject.Properties) {
                $name = $prop.Name
                $value = $row.$name
                if ($null -eq $value) { continue }
                if ($value -is [string]) {
                    $row.$name = $value.Trim()
                }
            }
        }
        return @($Dataset)
    }
    finally {
        Write-Log "END Trim-Dataset"
    }
}

function Get-TopNValues {
<#
.SYNOPSIS
Gets top N values from a column.

.DESCRIPTION
Returns up to TopN values from the specified column as strings.

.PARAMETER Dataset
The input dataset.

.PARAMETER ColumnName
The column name.

.PARAMETER TopN
Number of values to return.

.OUTPUTS
String[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string]$ColumnName,
        [Parameter(Mandatory = $true)]
        [int]$TopN
    )

    Write-Log "BEGIN Get-TopNValues"
    try {
        $rowCount = Get-RowCount -Dataset $Dataset
        $output = @()
        $i = [Math]::Min($TopN, $rowCount)
        for ($j = 0; $j -lt $i; $j++) {
            $val = $Dataset[$j].$ColumnName
            if ($null -eq $val) {
                $output += ''
            } else {
                $output += [string]$val
            }
        }
        return @($output)
    }
    finally {
        Write-Log "END Get-TopNValues"
    }
}

function Get-CellDataType {
<#
.SYNOPSIS
Determines the data type of a cell value.

.DESCRIPTION
Uses regex rules to classify a string as BOOLEAN, INTEGER, DECIMAL, DATETIME, or STRING.

.PARAMETER Value
The input value.

.OUTPUTS
DataTypeEnum
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    Write-Log "BEGIN Get-CellDataType"
    try {
        $v = $Value.Trim()

        if ($v -match '^(true|false)$') {
            return [DataTypeEnum]::BOOLEAN
        }
        if ($v -match '^-?\d+$') {
            return [DataTypeEnum]::INTEGER
        }
        if ($v -match '^[+-]?(?:\d+\.?\d*|\.\d+)$') {
            return [DataTypeEnum]::DECIMAL
        }
        if ($v -match '^\d{4}-\d{2}-\d{2}(?:[T\s]\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?(?:Z|[+\-]\d{2}:\d{2})?)?$') {
            return [DataTypeEnum]::DATETIME
        }
        if ($v -match '^.*$') {
            return [DataTypeEnum]::STRING
        }

        throw 'Value cannot be parsed by any regex rules!'
    }
    finally {
        Write-Log "END Get-CellDataType"
    }
}

function Apply-NullValues {
<#
.SYNOPSIS
Applies null-like value rules.

.DESCRIPTION
Replaces configured null-like values and empty strings with $null.

.PARAMETER Dataset
The input dataset.

.PARAMETER NullValuesArray
Array of null-like values.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $false)]
        [string[]]$NullValuesArray = $null
    )

    Write-Log "BEGIN Apply-NullValues"
    try {
        $columnNames = Get-ColumnNames -Dataset $Dataset
        foreach ($columnName in $columnNames) {
            foreach ($row in @($Dataset)) {
                $val = $row.$columnName
                if ($null -ne $NullValuesArray -and $NullValuesArray.Count -gt 0) {
                    if ($NullValuesArray -contains $val) {
                        $row.$columnName = $null
                        continue
                    }
                }
                if ($val -is [string] -and $val -eq '') {
                    $row.$columnName = $null
                }
            }
        }
        return @($Dataset)
    }
    finally {
        Write-Log "END Apply-NullValues"
    }
}

function Add-RowId {
<#
.SYNOPSIS
Adds an auto-incrementing row id column.

.DESCRIPTION
Adds a new column with integer values starting at 1.

.PARAMETER Dataset
The input dataset.

.PARAMETER RowIdName
The name of the row id column.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string]$RowIdName
    )

    Write-Log "BEGIN Add-RowId"
    try {
        if ([string]::IsNullOrWhiteSpace($RowIdName)) {
            return @($Dataset)
        }

        $columnNames = Get-ColumnNames -Dataset $Dataset
        if ($columnNames -contains $RowIdName) {
            throw "{$RowIdName} already exists in dataset!"
        }

        $i = 1
        foreach ($row in @($Dataset)) {
            $row.$RowIdName = $i
            $i++
        }
        return @($Dataset)
    }
    finally {
        Write-Log "END Add-RowId"
    }
}

function Get-DataTypes {
<#
.SYNOPSIS
Determines column data types.

.DESCRIPTION
Builds a hashtable of column name to DataTypeEnum, using auto-detection and optional overrides.

.PARAMETER Dataset
The input dataset.

.PARAMETER AutoDetectTypes
Whether to auto-detect types.

.PARAMETER ScanRows
Number of rows to scan when auto-detecting.

.PARAMETER ColumnTypesArray
Optional overrides in format 'column:type'.

.OUTPUTS
Hashtable
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $false)]
        [bool]$AutoDetectTypes = $false,
        [Parameter(Mandatory = $false)]
        [int]$ScanRows = $null,
        [Parameter(Mandatory = $false)]
        [string[]]$ColumnTypesArray = $null
    )

    Write-Log "BEGIN Get-DataTypes"
    try {
        if ($AutoDetectTypes -and (($null -eq $ScanRows) -or $ScanRows -lt 1)) {
            throw 'When AutoDetectTypes is true, ScanRows must be non-null and greater than 0.'
        }

        $columnNames = Get-ColumnNames -Dataset $Dataset
        $output = @{}

        foreach ($column in $columnNames) {
            $output[$column] = [DataTypeEnum]::STRING
        }

        if ($AutoDetectTypes) {
            foreach ($columnName in $columnNames) {
                $values = Get-TopNValues -Dataset $Dataset -ColumnName $columnName -TopN $ScanRows
                $dataTypes = @()
                foreach ($value in $values) {
                    $dt = Get-CellDataType -Value ([string]$value)
                    $dataTypes += $dt
                }

                if ($dataTypes.Count -gt 0 -and ($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::BOOLEAN } | Measure-Object).Count -eq 0) {
                    $output[$columnName] = [DataTypeEnum]::BOOLEAN
                }
                elseif ($dataTypes.Count -gt 0 -and ($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::INTEGER } | Measure-Object).Count -eq 0) {
                    $output[$columnName] = [DataTypeEnum]::INTEGER
                }
                elseif ($dataTypes.Count -gt 0 -and ($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::DECIMAL } | Measure-Object).Count -eq 0) {
                    $output[$columnName] = [DataTypeEnum]::DECIMAL
                }
                elseif ($dataTypes.Count -gt 0 -and ($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::DATETIME } | Measure-Object).Count -eq 0) {
                    $output[$columnName] = [DataTypeEnum]::DATETIME
                }
                else {
                    $output[$columnName] = [DataTypeEnum]::STRING
                }
            }
        }

        if ($null -ne $ColumnTypesArray -and $ColumnTypesArray.Count -gt 0) {
            foreach ($element in $ColumnTypesArray) {
                if ([string]::IsNullOrWhiteSpace($element)) { continue }
                $columnDataType = $element.Split(':', 2)
                if ($columnDataType.Count -ne 2) { continue }
                $key = $columnDataType[0]
                $value = [DataTypeEnum]::Parse([DataTypeEnum], $columnDataType[1])
                $output[$key] = $value
            }
        }

        return $output
    }
    finally {
        Write-Log "END Get-DataTypes"
    }
}

function Cast-Dataset {
<#
.SYNOPSIS
Casts dataset columns to detected types.

.DESCRIPTION
Uses the column type hashtable to cast non-null values to their target types.

.PARAMETER Dataset
The input dataset.

.PARAMETER ColumnTypes
Hashtable of column name to DataTypeEnum.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [hashtable]$ColumnTypes
    )

    Write-Log "BEGIN Cast-Dataset"
    try {
        foreach ($columnName in $ColumnTypes.Keys) {
            $targetType = $ColumnTypes[$columnName]
            foreach ($row in @($Dataset)) {
                $val = $row.$columnName
                if ($null -eq $val) { continue }

                switch ($targetType) {
                    ([DataTypeEnum]::BOOLEAN) {
                        $tmp = $false
                        if (-not [bool]::TryParse([string]$val, [ref]$tmp)) {
                            throw "Value: $val cannot be converted to a BOOLEAN."
                        }
                        $row.$columnName = $tmp
                    }
                    ([DataTypeEnum]::INTEGER) {
                        $tmp = 0
                        if (-not [int]::TryParse([string]$val, [ref]$tmp)) {
                            throw "Value: $val cannot be converted to an INTEGER."
                        }
                        $row.$columnName = $tmp
                    }
                    ([DataTypeEnum]::DECIMAL) {
                        $tmp = [decimal]0
                        if (-not [decimal]::TryParse([string]$val, [ref]$tmp)) {
                            throw "Value: $val cannot be converted to a DECIMAL."
                        }
                        $row.$columnName = $tmp
                    }
                    ([DataTypeEnum]::DATETIME) {
                        $tmp = [datetime]::MinValue
                        $formats = @(
                            "yyyy-MM-dd",
                            "yyyy-MM-ddTHH:mm",
                            "yyyy-MM-ddTHH:mm:ss",
                            "yyyy-MM-ddTHH:mm:ssK",
                            "yyyy-MM-dd HH:mm",
                            "yyyy-MM-dd HH:mm:ss",
                            "yyyy-MM-dd HH:mm:ssK"
                        )
                        if (-not [datetime]::TryParseExact([string]$val, $formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$tmp)) {
                            throw "Value: $val cannot be converted to a DATETIME."
                        }
                        $row.$columnName = $tmp
                    }
                    ([DataTypeEnum]::STRING) {
                        # no-op
                    }
                }
            }
        }
        return @($Dataset)
    }
    finally {
        Write-Log "END Cast-Dataset"
    }
}

function Compare-Schemas {
<#
.SYNOPSIS
Compares two schemas.

.DESCRIPTION
Builds a SchemaComparisonResult array from left and right column type hashtables.

.PARAMETER LeftDatasetColumnTypes
Left schema hashtable.

.PARAMETER RightDatasetColumnTypes
Right schema hashtable.

.OUTPUTS
SchemaComparisonResult[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LeftDatasetColumnTypes,
        [Parameter(Mandatory = $true)]
        [hashtable]$RightDatasetColumnTypes
    )

    Write-Log "BEGIN Compare-Schemas"
    try {
        $results = @()

        foreach ($leftKey in $LeftDatasetColumnTypes.Keys) {
            $leftType = $LeftDatasetColumnTypes[$leftKey]
            $result = [SchemaComparisonResult]::new($leftKey, $leftType, $null)
            $results += $result
        }

        foreach ($rightKey in $RightDatasetColumnTypes.Keys) {
            $rightType = $RightDatasetColumnTypes[$rightKey]
            $existing = $results | Where-Object { $_.ColumnName -eq $rightKey }
            if ($existing) {
                $existing.RightType = $rightType
            } else {
                $result = [SchemaComparisonResult]::new($rightKey, $null, $rightType)
                $results += $result
            }
        }

        return @($results)
    }
    finally {
        Write-Log "END Compare-Schemas"
    }
}

function Compare-Datasets {
<#
.SYNOPSIS
Compares two datasets row-by-row and column-by-column.

.DESCRIPTION
Uses __key to align rows and emits comparison results as PSCustomObject.

.PARAMETER LeftDataset
The left dataset.

.PARAMETER RightDataset
The right dataset.

.OUTPUTS
PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$LeftDataset,
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$RightDataset
    )

    Write-Log "BEGIN Compare-Datasets"
    try {
        $results = @()

        $htLeft = @{}
        foreach ($row in @($LeftDataset)) {
            $key = $row.__key
            $htLeft[$key] = $row
        }

        $htRight = @{}
        foreach ($row in @($RightDataset)) {
            $key = $row.__key
            $htRight[$key] = $row
        }

        foreach ($key in $htLeft.Keys) {
            if (-not $htRight.ContainsKey($key)) {
                $results += [pscustomobject]@{
                    CompareType = [CompareTypeEnum]::KEY_LEFT_ONLY
                    ColumnName  = $null
                    KeyValues   = [string]$key
                    Left        = $null
                    Right       = $null
                }
            }
        }

        foreach ($key in $htRight.Keys) {
            if (-not $htLeft.ContainsKey($key)) {
                $results += [pscustomobject]@{
                    CompareType = [CompareTypeEnum]::KEY_RIGHT_ONLY
                    ColumnName  = $null
                    KeyValues   = [string]$key
                    Left        = $null
                    Right       = $null
                }
            }
        }

        foreach ($key in $htLeft.Keys) {
            if (-not $htRight.ContainsKey($key)) { continue }

            $leftRow  = $htLeft[$key]
            $rightRow = $htRight[$key]

            foreach ($prop in $leftRow.PSObject.Properties) {
                $property = $prop.Name
                if ($property -eq '__key') { continue }

                $leftVal  = $leftRow.$property
                $rightVal = $rightRow.$property

                if ($leftVal -ne $rightVal) {
                    $results += [pscustomobject]@{
                        CompareType = [CompareTypeEnum]::DIFFERENT
                        ColumnName  = $property
                        KeyValues   = [string]$key
                        Left        = if ($null -eq $leftVal) { $null } else { [string]$leftVal }
                        Right       = if ($null -eq $rightVal) { $null } else { [string]$rightVal }
                    }
                }
            }
        }

        return @($results)
    }
    finally {
        Write-Log "END Compare-Datasets"
    }
}

function Output-SchemaResults {
<#
.SYNOPSIS
Outputs schema comparison results.

.DESCRIPTION
Writes schema comparison table and returns whether schemas match.

.PARAMETER SchemaComparisonResults
Array of SchemaComparisonResult.

.OUTPUTS
Boolean
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [SchemaComparisonResult[]]$SchemaComparisonResults
    )

    Write-Log "BEGIN Output-SchemaResults"
    try {
        $sorted = $SchemaComparisonResults | Sort-Object -Property ColumnName
        $sorted | Format-Table -AutoSize | Out-Host

        $mismatch = $sorted | Where-Object { $_.LeftType -ne $_.RightType }
        if ($mismatch) {
            return $false
        }
        return $true
    }
    finally {
        Write-Log "END Output-SchemaResults"

    }
}

function Output-Results {
<#
.SYNOPSIS
Outputs comparison results.

.DESCRIPTION
Outputs either detailed or summarised comparison results to the console.

.PARAMETER ComparisonResults
The comparison results.

.PARAMETER SummariseResults
If true, outputs grouped summary; otherwise detailed rows.

.PARAMETER DetailedRows
Maximum number of detailed rows to output.

.OUTPUTS
None
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$ComparisonResults,
        [Parameter(Mandatory = $true)]
        [bool]$SummariseResults,
        [Parameter(Mandatory = $true)]
        [int]$DetailedRows
    )

    Write-Log "BEGIN Output-Results"
    try {
        if (-not $SummariseResults) {
            $ordered = $ComparisonResults |
                Sort-Object -Property CompareType, ColumnName, KeyValues
            if ($DetailedRows -gt 0) {
                $ordered = $ordered | Select-Object -First $DetailedRows
            }
            $ordered | Format-Table -AutoSize | Out-Host
        }
        else {
            $normalized = $ComparisonResults | ForEach-Object {
                [pscustomobject]@{
                    CompareType = $_.CompareType
                    ColumnName  = if ($null -eq $_.ColumnName) { '' } else { [string]$_.ColumnName }
                }
            }

            $resultsGrouped = @()
            $groups = $normalized | Group-Object -Property CompareType, ColumnName
            foreach ($g in $groups) {
                $resultsGrouped += [pscustomobject]@{
                    CompareType = $g.Group[0].CompareType
                    ColumnName  = $g.Group[0].ColumnName
                    Count       = [string]$g.Count
                }
            }

            $resultsGrouped =
                $resultsGrouped |
                Sort-Object -Property CompareType, ColumnName

            $resultsGrouped | Format-Table -AutoSize | Out-Host
        }
    }
    finally {
        Write-Log "END Output-Results"
    }
}

function Compare-Csv {
<#
.SYNOPSIS
Compares two CSV files.

.DESCRIPTION
Top-level function that orchestrates validation, reading, preprocessing, comparison, and output.

.PARAMETER Left
Path to the left CSV file.

.PARAMETER Right
Path to the right CSV file.

.PARAMETER Delimiter
CSV delimiter. Defaults to ','.

.PARAMETER RowIdName
Optional row id column name.

.PARAMETER KeyColumns
Comma-separated list of key columns.

.PARAMETER ExcludeColumns
Comma-separated list of columns to exclude.

.PARAMETER ColumnTypes
Optional column type overrides in 'column:type' format.

.PARAMETER NullValues
Comma-separated list of null-like values.

.PARAMETER ApplyTrim
If true, trims all string values.

.PARAMETER AutoDetectTypes
If true, auto-detects column types.

.PARAMETER ScanRows
Number of rows to scan when auto-detecting types.

.PARAMETER SummariseResults
If true, outputs summary; otherwise detailed results.

.PARAMETER DetailedRows
Maximum number of detailed rows to output.

.OUTPUTS
None
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Left,
        [Parameter(Mandatory = $true)]
        [string]$Right,
        [Parameter(Mandatory = $false)]
        [string]$Delimiter = ',',
        [Parameter(Mandatory = $false)]
        [string]$RowIdName = $null,
        [Parameter(Mandatory = $true)]
        [string]$KeyColumns,
        [Parameter(Mandatory = $false)]
        [string]$ExcludeColumns = $null,
        [Parameter(Mandatory = $false)]
        [string]$ColumnTypes = $null,
        [Parameter(Mandatory = $false)]
        [string]$NullValues = $null,
        [Parameter(Mandatory = $false)]
        [bool]$ApplyTrim = $false,
        [Parameter(Mandatory = $false)]
        [bool]$AutoDetectTypes = $false,
        [Parameter(Mandatory = $false)]
        [int]$ScanRows = $null,
        [Parameter(Mandatory = $false)]
        [bool]$SummariseResults = $true,
        [Parameter(Mandatory = $false)]
        [int]$DetailedRows = 0
    )

    Write-Log "BEGIN Compare-Csv"
    try {
        $keyColumnsArray     = Parse-List -Value $KeyColumns -Delimiter $Delimiter
        $excludeColumnsArray = if ($null -ne $ExcludeColumns) { Parse-List -Value $ExcludeColumns -Delimiter $Delimiter } else { @() }
        $nullValuesArray     = if ($null -ne $NullValues) { Parse-List -Value $NullValues -Delimiter $Delimiter } else { @() }
        $columnTypesArray    = if ($null -ne $ColumnTypes) { Parse-List -Value $ColumnTypes -Delimiter $Delimiter } else { @() }

        Test-Path -Path $Left | Out-Null
        Test-Path -Path $Right | Out-Null

        $leftDataset  = Read-Csv -Path $Left -Delimiter $Delimiter
        $rightDataset = Read-Csv -Path $Right -Delimiter $Delimiter

        if ($excludeColumnsArray.Count -gt 0) {
            $leftDataset  = Remove-Columns -Dataset $leftDataset -ExcludeColumns $excludeColumnsArray
            $rightDataset = Remove-Columns -Dataset $rightDataset -ExcludeColumns $excludeColumnsArray
        }

        if ($ApplyTrim) {
            $leftDataset  = Trim-Dataset -Dataset $leftDataset
            $rightDataset = Trim-Dataset -Dataset $rightDataset
        }

        $leftDataset  = Apply-NullValues -Dataset $leftDataset -NullValuesArray $nullValuesArray
        $rightDataset = Apply-NullValues -Dataset $rightDataset -NullValuesArray $nullValuesArray

        if ($null -ne $RowIdName) {
            $leftDataset  = Add-RowId -Dataset $leftDataset -RowIdName $RowIdName
            $rightDataset = Add-RowId -Dataset $rightDataset -RowIdName $RowIdName
        }

        $leftDatasetColumnTypes  = Get-DataTypes -Dataset $leftDataset -AutoDetectTypes $AutoDetectTypes -ScanRows $ScanRows -ColumnTypesArray $columnTypesArray
        $rightDatasetColumnTypes = Get-DataTypes -Dataset $rightDataset -AutoDetectTypes $AutoDetectTypes -ScanRows $ScanRows -ColumnTypesArray $columnTypesArray

        $leftDataset  = Cast-Dataset -Dataset $leftDataset -ColumnTypes $leftDatasetColumnTypes
        $rightDataset = Cast-Dataset -Dataset $rightDataset -ColumnTypes $rightDatasetColumnTypes

        $leftDataset  = Add-Key -Dataset $leftDataset -KeyColumns $keyColumnsArray
        $rightDataset = Add-Key -Dataset $rightDataset -KeyColumns $keyColumnsArray

        $leftKeys  = Get-DistinctValues -Dataset $leftDataset -Columns $keyColumnsArray
        $rightKeys = Get-DistinctValues -Dataset $rightDataset -Columns $keyColumnsArray

        Check-KeyUnique -Dataset $leftDataset  | Out-Null
        Check-KeyUnique -Dataset $rightDataset | Out-Null

        $schemaResults  = Compare-Schemas -LeftDatasetColumnTypes $leftDatasetColumnTypes -RightDatasetColumnTypes $rightDatasetColumnTypes
        $outputSchemaOk = Output-SchemaResults -SchemaComparisonResults $schemaResults

        if ($outputSchemaOk) {
            $results = Compare-Datasets -LeftDataset $leftDataset -RightDataset $rightDataset
            Output-Results -ComparisonResults $results -SummariseResults $SummariseResults -DetailedRows $DetailedRows
        }
    }
    finally {
        Write-Log "END Compare-Csv"
    }
}

function New-TestCsvFiles {
<#
.SYNOPSIS
Generates sample left.csv and right.csv files.

.DESCRIPTION
Creates two CSV files with 50 rows each, matching the specification:
recordId, columnA (DateTime), columnB (Decimal), columnC (Integer),
columnD (String color), and columnE (String animal) on the right file.
Approximately 90% of rows match between left and right, with a few extra keys on each side.

.OUTPUTS
None
#>
    [CmdletBinding()]
    param()

    Write-Log "BEGIN New-TestCsvFiles"
    try {
        $colors  = @('Red','Green','Blue','Yellow','Purple','Orange','Black','White','Gray','Cyan')
        $animals = @('Dog','Cat','Horse','Lion','Tiger','Bear','Wolf','Fox','Eagle','Shark')

        $now = Get-Date
        $rand = [System.Random]::new()

        $leftRows  = @()
        $rightRows = @()

        for ($i = 1; $i -le 50; $i++) {
            $daysBack = $rand.Next(0, 365)
            $dt = $now.AddDays(-$daysBack).AddMinutes(-$rand.Next(0, 1440))
            $b  = [math]::Round(($rand.NextDouble() * 100), 2)
            $c  = $rand.Next(0, 1001)
            $d  = $colors[$rand.Next(0, $colors.Count)]
            $e  = $animals[$rand.Next(0, $animals.Count)]

            $leftRows += [pscustomobject]@{
                recordId = $i
                columnA  = $dt.ToString("yyyy-MM-ddTHH:mm:ss")
                columnB  = $b
                columnC  = $c
                columnD  = $d
            }

            # 90% chance to match, 10% chance to differ slightly
            if ($rand.NextDouble() -lt 0.9) {
                $rightRows += [pscustomobject]@{
                    recordId = $i
                    columnA  = $dt.ToString("yyyy-MM-ddTHH:mm:ss")
                    columnB  = $b
                    columnC  = $c
                    columnD  = $d
                    columnE  = $e
                }
            }
            else {
                $rightRows += [pscustomobject]@{
                    recordId = $i
                    columnA  = $dt.AddMinutes(1).ToString("yyyy-MM-ddTHH:mm:ss")
                    columnB  = [math]::Round($b + 0.5, 2)
                    columnC  = $c + 1
                    columnD  = $colors[$rand.Next(0, $colors.Count)]
                    columnE  = $animals[$rand.Next(0, $animals.Count)]
                }
            }
        }

        # Extra keys on left
        foreach ($extraId in 1001,1002) {
            $daysBack = $rand.Next(0, 365)
            $dt = $now.AddDays(-$daysBack).AddMinutes(-$rand.Next(0, 1440))
            $b  = [math]::Round(($rand.NextDouble() * 100), 2)
            $c  = $rand.Next(0, 1001)
            $d  = $colors[$rand.Next(0, $colors.Count)]

            $leftRows += [pscustomobject]@{
                recordId = $extraId
                columnA  = $dt.ToString("yyyy-MM-ddTHH:mm:ss")
                columnB  = $b
                columnC  = $c
                columnD  = $d
            }
        }

        # Extra keys on right
        foreach ($extraId in 2001,2002) {
            $daysBack = $rand.Next(0, 365)
            $dt = $now.AddDays(-$daysBack).AddMinutes(-$rand.Next(0, 1440))
            $b  = [math]::Round(($rand.NextDouble() * 100), 2)
            $c  = $rand.Next(0, 1001)
            $d  = $colors[$rand.Next(0, $colors.Count)]
            $e  = $animals[$rand.Next(0, $animals.Count)]

            $rightRows += [pscustomobject]@{
                recordId = $extraId
                columnA  = $dt.ToString("yyyy-MM-ddTHH:mm:ss")
                columnB  = $b
                columnC  = $c
                columnD  = $d
                columnE  = $e
            }
        }

        $leftRows  | Export-Csv -Path 'left.csv'  -NoTypeInformation -Encoding utf8
        $rightRows | Export-Csv -Path 'right.csv' -NoTypeInformation -Encoding utf8
    }
    finally {
        Write-Log "END New-TestCsvFiles"
    }
}

# Sample invocation
New-TestCsvFiles

Compare-Csv `
    -Left 'left.csv' `
    -Right 'right.csv' `
    -KeyColumns 'recordId' `
    -ExcludeColumns 'columnE' `
    -NullValues 'null' `
    -ApplyTrim $true `
    -ScanRows 10 `
    -SummariseResults $true `
    -DetailedRows 50
