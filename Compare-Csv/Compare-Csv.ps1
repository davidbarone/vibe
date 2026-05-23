Set-StrictMode -Version Latest

# =========================
# Enums and Types
# =========================

enum DataTypeEnum {
    NONE     = 0
    BOOLEAN  = 1
    INTEGER  = 2
    DECIMAL  = 3
    DATETIME = 5
    STRING   = 6
}

enum CompareTypeEnum {
    KEY_LEFT_ONLY  = 1
    KEY_RIGHT_ONLY = 2
    DIFFERENT      = 3
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

# =========================
# Logging
# =========================

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    Write-Host $Message -ForegroundColor Cyan
}

# =========================
# Helper Functions
# =========================

function Parse-List {
    <#
    .SYNOPSIS
    Parses a delimited string into an array.

    .DESCRIPTION
    Takes a string input that represents a set of values delimited by a character.
    Returns an array of strings. If the input is null or empty, returns an empty array.

    .PARAMETER Value
    The input string.

    .PARAMETER Delimiter
    The delimiter character. Defaults to ','.

    .OUTPUTS
    String[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [string]$Delimiter = ','
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return @()
    }

    return @($Value.Split($Delimiter))
}

function Parse-Hashtable {
    <#
    .SYNOPSIS
    Parses a key:value,key2:value2 string into a hashtable.

    .DESCRIPTION
    Takes a string input in the format 'key1:value1,key2:value2' and converts it to a hashtable.

    .PARAMETER Value
    The input string.

    .PARAMETER PairDelimiter
    Delimiter between pairs. Defaults to ','.

    .PARAMETER KeyValueDelimiter
    Delimiter between key and value. Defaults to ':'.

    .OUTPUTS
    Hashtable
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Value = '',
        [string]$PairDelimiter = ',',
        [string]$KeyValueDelimiter = ':'
    )

    $results = @{}

    if ([string]::IsNullOrEmpty($Value)) {
        return $results
    }

    $elements = @($Value.Split($PairDelimiter))

    foreach ($element in $elements) {
        $keyValueArray = @($element.Split($KeyValueDelimiter))
        if (@($keyValueArray).Count -ne 2) {
            throw 'Input string not in correct format to convert to a hashtable!'
        }
        $key   = $keyValueArray[0]
        $value = $keyValueArray[1]
        $results[$key] = $value
    }

    return $results
}

function Test-PathCustom {
    <#
    .SYNOPSIS
    Tests that a file exists.

    .DESCRIPTION
    Takes a string input that represents a file path. Checks that the file exists.
    Throws if it does not.

    .PARAMETER Path
    The file path.

    .OUTPUTS
    Boolean
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "The file: $Path does not exist!"
    }

    return $true
}

function Read-Csv {
    <#
    .SYNOPSIS
    Reads a CSV file.

    .DESCRIPTION
    Uses Import-Csv to read a CSV file. Throws if no rows are read.

    .PARAMETER Path
    The path to the CSV file.

    .PARAMETER Delimiter
    The delimiter character.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$Delimiter = ','
    )

    $data = Import-Csv -LiteralPath $Path -Delimiter $Delimiter
    if (-not $data -or @($data).Count -eq 0) {
        throw 'Csv file contains no data!'
    }

    return @($data)
}

function Concatenate-Values {
    <#
    .SYNOPSIS
    Concatenates multiple column values into a single key string.

    .DESCRIPTION
    Used to create a composite key string from multiple columns.

    .PARAMETER Row
    The input row.

    .PARAMETER ColumnArray
    The columns to include.

    .PARAMETER Delimiter
    The delimiter used in the concatenated key.

    .OUTPUTS
    String
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Row,
        [Parameter(Mandatory = $true)]
        [string[]]$ColumnArray,
        [string]$Delimiter = '|'
    )

    $values = @()
    foreach ($col in $ColumnArray) {
        $val = $Row.$col
        if ($null -eq $val) {
            $val = ''
        } else {
            $val = [string]$val
        }
        if ($val -like "*$Delimiter*") {
            $val = $val -replace [regex]::Escape($Delimiter), "\$Delimiter"
        }
        $values += $val
    }

    return ($values -join $Delimiter)
}

function Add-Key {
    <#
    .SYNOPSIS
    Adds a __key metadata column.

    .DESCRIPTION
    Adds a metadata column '__key' to each row based on key columns.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER KeyColumns
    The key columns.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$KeyColumns
    )

    foreach ($row in $Dataset) {
        $key = Concatenate-Values -Row $row -ColumnArray $KeyColumns
        $row | Add-Member -MemberType NoteProperty -Name '__key' -Value $key -Force
    }

    return $Dataset
}

function Get-ColumnNames {
    <#
    .SYNOPSIS
    Gets column names from the first row of a dataset.

    .DESCRIPTION
    Reads the first row of a dataset to get the column names. Assumes regular shape.

    .PARAMETER Dataset
    The dataset.

    .OUTPUTS
    String[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    if (-not $Dataset -or @($Dataset).Count -eq 0) {
        return @()
    }

    $first = $Dataset[0]
    return @($first.PSObject.Properties.Name)
}

function Get-RowCount {
    <#
    .SYNOPSIS
    Gets the row count of a dataset.

    .PARAMETER Dataset
    The dataset.

    .OUTPUTS
    Int
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    return @($Dataset).Count
}

function Get-DistinctValues {
    <#
    .SYNOPSIS
    Gets distinct values for a set of columns.

    .DESCRIPTION
    Returns distinct concatenated values for the specified columns.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER Columns
    The columns to use.

    .OUTPUTS
    String[]
    #>
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

    foreach ($row in $Dataset) {
        $value = Concatenate-Values -Row $row -ColumnArray $Columns
        $ht[$value] = $row
    }

    return @($ht.Keys)
}

function Check-KeyUnique {
    <#
    .SYNOPSIS
    Checks that __key is unique.

    .DESCRIPTION
    Ensures that the '__key' column contains unique values.

    .PARAMETER Dataset
    The dataset.

    .OUTPUTS
    Boolean
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    $datasetRowCount = Get-RowCount -Dataset $Dataset
    $distinctKeys    = Get-DistinctValues -Dataset $Dataset -Columns @('__key')
    $keyRowCount     = @($distinctKeys).Count

    if ($datasetRowCount -ne $keyRowCount) {
        throw 'The key column does not contain all unique values!'
    }

    return $true
}

function Remove-Columns {
    <#
    .SYNOPSIS
    Removes unwanted columns.

    .DESCRIPTION
    Removes columns listed in ExcludeColumns from each row, except '__key'.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER ExcludeColumns
    The columns to remove.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string[]]$ExcludeColumns
    )

    $colsToRemove = $ExcludeColumns | Where-Object { $_ -ne '__key' }

    foreach ($column in $colsToRemove) {
        foreach ($row in $Dataset) {
            if ($row.PSObject.Properties.Name -contains $column) {
                $row.PSObject.Properties.Remove($column) | Out-Null
            }
        }
    }

    return $Dataset
}

function Trim-Dataset {
    <#
    .SYNOPSIS
    Trims all string cells.

    .PARAMETER Dataset
    The dataset.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset
    )

    foreach ($row in $Dataset) {
        foreach ($prop in $row.PSObject.Properties) {
            $name  = $prop.Name
            $value = $row.$name
            if ($null -eq $value) { continue }
            if ($value -is [string]) {
                $row.$name = $value.Trim()
            }
        }
    }

    return $Dataset
}

function Get-TopNValues {
    <#
    .SYNOPSIS
    Gets top N values for a column.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER ColumnName
    The column name.

    .PARAMETER TopN
    Number of values.

    .OUTPUTS
    String[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string]$ColumnName,
        [Parameter(Mandatory = $true)]
        [int]$TopN
    )

    $rowCount = Get-RowCount -Dataset $Dataset
    $i        = [Math]::Min($TopN, $rowCount)
    $output   = @()

    for ($j = 0; $j -lt $i; $j++) {
        $value = $Dataset[$j].$ColumnName
        if ($null -ne $value) {
            $output += [string]$value
        } else {
            $output += ''
        }
    }

    return $output
}

function Get-CellDataType {
    <#
    .SYNOPSIS
    Determines the data type of a string cell.

    .DESCRIPTION
    Uses regex rules to determine the data type.

    .PARAMETER Value
    The input value.

    .OUTPUTS
    DataTypeEnum
    #>
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
    Applies null-like values.

    .DESCRIPTION
    Replaces null-like values with $null. Empty strings are always treated as null.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER NullValuesArray
    The null-like values.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [string[]]$NullValuesArray = $null
    )

    $columnNames = Get-ColumnNames -Dataset $Dataset

    foreach ($columnName in $columnNames) {
        foreach ($row in $Dataset) {
            $value = $row.$columnName

            if ($NullValuesArray -ne $null -and @($NullValuesArray).Count -gt 0) {
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

    return $Dataset
}

function Add-RowId {
    <#
    .SYNOPSIS
    Adds an auto-increment row id column.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER RowIdName
    The row id column name.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [string]$RowIdName
    )

    if ([string]::IsNullOrEmpty($RowIdName)) {
        return $Dataset
    }

    $columnNames = Get-ColumnNames -Dataset $Dataset
    if ($columnNames -contains $RowIdName) {
        throw "{$RowIdName} already exists in dataset!"
    }

    $i = 1
    foreach ($row in $Dataset) {
        $row | Add-Member -MemberType NoteProperty -Name $RowIdName -Value $i -Force
        $i++
    }

    return $Dataset
}

function Get-DataTypes {
    <#
    .SYNOPSIS
    Gets data types for all columns.

    .DESCRIPTION
    Uses auto-detection and/or overrides to determine column types.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER AutoDetectTypes
    Whether to auto-detect types.

    .PARAMETER ScanRows
    Number of rows to scan.

    .PARAMETER ColumnTypesHashtable
    Column type overrides.

    .OUTPUTS
    Hashtable
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [bool]$AutoDetectTypes = $false,
        [int]$ScanRows = $null,
        [hashtable]$ColumnTypesHashtable = $null
    )

    if ($AutoDetectTypes -and (($null -eq $ScanRows) -or $ScanRows -lt 1)) {
        throw 'AutoDetectTypes is true but ScanRows is null or less than 1.'
    }

    $columnNames = Get-ColumnNames -Dataset $Dataset
    $output      = @{}

    foreach ($column in $columnNames) {
        $output[$column] = [DataTypeEnum]::STRING
    }

    if ($AutoDetectTypes) {
        foreach ($columnName in $columnNames) {
            $values    = Get-TopNValues -Dataset $Dataset -ColumnName $columnName -TopN $ScanRows
            $dataTypes = @()

            foreach ($value in $values) {
                $dt = Get-CellDataType -Value ([string]$value)
                $dataTypes += $dt
            }

            if (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::BOOLEAN }).Count -eq 0 -and @($dataTypes).Count -gt 0) {
                $output[$columnName] = [DataTypeEnum]::BOOLEAN
            } elseif (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::INTEGER }).Count -eq 0 -and @($dataTypes).Count -gt 0) {
                $output[$columnName] = [DataTypeEnum]::INTEGER
            } elseif (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::DECIMAL }).Count -eq 0 -and @($dataTypes).Count -gt 0) {
                $output[$columnName] = [DataTypeEnum]::DECIMAL
            } elseif (@($dataTypes | Where-Object { $_ -ne [DataTypeEnum]::DATETIME }).Count -eq 0 -and @($dataTypes).Count -gt 0) {
                $output[$columnName] = [DataTypeEnum]::DATETIME
            } else {
                $output[$columnName] = [DataTypeEnum]::STRING
            }
        }
    }

    if ($ColumnTypesHashtable -ne $null -and @($ColumnTypesHashtable.Keys).Count -gt 0) {
        foreach ($key in $ColumnTypesHashtable.Keys) {
            $output[$key] = [DataTypeEnum]::Parse([DataTypeEnum], $ColumnTypesHashtable[$key])
        }
    }

    return $output
}

function Cast-Dataset {
    <#
    .SYNOPSIS
    Casts dataset columns to specified types.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER ColumnTypes
    Hashtable of column types.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [hashtable]$ColumnTypes
    )

    foreach ($columnName in $ColumnTypes.Keys) {
        $type = $ColumnTypes[$columnName]

        foreach ($row in $Dataset) {
            $value = $row.$columnName
            if ($null -eq $value) { continue }

            switch ($type) {
                ([DataTypeEnum]::BOOLEAN) {
                    $parsed = $false
                    $ok = [bool]::TryParse([string]$value, [ref]$parsed)
                    if (-not $ok) {
                        throw "Value: $value cannot be converted to a BOOLEAN."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::INTEGER) {
                    $parsed = 0
                    $ok = [int]::TryParse([string]$value, [ref]$parsed)
                    if (-not $ok) {
                        throw "Value: $value cannot be converted to an INTEGER."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::DECIMAL) {
                    $parsed = [decimal]0
                    $ok = [decimal]::TryParse([string]$value, [ref]$parsed)
                    if (-not $ok) {
                        throw "Value: $value cannot be converted to a DECIMAL."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::DATETIME) {
                    $parsed = [datetime]::MinValue
                    $ok = [datetime]::TryParse([string]$value, [ref]$parsed)
                    if (-not $ok) {
                        throw "Value: $value cannot be converted to a DATETIME."
                    }
                    $row.$columnName = $parsed
                }
                ([DataTypeEnum]::STRING) {
                    # no-op
                }
                default {
                    # no-op
                }
            }
        }
    }

    return $Dataset
}

function Round-Dataset {
    <#
    .SYNOPSIS
    Rounds data in a dataset according to rules.

    .PARAMETER Dataset
    The dataset.

    .PARAMETER DatasetColumnTypes
    Column types.

    .PARAMETER RoundRulesHashtable
    Rounding rules.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$Dataset,
        [Parameter(Mandatory = $true)]
        [hashtable]$DatasetColumnTypes,
        [Parameter(Mandatory = $true)]
        [hashtable]$RoundRulesHashtable
    )

    foreach ($key in $RoundRulesHashtable.Keys) {
        if (-not ($DatasetColumnTypes.Keys -contains $key)) {
            throw "The rounding column: $key does not exist in the dataset."
        }

        $rule = $RoundRulesHashtable[$key]
        $pattern = '^(?<size>\d{1,2})(?<type>sf|dp|se|mi|hr|dy)$'
        $match = [regex]::Match($rule, $pattern)

        if (-not $match.Success) {
            throw "Rule: $rule does not match any rounding pattern!"
        }

        $size = [int]$match.Groups['size'].Value
        $type = $match.Groups['type'].Value

        if ($size -lt 1 -or $size -gt 99) {
            throw "Rounding size $size is out of range (1-99)."
        }

        $columnType = $DatasetColumnTypes[$key]

        $supported = switch ($type) {
            'sf' { @([DataTypeEnum]::INTEGER, [DataTypeEnum]::DECIMAL) }
            'dp' { @([DataTypeEnum]::DECIMAL) }
            'se' { @([DataTypeEnum]::DATETIME) }
            'mi' { @([DataTypeEnum]::DATETIME) }
            'hr' { @([DataTypeEnum]::DATETIME) }
            'dy' { @([DataTypeEnum]::DATETIME) }
        }

        if (-not ($supported -contains $columnType)) {
            throw "Rounding by $type is not support for column type $columnType"
        }

        foreach ($row in $Dataset) {
            $val = $row.$key
            if ($null -eq $val) { continue }

            switch ($type) {
                'sf' {
                    # Significant figures rounding for numeric types
                    $num = [double]$val
                    if ($num -eq 0) { continue }
                    $scale = [math]::Pow(10, $size - 1 - [math]::Floor([math]::Log10([math]::Abs($num))))
                    $row.$key = [math]::Round($num * $scale) / $scale
                }
                'dp' {
                    $row.$key = [math]::Round([double]$val, $size)
                }
                'se' {
                    $dt = [datetime]$val
                    $ticksPerUnit = [timespan]::FromSeconds($size).Ticks
                    $roundedTicks = [math]::Round($dt.Ticks / $ticksPerUnit) * $ticksPerUnit
                    $row.$key = [datetime]::new($roundedTicks)
                }
                'mi' {
                    $dt = [datetime]$val
                    $ticksPerUnit = [timespan]::FromMinutes($size).Ticks
                    $roundedTicks = [math]::Round($dt.Ticks / $ticksPerUnit) * $ticksPerUnit
                    $row.$key = [datetime]::new($roundedTicks)
                }
                'hr' {
                    $dt = [datetime]$val
                    $ticksPerUnit = [timespan]::FromHours($size).Ticks
                    $roundedTicks = [math]::Round($dt.Ticks / $ticksPerUnit) * $ticksPerUnit
                    $row.$key = [datetime]::new($roundedTicks)
                }
                'dy' {
                    $dt = [datetime]$val
                    $ticksPerUnit = [timespan]::FromDays($size).Ticks
                    $roundedTicks = [math]::Round($dt.Ticks / $ticksPerUnit) * $ticksPerUnit
                    $row.$key = [datetime]::new($roundedTicks)
                }
            }
        }
    }

    return $Dataset
}

function Compare-Schemas {
    <#
    .SYNOPSIS
    Compares two schemas.

    .PARAMETER LeftDatasetColumnTypes
    Left schema.

    .PARAMETER RightDatasetColumnTypes
    Right schema.

    .OUTPUTS
    SchemaComparisonResult[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$LeftDatasetColumnTypes,
        [Parameter(Mandatory = $true)]
        [hashtable]$RightDatasetColumnTypes
    )

    $results = @()

    foreach ($leftKey in $LeftDatasetColumnTypes.Keys) {
        $result = [SchemaComparisonResult]::new(
            $leftKey,
            $LeftDatasetColumnTypes[$leftKey],
            [DataTypeEnum]::NONE
        )
        $results += $result
    }

    foreach ($rightKey in $RightDatasetColumnTypes.Keys) {
        $existing = $results | Where-Object { $_.ColumnName -eq $rightKey }
        if ($existing) {
            $existing.RightType = $RightDatasetColumnTypes[$rightKey]
        } else {
            $result = [SchemaComparisonResult]::new(
                $rightKey,
                [DataTypeEnum]::NONE,
                $RightDatasetColumnTypes[$rightKey]
            )
            $results += $result
        }
    }

    return $results
}

function Compare-Datasets {
    <#
    .SYNOPSIS
    Compares two datasets row-by-row and column-by-column.

    .PARAMETER LeftDataset
    Left dataset.

    .PARAMETER RightDataset
    Right dataset.

    .OUTPUTS
    PSCustomObject[]
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$LeftDataset,
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$RightDataset
    )

    $results = @()

    $htLeft  = @{}
    foreach ($row in $LeftDataset) {
        $htLeft[$row.__key] = $row
    }

    $htRight = @{}
    foreach ($row in $RightDataset) {
        $htRight[$row.__key] = $row
    }

    foreach ($key in $htLeft.Keys) {
        if (-not $htRight.ContainsKey($key)) {
            $results += [pscustomobject]@{
                CompareType = [CompareTypeEnum]::KEY_LEFT_ONLY
                ColumnName  = $null
                KeyValues   = $key
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
                KeyValues   = $key
                Left        = $null
                Right       = $null
            }
        }
    }

    foreach ($key in $htLeft.Keys) {
        if ($htRight.ContainsKey($key)) {
            $leftRow  = $htLeft[$key]
            $rightRow = $htRight[$key]

            foreach ($prop in $leftRow.PSObject.Properties) {
                if ($prop.Name -eq '__key') { continue }

                $leftVal  = $leftRow.$($prop.Name)
                $rightVal = $rightRow.$($prop.Name)

                if ($leftVal -ne $rightVal) {
                    $results += [pscustomobject]@{
                        CompareType = [CompareTypeEnum]::DIFFERENT
                        ColumnName  = $prop.Name
                        KeyValues   = $key
                        Left        = [string]$leftVal
                        Right       = [string]$rightVal
                    }
                }
            }
        }
    }

    return $results
}

function Output-SchemaResults {
    <#
    .SYNOPSIS
    Outputs schema comparison results.

    .PARAMETER SchemaComparisonResults
    The schema comparison results.

    .OUTPUTS
    Boolean
    #>
    param(
        [Parameter(Mandatory = $true)]
        [SchemaComparisonResult[]]$SchemaComparisonResults
    )

    Write-Host ''
    Write-Host '--------------'
    Write-Host 'SCHEMA RESULTS' 
    Write-Host '--------------'

    $sorted = $SchemaComparisonResults | Sort-Object ColumnName
    $sorted | Format-Table -AutoSize | Out-Host

    $diffs = $SchemaComparisonResults | Where-Object { $_.LeftType -ne $_.RightType }
    if ($diffs) {
        Write-Host 'Schema differences found. Row-level comparison not performed'
        return $false
    } else {
        Write-Host 'Schemas match. Continuing to perform row-by-row comparison...'
        return $true
    }
}

function Output-Results {
    <#
    .SYNOPSIS
    Outputs comparison results.

    .PARAMETER ComparisonResults
    The comparison results.

    .PARAMETER SummariseResults
    Whether to summarise.

    .PARAMETER DetailedRows
    Max detailed rows.

    .OUTPUTS
    None
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$ComparisonResults,
        [Parameter(Mandatory = $true)]
        [bool]$SummariseResults,
        [Parameter(Mandatory = $true)]
        [int]$DetailedRows
    )

    Write-Host ''
    Write-Host '-----------------'
    Write-Host 'ROW LEVEL RESULTS'
    Write-Host '-----------------'

    if (-not $SummariseResults) {
        $ordered = $ComparisonResults |
            Sort-Object CompareType, ColumnName, KeyValues

        if ($DetailedRows -gt 0) {
            $ordered = $ordered | Select-Object -First $DetailedRows
        }

        $ordered | Format-Table -AutoSize | Out-Host
    } else {
        $resultsGrouped = @()

        $normalized = $ComparisonResults | ForEach-Object {
            [pscustomobject]@{
                CompareType = $_.CompareType
                ColumnName  = if ($null -eq $_.ColumnName) { '' } else { $_.ColumnName }
            }
        }

        $groups = $normalized | Group-Object CompareType, ColumnName

        foreach ($g in $groups) {
            $resultsGrouped += [pscustomobject]@{
                CompareType = $g.Group[0].CompareType
                ColumnName  = $g.Group[0].ColumnName
                Count       = [string](@($g.Group).Count)
            }
        }

        $resultsGrouped =
            $resultsGrouped | Sort-Object CompareType, ColumnName

        $resultsGrouped | Format-Table -AutoSize | Out-Host
    }
}

# =========================
# Top-Level Function
# =========================

function Compare-Csv {
    <#
    .SYNOPSIS
    Compares two CSV files.

    .DESCRIPTION
    Orchestrates the full CSV comparison process as per the specification.

    .PARAMETER Left
    Left CSV path.

    .PARAMETER Right
    Right CSV path.

    .PARAMETER KeyColumns
    Comma-separated key columns.

    .PARAMETER Delimiter
    CSV delimiter.

    .PARAMETER RowIdName
    Optional row id column name.

    .PARAMETER ExcludeColumns
    Comma-separated columns to exclude.

    .PARAMETER NullValues
    Comma-separated null-like values.

    .PARAMETER ColumnTypes
    Column type overrides.

    .PARAMETER RoundRules
    Rounding rules.

    .PARAMETER ApplyTrim
    Whether to trim strings.

    .PARAMETER AutoDetectTypes
    Whether to auto-detect types.

    .PARAMETER ScanRows
    Number of rows to scan for type detection.

    .PARAMETER SummariseResults
    Whether to summarise results.

    .PARAMETER DetailedRows
    Max detailed rows.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Left,
        [Parameter(Mandatory = $true)]
        [string]$Right,
        [Parameter(Mandatory = $true)]
        [string]$KeyColumns,
        [string]$Delimiter        = ',',
        [string]$RowIdName        = [string]::Empty,
        [string]$ExcludeColumns   = [string]::Empty,
        [string]$NullValues       = [string]::Empty,
        [string]$ColumnTypes      = [string]::Empty,
        [string]$RoundRules       = [string]::Empty,
        [bool]$ApplyTrim          = $false,
        [bool]$AutoDetectTypes    = $false,
        [int]$ScanRows            = $null,
        [bool]$SummariseResults   = $true,
        [int]$DetailedRows        = 0
    )

    try {
        # Validation
        Write-Log "Begin Step: Validate KeyColumns"
        $keyColumnsArray = @()
        if ($KeyColumns -ne '') {
            $keyColumnsArray = Parse-List -Value $KeyColumns
        }
        Write-Log "End Step: Validate KeyColumns"

        Write-Log "Begin Step: Validate ExcludeColumns"
        $excludeColumnsArray = @()
        if ($ExcludeColumns -ne '') {
            $excludeColumnsArray = Parse-List -Value $ExcludeColumns
        }
        Write-Log "End Step: Validate ExcludeColumns"

        Write-Log "Begin Step: Validate NullValues"
        $nullValuesArray = @()
        if ($NullValues -ne '') {
            $nullValuesArray = Parse-List -Value $NullValues
        }
        Write-Log "End Step: Validate NullValues"

        Write-Log "Begin Step: Validate ColumnTypes"
        $columnTypesHashtable = Parse-Hashtable -Value $ColumnTypes
        Write-Log "End Step: Validate ColumnTypes"

        Write-Log "Begin Step: Validate RoundRules"
        $RoundRulesHashtable = @{}
        if ($RoundRules -ne '') {
            $RoundRulesHashtable = Parse-Hashtable -Value $RoundRules
        }
        Write-Log "End Step: Validate RoundRules"

        Write-Log "Begin Step: Validate Left Path"
        Test-PathCustom -Path $Left | Out-Null
        Write-Log "End Step: Validate Left Path"

        Write-Log "Begin Step: Validate Right Path"
        Test-PathCustom -Path $Right | Out-Null
        Write-Log "End Step: Validate Right Path"

        # Read
        Write-Log "Begin Step: Read Left File"
        $leftDataset = Read-Csv -Path $Left -Delimiter $Delimiter
        Write-Log "End Step: Read Left File"

        Write-Log "Begin Step: Read Right File"
        $rightDataset = Read-Csv -Path $Right -Delimiter $Delimiter
        Write-Log "End Step: Read Right File"

        # Processing
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
        $leftDatasetColumnTypes = Get-DataTypes -Dataset $leftDataset -AutoDetectTypes $AutoDetectTypes -ScanRows $ScanRows -ColumnTypesHashtable $columnTypesHashtable
        Write-Log "End Step: Get DataTypes Left Dataset"

        Write-Log "Begin Step: Get DataTypes Right Dataset"
        $rightDatasetColumnTypes = Get-DataTypes -Dataset $rightDataset -AutoDetectTypes $AutoDetectTypes -ScanRows $ScanRows -ColumnTypesHashtable $columnTypesHashtable
        Write-Log "End Step: Get DataTypes Right Dataset"

        Write-Log "Begin Step: Cast Left Dataset"
        $leftDataset = Cast-Dataset -Dataset $leftDataset -ColumnTypes $leftDatasetColumnTypes
        Write-Log "End Step: Cast Left Dataset"

        Write-Log "Begin Step: Cast Right Dataset"
        $rightDataset = Cast-Dataset -Dataset $rightDataset -ColumnTypes $rightDatasetColumnTypes
        Write-Log "End Step: Cast Right Dataset"

        Write-Log "Begin Step: Round Left Dataset"
        $leftDataset = Round-Dataset -Dataset $leftDataset -DatasetColumnTypes $leftDatasetColumnTypes -RoundRulesHashtable $RoundRulesHashtable
        Write-Log "End Step: Round Left Dataset"

        Write-Log "Begin Step: Round Right Dataset"
        $rightDataset = Round-Dataset -Dataset $rightDataset -DatasetColumnTypes $rightDatasetColumnTypes -RoundRulesHashtable $RoundRulesHashtable
        Write-Log "End Step: Round Right Dataset"

        Write-Log "Begin Step: Add Key Column Left"
        $leftDataset = Add-Key -Dataset $leftDataset -KeyColumns $keyColumnsArray
        Write-Log "End Step: Add Key Column Left"

        Write-Log "Begin Step: Add Key Column Right"
        $rightDataset = Add-Key -Dataset $rightDataset -KeyColumns $keyColumnsArray
        Write-Log "End Step: Add Key Column Right"

        Write-Log "Begin Step: Get Left Keys"
        $leftKeys = Get-DistinctValues -Dataset $leftDataset -Columns $keyColumnsArray
        Write-Log "End Step: Get Left Keys"

        Write-Log "Begin Step: Get Right Keys"
        $rightKeys = Get-DistinctValues -Dataset $rightDataset -Columns $keyColumnsArray
        Write-Log "End Step: Get Right Keys"

        Write-Log "Begin Step: Check Unique Left"
        [void](Check-KeyUnique -Dataset $leftDataset)
        Write-Log "End Step: Check Unique Left"

        Write-Log "Begin Step: Check Unique Right"
        [void](Check-KeyUnique -Dataset $rightDataset)
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
    }
    catch {
        throw
    }
}

# =========================
# Sample Invocation
# =========================

# Defaults per spec:
# $Left             : 'left.csv'
# $Right            : 'right.csv'
# $KeyColumns       : 'recordId'
# $ExcludeColumns   : 'columnE'
# $NullValues       : 'null'
# $ApplyTrim        : $true
# $ScanRows         : 10

Compare-Csv `
    -Left 'left.csv' `
    -Right 'right.csv' `
    -KeyColumns 'recordId' `
    -ExcludeColumns 'columnE' `
    -NullValues 'null' `
    -ApplyTrim $true `
    -ScanRows 10 `
    -SummariseResults $false `
    -DetailedRows 500 `
    -AutoDetectTypes $true `
    -RoundRules 'columnA:1mi,columnB:1dp'
