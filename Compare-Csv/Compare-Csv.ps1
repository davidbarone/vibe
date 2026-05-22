Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

enum DataTypeEnum {
    NONE     = 0
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
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Host $Message -ForegroundColor Cyan
}

function Parse-List {
<#
.SYNOPSIS
Parses a delimited string into a string array.

.DESCRIPTION
Takes a string input that represents a set of values delimited by a character.
If the input is null or empty, returns an empty array. Always returns an array.

.PARAMETER Value
The input string.

.PARAMETER Delimiter
The delimiter character. Defaults to ','.

.OUTPUTS
System.String[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $false)]
        [string]$Delimiter = ','
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return @()
    }

    $parts = $Value.Split($Delimiter)
    return @($parts)
}

function Test-Path {
<#
.SYNOPSIS
Validates that a file exists.

.DESCRIPTION
Checks that the file at the specified path exists. Throws if it does not.

.PARAMETER Path
The file path to test.

.OUTPUTS
System.Boolean
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $Path)) {
        throw "The file: $Path does not exist!"
    }

    return $true
}

function Read-Csv {
<#
.SYNOPSIS
Reads a CSV file into a dataset.

.DESCRIPTION
Uses Import-Csv to read a CSV file into an array of PSCustomObject.

.PARAMETER Path
The path to the CSV file.

.PARAMETER Delimiter
The delimiter character. Defaults to ','.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [string]$Delimiter = ','
    )

    $dataset = Import-Csv -LiteralPath $Path -Delimiter $Delimiter
    if (@($dataset).Count -eq 0) {
        throw 'Csv file contains no data!'
    }

    return @($dataset)
}

function Concatenate-Values {
<#
.SYNOPSIS
Concatenates multiple column values from a row.

.DESCRIPTION
Builds a single string key from multiple column values, escaping the delimiter.

.PARAMETER Row
The input row.

.PARAMETER ColumnArray
The columns to include.

.PARAMETER Delimiter
The delimiter used between values. Defaults to '|' (ASCII 124).

.OUTPUTS
System.String
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Row,
        [Parameter(Mandatory = $true)]
        [string[]]$ColumnArray,
        [Parameter(Mandatory = $false)]
        [string]$Delimiter = '|'
    )

    $values = @()
    foreach ($column in $ColumnArray) {
        $value = $Row.$column
        if ($null -eq $value) {
            $stringValue = ''
        } else {
            $stringValue = [string]$value
        }

        if ($stringValue -like "*$Delimiter*") {
            $stringValue = $stringValue -replace [regex]::Escape($Delimiter), ('\' + $Delimiter)
        }

        $values += $stringValue
    }

    return ($values -join $Delimiter)
}

function Add-Key {
<#
.SYNOPSIS
Adds a __key metadata column to a dataset.

.DESCRIPTION
Concatenates key column values into a single __key column for each row.

.PARAMETER Dataset
The input dataset.

.PARAMETER KeyColumns
The key column names.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$KeyColumns
    )

    foreach ($row in @($Dataset)) {
        $key = Concatenate-Values -Row $row -ColumnArray $KeyColumns
        $row | Add-Member -MemberType NoteProperty -Name '__key' -Value $key -Force
    }

    return @($Dataset)
}

function Get-ColumnNames {
<#
.SYNOPSIS
Gets column names from a dataset.

.DESCRIPTION
Reads the first row of a dataset and returns its property names.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
System.String[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    $first = @($Dataset)[0]
    if ($null -eq $first) {
        return @()
    }

    $names = $first.PSObject.Properties |
        Where-Object { $_.MemberType -eq 'NoteProperty' } |
        Select-Object -ExpandProperty Name

    return @($names)
}

function Get-RowCount {
<#
.SYNOPSIS
Gets the row count of a dataset.

.DESCRIPTION
Returns the number of elements in the dataset array.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
System.Int32
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    return @($Dataset).Count
}

function Get-DistinctValues {
<#
.SYNOPSIS
Gets distinct concatenated values for specified columns.

.DESCRIPTION
Uses Concatenate-Values to build keys and returns distinct values.

.PARAMETER Dataset
The input dataset.

.PARAMETER Columns
The columns to use.

.OUTPUTS
System.String[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$Columns
    )

    $datasetColumns = Get-ColumnNames -Dataset $Dataset
    foreach ($column in $Columns) {
        if (-not ($datasetColumns -contains $column)) {
            throw "Column `$column` does not exist in dataset."
        }
    }

    $ht = @{}
    foreach ($row in @($Dataset)) {
        $value = Concatenate-Values -Row $row -ColumnArray $Columns
        $ht[$value] = $row
    }

    return @($ht.Keys)
}

function Check-KeyUnique {
<#
.SYNOPSIS
Checks that the __key column is unique.

.DESCRIPTION
Compares row count to distinct __key count and throws if not equal.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
System.Boolean
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    $datasetRowCount = Get-RowCount -Dataset $Dataset
    $keys = Get-DistinctValues -Dataset $Dataset -Columns @('__key')
    $keyRowCount = @($keys).Count

    if ($datasetRowCount -ne $keyRowCount) {
        throw 'The key column does not contain all unique values!'
    }

    return $true
}

function Remove-Columns {
<#
.SYNOPSIS
Removes unwanted columns from a dataset.

.DESCRIPTION
Removes specified columns from each row, except __key.

.PARAMETER Dataset
The input dataset.

.PARAMETER ExcludeColumns
The columns to remove.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$ExcludeColumns
    )

    $columnsToRemove = @($ExcludeColumns | Where-Object { $_ -ne '__key' })

    foreach ($column in $columnsToRemove) {
        foreach ($row in @($Dataset)) {
            if ($row.PSObject.Properties.Name -contains $column) {
                $row.PSObject.Properties.Remove($column) | Out-Null
            }
        }
    }

    return @($Dataset)
}

function Trim-Dataset {
<#
.SYNOPSIS
Trims all string cells in a dataset.

.DESCRIPTION
Iterates all properties and trims string values.

.PARAMETER Dataset
The input dataset.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    foreach ($row in @($Dataset)) {
        foreach ($prop in $row.PSObject.Properties) {
            $name = $prop.Name
            $value = $row.$name
            if ($null -eq $value) {
                continue
            }

            if ($value -is [string]) {
                $row.$name = $value.Trim()
            }
        }
    }

    return @($Dataset)
}

function Get-TopNValues {
<#
.SYNOPSIS
Gets the top N values of a column.

.DESCRIPTION
Returns up to TopN values from the specified column as strings.

.PARAMETER Dataset
The input dataset.

.PARAMETER ColumnName
The column name.

.PARAMETER TopN
The number of values to return.

.OUTPUTS
System.String[]
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

    $rowCount = Get-RowCount -Dataset $Dataset
    $output = @()
    $i = [Math]::Min($TopN, $rowCount)

    for ($j = 0; $j -lt $i; $j++) {
        $row = @($Dataset)[$j]
        $value = $row.$ColumnName
        $output += [string]$value
    }

    return @($output)
}

function Get-CellDataType {
<#
.SYNOPSIS
Determines the data type of a string cell value.

.DESCRIPTION
Uses regex rules to classify the value into DataTypeEnum.

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

function Apply-NullValues {
<#
.SYNOPSIS
Replaces null-like values with $null.

.DESCRIPTION
Converts configured null-like values and empty strings to $null.

.PARAMETER Dataset
The input dataset.

.PARAMETER NullValuesArray
The null-like values.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $false)]
        [string[]]$NullValuesArray = $null
    )

    $columnNames = Get-ColumnNames -Dataset $Dataset

    foreach ($columnName in $columnNames) {
        foreach ($row in @($Dataset)) {
            $value = $row.$columnName

            if ($null -ne $NullValuesArray -and @($NullValuesArray).Count -gt 0) {
                if ($NullValuesArray -contains $value) {
                    $row.$columnName = $null
                    continue
                }
            }

            if ($value -is [string] -and $value -eq '') {
                $row.$columnName = $null
            }
        }
    }

    return @($Dataset)
}

function Add-RowId {
<#
.SYNOPSIS
Adds an auto-increment row ID column.

.DESCRIPTION
Optionally adds a row ID column starting at 1.

.PARAMETER Dataset
The input dataset.

.PARAMETER RowIdName
The name of the row ID column.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string]$RowIdName
    )

    if ([string]::IsNullOrEmpty($RowIdName)) {
        return @($Dataset)
    }

    $columnNames = Get-ColumnNames -Dataset $Dataset
    if ($columnNames -contains $RowIdName) {
        throw "{$RowIdName} already exists in dataset!"
    }

    $i = 1
    foreach ($row in @($Dataset)) {
        $row | Add-Member -MemberType NoteProperty -Name $RowIdName -Value $i -Force
        $i++
    }

    return @($Dataset)
}

function Get-DataTypes {
<#
.SYNOPSIS
Determines data types for all columns in a dataset.

.DESCRIPTION
Initialises all columns as STRING, optionally auto-detects types, then applies overrides.

.PARAMETER Dataset
The input dataset.

.PARAMETER AutoDetectTypes
Whether to auto-detect types.

.PARAMETER ScanRows
Number of rows to scan when auto-detecting.

.PARAMETER ColumnTypesArray
Optional overrides in 'column:dataType' format.

.OUTPUTS
System.Collections.Hashtable
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

    if ($AutoDetectTypes -and (($null -eq $ScanRows) -or ($ScanRows -lt 1))) {
        throw 'If AutoDetectTypes is true, ScanRows must be non-null and > 0.'
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
                if ([string]::IsNullOrEmpty($value)) {
                    continue
                }
                $dt = Get-CellDataType -Value ([string]$value)
                $dataTypes += $dt
            }

            if (@($dataTypes).Count -eq 0) {
                continue
            }

            if (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::BOOLEAN }).Count -eq 0) {
                $output[$columnName] = [DataTypeEnum]::BOOLEAN
            } elseif (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::INTEGER }).Count -eq 0) {
                $output[$columnName] = [DataTypeEnum]::INTEGER
            } elseif (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::DECIMAL }).Count -eq 0) {
                $output[$columnName] = [DataTypeEnum]::DECIMAL
            } elseif (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::DATETIME }).Count -eq 0) {
                $output[$columnName] = [DataTypeEnum]::DATETIME
            } else {
                $output[$columnName] = [DataTypeEnum]::STRING
            }
        }
    }

    if ($null -ne $ColumnTypesArray -and @($ColumnTypesArray).Count -gt 0) {
        foreach ($element in $ColumnTypesArray) {
            if ([string]::IsNullOrWhiteSpace($element)) {
                continue
            }

            $columnDataType = $element.Split(':')
            if ($columnDataType.Count -ne 2) {
                throw "Invalid ColumnTypes element: '$element'. Expected format 'column:dataType'."
            }

            $key = $columnDataType[0]
            $valueString = $columnDataType[1]

            $value = [DataTypeEnum]::Parse([DataTypeEnum], $valueString)
            $output[$key] = $value
        }
    }

    return $output
}

function Cast-Dataset {
<#
.SYNOPSIS
Casts dataset columns to specified types.

.DESCRIPTION
Uses DataTypeEnum to cast non-null values to the correct .NET types.

.PARAMETER Dataset
The input dataset.

.PARAMETER ColumnTypes
Hashtable of column name to DataTypeEnum.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [hashtable]$ColumnTypes
    )

    foreach ($columnName in @($ColumnTypes.Keys)) {
        $typeEnum = $ColumnTypes[$columnName]

        foreach ($row in @($Dataset)) {
            $value = $row.$columnName
            if ($null -eq $value) {
                continue
            }

            switch ($typeEnum) {
                ([DataTypeEnum]::BOOLEAN) {
                    [bool]$parsed = $false
                    if (-not [bool]::TryParse([string]$value, [ref]$parsed)) {
                        throw "Value: $value cannot be converted to a BOOLEAN."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::INTEGER) {
                    [int]$parsed = 0
                    if (-not [int]::TryParse([string]$value, [ref]$parsed)) {
                        throw "Value: $value cannot be converted to an INTEGER."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::DECIMAL) {
                    [decimal]$parsed = 0
                    if (-not [decimal]::TryParse([string]$value, [ref]$parsed)) {
                        throw "Value: $value cannot be converted to a DECIMAL."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::DATETIME) {
                    [datetime]$parsed = [datetime]::MinValue
                    $formats = [string[]]@(
                        "yyyy-MM-dd",
                        "yyyy-MM-ddTHH:mm",
                        "yyyy-MM-ddTHH:mm:ss",
                        "yyyy-MM-ddTHH:mm:ss.fff",
                        "yyyy-MM-dd HH:mm",
                        "yyyy-MM-dd HH:mm:ss",
                        "yyyy-MM-dd HH:mm:ss.fff"
                    )
                    if (-not [datetime]::TryParseExact([string]$value, $formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)) {
                        throw "Value: $value cannot be converted to a DATETIME."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::STRING) {
                    continue
                }
                default {
                    continue
                }
            }
        }
    }

    return @($Dataset)
}

function Compare-Schemas {
<#
.SYNOPSIS
Compares two dataset schemas.

.DESCRIPTION
Builds a SchemaComparisonResult array describing column type differences.

.PARAMETER LeftDatasetColumnTypes
Hashtable of left column types.

.PARAMETER RightDatasetColumnTypes
Hashtable of right column types.

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

    $results = @()

    foreach ($leftKey in @($LeftDatasetColumnTypes.Keys)) {
        $leftType = $LeftDatasetColumnTypes[$leftKey]
        $result = [SchemaComparisonResult]::new($leftKey, $leftType, [DataTypeEnum]::NONE)
        $results += $result
    }

    foreach ($rightKey in @($RightDatasetColumnTypes.Keys)) {
        $rightType = $RightDatasetColumnTypes[$rightKey]
        $existing = $results | Where-Object { $_.ColumnName -eq $rightKey }
        if ($null -ne $existing) {
            $existing.RightType = $rightType
        } else {
            $result = [SchemaComparisonResult]::new($rightKey, [DataTypeEnum]::NONE, $rightType)
            $results += $result
        }
    }

    return @($results)
}

function Compare-Datasets {
<#
.SYNOPSIS
Compares two datasets row-by-row and column-by-column.

.DESCRIPTION
Uses __key to align rows and reports key-only and cell differences.

.PARAMETER LeftDataset
The left dataset.

.PARAMETER RightDataset
The right dataset.

.OUTPUTS
System.Management.Automation.PSCustomObject[]
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$LeftDataset,
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$RightDataset
    )

    $results = @()

    $htLeft = @{}
    foreach ($row in @($LeftDataset)) {
        $key = $row.'__key'
        $htLeft[$key] = $row
    }

    $htRight = @{}
    foreach ($row in @($RightDataset)) {
        $key = $row.'__key'
        $htRight[$key] = $row
    }

    foreach ($key in @($htLeft.Keys)) {
        if (-not $htRight.ContainsKey($key)) {
            $results += [pscustomobject]@{
                CompareType = [CompareTypeEnum]::KEY_LEFT_ONLY
                ColumnName  = $null
                KeyValues   = [string]$key
                Left        = [string]$null
                Right       = [string]$null
            }
        }
    }

    foreach ($key in @($htRight.Keys)) {
        if (-not $htLeft.ContainsKey($key)) {
            $results += [pscustomobject]@{
                CompareType = [CompareTypeEnum]::KEY_RIGHT_ONLY
                ColumnName  = $null
                KeyValues   = [string]$key
                Left        = [string]$null
                Right       = [string]$null
            }
        }
    }

    foreach ($key in @($htLeft.Keys)) {
        if (-not $htRight.ContainsKey($key)) {
            continue
        }

        $leftRow  = $htLeft[$key]
        $rightRow = $htRight[$key]

        foreach ($prop in $leftRow.PSObject.Properties) {
            $property = $prop.Name
            if ($property -eq '__key') {
                continue
            }

            $leftValue  = $leftRow.$property
            $rightValue = $rightRow.$property

            if ($leftValue -is [datetime] -and $rightValue -is [datetime]) {
                $leftString  = $leftValue.ToUniversalTime().ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
                $rightString = $rightValue.ToUniversalTime().ToString("o", [System.Globalization.CultureInfo]::InvariantCulture)
                if ($leftString -ne $rightString) {
                    $results += [pscustomobject]@{
                        CompareType = [CompareTypeEnum]::DIFFERENT
                        ColumnName  = $property
                        KeyValues   = [string]$key
                        Left        = [string]$leftValue
                        Right       = [string]$rightValue
                    }
                }
            } else {
                if ($leftValue -ne $rightValue) {
                    $results += [pscustomobject]@{
                        CompareType = [CompareTypeEnum]::DIFFERENT
                        ColumnName  = $property
                        KeyValues   = [string]$key
                        Left        = [string]$leftValue
                        Right       = [string]$rightValue
                    }
                }
            }
        }
    }

    return @($results)
}

function Output-SchemaResults {
<#
.SYNOPSIS
Outputs schema comparison results.

.DESCRIPTION
Prints schema results and returns whether schemas match.

.PARAMETER SchemaComparisonResults
The schema comparison results.

.OUTPUTS
System.Boolean
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [SchemaComparisonResult[]]$SchemaComparisonResults
    )

    Write-Host '' -ForegroundColor Cyan
    Write-Host '--------------' -ForegroundColor Cyan
    Write-Host 'SCHEMA RESULTS' -ForegroundColor Cyan
    Write-Host '--------------' -ForegroundColor Cyan

    $sorted = $SchemaComparisonResults | Sort-Object -Property ColumnName
    $sorted | Format-Table -AutoSize | Out-Host

    $differences = $sorted | Where-Object { $_.LeftType -ne $_.RightType }
    if (@($differences).Count -gt 0) {
        Write-Host 'Schema differences found. Row-level comparison not performed' -ForegroundColor Cyan
        return $false
    } else {
        Write-Host 'Schemas match. Continuing to perform row-by-row comparison...' -ForegroundColor Cyan
        return $true
    }
}

function Output-Results {
<#
.SYNOPSIS
Outputs comparison results.

.DESCRIPTION
Outputs either detailed or summarised comparison results.

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

    Write-Host '' -ForegroundColor Cyan
    Write-Host '-----------------' -ForegroundColor Cyan
    Write-Host 'ROW LEVEL RESULTS' -ForegroundColor Cyan
    Write-Host '-----------------' -ForegroundColor Cyan

    if (-not $SummariseResults) {
        $ordered = $ComparisonResults |
            Sort-Object -Property CompareType, ColumnName, KeyValues

        if ($DetailedRows -gt 0) {
            $ordered = $ordered | Select-Object -First $DetailedRows
        }

        $ordered | Format-Table -AutoSize | Out-Host
    } else {
        $normalized = $ComparisonResults | ForEach-Object {
            [pscustomobject]@{
                CompareType = $_.CompareType
                ColumnName  = if ($null -eq $_.ColumnName) { '' } else { [string]$_.ColumnName }
            }
        }

        $grouped = $normalized |
            Group-Object -Property CompareType, ColumnName |
            ForEach-Object {
                [pscustomobject]@{
                    CompareType = $_.Group[0].CompareType
                    ColumnName  = $_.Group[0].ColumnName
                    Count       = [string]$_.Count
                }
            } |
            Sort-Object -Property CompareType, ColumnName

        $grouped | Format-Table -AutoSize | Out-Host
    }
}

function Compare-Csv {
<#
.SYNOPSIS
Compares two CSV files.

.DESCRIPTION
Top-level function that orchestrates CSV comparison using helper functions.

.PARAMETER Left
Full path to the left CSV file.

.PARAMETER Right
Full path to the right CSV file.

.PARAMETER Delimiter
CSV delimiter. Defaults to ','.

.PARAMETER RowIdName
Optional row ID column name.

.PARAMETER KeyColumns
Comma-separated list of key columns.

.PARAMETER ExcludeColumns
Comma-separated list of columns to exclude.

.PARAMETER ColumnTypes
Column type overrides in 'column:type' format.

.PARAMETER NullValues
Comma-separated list of null-like values.

.PARAMETER ApplyTrim
If true, trims string values.

.PARAMETER AutoDetectTypes
If true, auto-detects column types.

.PARAMETER ScanRows
Number of rows to scan for type detection.

.PARAMETER SummariseResults
If true, outputs summary; otherwise detailed rows.

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
        [string]$RowIdName = [string]::Empty,
        [Parameter(Mandatory = $true)]
        [string]$KeyColumns,
        [Parameter(Mandatory = $false)]
        [string]$ExcludeColumns = [string]::Empty,
        [Parameter(Mandatory = $false)]
        [string]$ColumnTypes = [string]::Empty,
        [Parameter(Mandatory = $false)]
        [string]$NullValues = [string]::Empty,
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

    try {
        Write-Log "Begin Step: Validate KeyColumns"
        $keyColumnsArray = Parse-List -Value $KeyColumns -Delimiter $Delimiter
        Write-Log "End Step: Validate KeyColumns"

        Write-Log "Begin Step: Validate ExcludeColumns"
        $excludeColumnsArray = Parse-List -Value $ExcludeColumns -Delimiter $Delimiter
        Write-Log "End Step: Validate ExcludeColumns"

        Write-Log "Begin Step: Validate NullValues"
        $nullValuesArray = Parse-List -Value $NullValues -Delimiter $Delimiter
        Write-Log "End Step: Validate NullValues"

        Write-Log "Begin Step: Validate ColumnTypes"
        $columnTypesArray = @()
        if ($ColumnTypes -ne '') {
            $columnTypesArray = Parse-List -Value $ColumnTypes -Delimiter $Delimiter
        }
        Write-Log "End Step: Validate ColumnTypes"

        Write-Log "Begin Step: Validate Left Path"
        Test-Path -Path $Left | Out-Null
        Write-Log "End Step: Validate Left Path"

        Write-Log "Begin Step: Validate Right Path"
        Test-Path -Path $Right | Out-Null
        Write-Log "End Step: Validate Right Path"

        Write-Log "Begin Step: Read Left File"
        $leftDataset = Read-Csv -Path $Left -Delimiter $Delimiter
        Write-Log "End Step: Read Left File"

        Write-Log "Begin Step: Read Right File"
        $rightDataset = Read-Csv -Path $Right -Delimiter $Delimiter
        Write-Log "End Step: Read Right File"

        Write-Log "Begin Step: Remove Left Columns"
        $leftDataset = Remove-Columns -Dataset $leftDataset -ExcludeColumns $excludeColumnsArray
        Write-Log "End Step: Remove Left Columns"

        Write-Log "Begin Step: Remove Right Columns"
        $rightDataset = Remove-Columns -Dataset $rightDataset -ExcludeColumns $excludeColumnsArray
        Write-Log "End Step: Remove Right Columns"

        if ($ApplyTrim) {
            Write-Log "Begin Step: Trim Left Dataset"
            $leftDataset = Trim-Dataset -Dataset $leftDataset
            Write-Log "End Step: Trim Left Dataset"

            Write-Log "Begin Step: Trim Right Dataset"
            $rightDataset = Trim-Dataset -Dataset $rightDataset
            Write-Log "End Step: Trim Right Dataset"
        }

        Write-Log "Begin Step: Nulls Left Dataset"
        $leftDataset = Apply-NullValues -Dataset $leftDataset -NullValuesArray $nullValuesArray
        Write-Log "End Step: Nulls Left Dataset"

        Write-Log "Begin Step: Nulls Right Dataset"
        $rightDataset = Apply-NullValues -Dataset $rightDataset -NullValuesArray $nullValuesArray
        Write-Log "End Step: Nulls Right Dataset"

        Write-Log "Begin Step: RowId Left Dataset"
        if ($RowIdName -ne '') {
            $leftDataset = Add-RowId -Dataset $leftDataset -RowIdName $RowIdName
        }
        Write-Log "End Step: RowId Left Dataset"

        Write-Log "Begin Step: RowId Right Dataset"
        if ($RowIdName -ne '') {
            $rightDataset = Add-RowId -Dataset $rightDataset -RowIdName $RowIdName
        }
        Write-Log "End Step: RowId Right Dataset"

        Write-Log "Begin Step: Get DataTypes Left Dataset"
        $leftDatasetColumnTypes = Get-DataTypes -Dataset $leftDataset -AutoDetectTypes $AutoDetectTypes -ScanRows $ScanRows -ColumnTypesArray $columnTypesArray
        Write-Log "End Step: Get DataTypes Left Dataset"

        Write-Log "Begin Step: Get DataTypes Right Dataset"
        $rightDatasetColumnTypes = Get-DataTypes -Dataset $rightDataset -AutoDetectTypes $AutoDetectTypes -ScanRows $ScanRows -ColumnTypesArray $columnTypesArray
        Write-Log "End Step: Get DataTypes Right Dataset"

        Write-Log "Begin Step: Cast Left Dataset"
        $leftDataset = Cast-Dataset -Dataset $leftDataset -ColumnTypes $leftDatasetColumnTypes
        Write-Log "End Step: Cast Left Dataset"

        Write-Log "Begin Step: Cast Right Dataset"
        $rightDataset = Cast-Dataset -Dataset $rightDataset -ColumnTypes $rightDatasetColumnTypes
        Write-Log "End Step: Cast Right Dataset"

        Write-Log "Begin Step: Add Key Column Left"
        $leftDataset = Add-Key -Dataset $leftDataset -KeyColumns $keyColumnsArray
        Write-Log "End Step: Add Key Column Left"

        Write-Log "Begin Step: Add Key Column Right"
        $rightDataset = Add-Key -Dataset $rightDataset -KeyColumns $keyColumnsArray
        Write-Log "End Step: Add Key Column Right"

        Write-Log "Begin Step: Get Left Keys"
        $leftKeys = Get-DistinctValues -Dataset $leftDataset -Columns @('__key')
        Write-Log "End Step: Get Left Keys"

        Write-Log "Begin Step: Get Right Keys"
        $rightKeys = Get-DistinctValues -Dataset $rightDataset -Columns @('__key')
        Write-Log "End Step: Get Right Keys"

        Write-Log "Begin Step: Check Unique Left"
        Check-KeyUnique -Dataset $leftDataset | Out-Null
        Write-Log "End Step: Check Unique Left"

        Write-Log "Begin Step: Check Unique Right"
        Check-KeyUnique -Dataset $rightDataset | Out-Null
        Write-Log "End Step: Check Unique Right"

        Write-Log "Begin Step: Compare schemas"
        $schemaResults = Compare-Schemas -LeftDatasetColumnTypes $leftDatasetColumnTypes -RightDatasetColumnTypes $rightDatasetColumnTypes
        Write-Log "End Step: Compare schemas"

        Write-Log "Begin Step: Write schema output"
        $outputSchemaOk = Output-SchemaResults -SchemaComparisonResults $schemaResults
        Write-Log "End Step: Write schema output"

        if ($outputSchemaOk) {
            Write-Log "Begin Step: Compare datasets"
            $results = Compare-Datasets -LeftDataset $leftDataset -RightDataset $rightDataset
            Write-Log "End Step: Compare datasets"

            Write-Log "Begin Step: Write output"
            Output-Results -ComparisonResults $results -SummariseResults $SummariseResults -DetailedRows $DetailedRows
            Write-Log "End Step: Write output"
        }
    } catch {
        throw
    }
}

# Sample invocation
# Defaults:
# $Left             = 'left.csv'
# $Right            = 'right.csv'
# $KeyColumns       = 'recordId'
# $ExcludeColumns   = 'columnE'
# $NullValues       = 'null'
# $ApplyTrim        = $true
# $ScanRows         = 10
# $SummariseResults = $true
# $DetailedRows     = 0

Compare-Csv -Left 'left.csv' `
            -Right 'right.csv' `
            -KeyColumns 'recordId' `
            -ExcludeColumns 'columnE' `
            -NullValues 'null' `
            -ApplyTrim $true `
            -AutoDetectTypes $true `
            -ScanRows 10 `
            -SummariseResults $false `
            -DetailedRows 100
