# Specification for a Csv Compare Tool Written in PowerShell

## Purpose
The purpose of this tool is to compare 2 csv files, and output differences between the 2 files. The user is able to invoke the comparison function and provide a number of parameters to control the way that the comparison is performed. The comparison works by identifying key column(s) in each of the files then doing a row-by-row, column-by-column comparison of the values. The tool attempts to convert all columns to the correct data types prior to comparing values. The tool outputs comparison information so that the user is able to determine whether the 2 csv files are the same, and where there are any differences. Output can be configured to be either summary information, or detailed row-level information.

## Business Requirements
- The user should be able to invoke a Powershell function and pass in various parameter to enable a csv comparison between 2 csv files to take place.
- Output regarding the comparison results will be sent to the console / standard output.
- It is assumed that the 2 csv files being compared are valid csv files according to  RFC 4180. The Csv Compare tool is not required to build in any additional smart to detect non-csv-compliant files.

## Non Functional Requirements
- The solution generated should be modular so that the overall solution has a minimal amount of lines of code. It can be split over multiple PowerShell module files.
- The Powershell .ps1 files generated should use 100% vanilla PowerShell. No external libraries are to be used. For example, no VisualBasic libraries should be used.
- Set-StrictMode should be used.
- The code generated should be verified to be 100% runnable PowerShell code. In particular:
  - When using `TryParse` functions with a `[ref]` parameter, the parameter must be previously initialised to a non `$null` value.
  - Where statements are generated over multiple lines, check that the line continuation character (back-tick) is correctly used.
- When dealing with arrays in Set-StrictMode, to prevent issues with unboxing arrays, ensure that all arrays are forced to be arrays by wrapping them in the `@()` array subexpression.
  - Before calling `.Count` on an array, make sure to use the array subexpression operator `@(...)` around the array first.
- All functions should be fully commented with standard sections like .SYNOPSIS, .DESCRIPTION etc.
- The solution generated should adhere to the function structure defined in this specification. However, additional functions may be added if required. 
- The solution generated should be refactored as much as possible so that any repeated code is extracted into additional functions as required.
- Logging should be implemented. Logging statements should be added around each step in the top-level function according to the table of steps shown below.
  - Before each step, log 'Begin Step: $step' (where $step is the value in the 'Step' column in the table below).
  - After each step, log 'End Step: $step' (where $step is the value in the 'Step' column in the table below).
  - Logging should be output to the console / standard output with cyan foreground colour:
- A sample PowerShell script should be included in the AI generated output to invoke an example call to `Compare-Csv`, with the following defaults:
  - `$Left`: 'left.csv'
  - `$Right`: 'right.csv'
  - `$KeyColumns`: 'recordId'
  - `$ExcludeColumns`: 'columnE'
  - `$NullValues`: 'null'
  - `$ApplyTrim`: `$true`
  - `$ScanRows`: 10
  - `$AutoDetectTypes`: `$true`
  - `$RoundRules`: 'columnA:1mi,columnB:1dp'
- Include 2 test csv files for use with the script. The files should be called 'left.csv' and 'right.csv' and have the following properties:
  - Both should be valid CSV files.
  - Both csv files should have columns: recordId, columnA, columnB, columnC, columnD.
    - recordId should be an incrementing `Integer`.
    - columnA should be a `DateTime` and should represent a date-time in the past 12 months.
    - columnB should be a `Decimal` and should represent an amount between 0 and 100.
    - columnC should be an `Integer` and should represent an amount between 0 and 1000.
    - columnD should be a `String` and should represent a random color.
  - In addition, right.csv should include column called 'columnE' which is a `String` column and should represent a random animal
  - Populate both tables with 50 rows of random data. With approximately 90% of the data matching between left.csv and right.csv Include a couple of recordId values in left.csv which don't exist in right.csv and vice versa.
- The generated PowerShell code should be put into a single .ps1 file, and all functions should be public. This single file should include:
  - All helper functions
  - The main top-level function
  - The sample invocation code to `Compare-Csv`

## Architecture
The following lays out the general architecture of the solution.
- The solution should be developed in PowerShell. This enables the solution to be easily extended without requiring a complex development tool stack.
- AI code generation will be used to generate the source code. This document acts as the human specification or human source and will be passed to the AI tool so that PowerShell source can be generated.
- The PowerShell solution generated should be modularised so that functions are created to perform distinct parts of the compare process.
- There should be a single top-level public function (called 'Compare-Csv') that the user calls to perform the csv comparison. This function should a set of parameters to allow the user to customise the comparison process.
- The public function should do the following high-level tasks:
  - Validate the input parameters
  - Read in the 2 csv files
  - Perform various preprocessing to get the data into a fit state for comparison
  - Perform the comparison between the 2 csv files
  - Output results
- The solution will be written in a modular fashion, with the overall process being broken down into a series of discrete steps. Each step should do a very specific thing. The top-level public function will orchestrate the overall comparison process by calling the helper functions in a particular order. 
- UTF8 encoding should be used.

## Inputs
The following parameters should defined on the main public function:

| Parameter Name      | Data Type | Mandatory | Default           | Purpose                                                                                                                                                   |
| ------------------- | --------- | --------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `$Left`             | `String`  | yes       |                   | The full file path of the first CSV file.                                                                                                                 |
| `$Right`            | `String`  | yes       |                   | The full file path of the second CSV file.                                                                                                                |
| `$KeyColumns`       | `String`  | yes       |                   | If set, should be a comma-separated list of key columns. Used during the COMPARE process.                                                                 |
| `$Delimiter`        | `String`  | no        | ','               | The delimiter used in the csv file. Defaults to a comma character (',').                                                                                  |
| `$RowIdName`        | `String`  | no        | `[string]::Empty` | If set, then an additional integer column of the same name as the rowIdName parameter is created in both the left and right datasets.                     |
| `$ExcludeColumns`   | `String`  | no        | `[string]::Empty` | If set, should be a comma-separated list of columns to exclude from all processing (EXCLUDE LEFT and EXCLUDE RIGHT steps).                                |
| `$NullValues`       | `String`  | no        | `[string]::Empty` | If set, should be a comma-separated list of values to be considered as null (for example 'null,-,(null)')                                                 |
| `$ColumnTypes`      | `String`  | no        | `[string]::Empty` | Optional parameter. If set, is specification of columns. Not all columns need types specified. Example format is 'columnA:INTEGER,columnB:STRING'.        |
| `$RoundRules`       | `String`  | no        | `[string]::Empty` | If set, should be a comma-separated list of rounding rules. Example format is 'columnA:2dp,columnB:5mi'.                                                  |
| `$ApplyTrim`        | `Boolean` | no        | `$false`          | If set, then all string values read in are trimmed prior to further processing (TRIM LEFT and TRIM RIGHT steps).                                          |
| `$AutoDetectTypes`  | `Boolean` | no        | `$false`          | If set, then column data types are auto-detected.                                                                                                         |
| `$ScanRows`         | `Integer` | no        | `$null`           | This parameter is used to control the number of rows scanned in the left and right datasets when calculating data types (SCAN LEFT and SCAN RIGHT steps). |
| `$SummariseResults` | `Boolean` | no        | `$true`           | If set to `$true`, then summary results are produced. Otherwise detailed results are produced.                                                            |
| `$DetailedRows`     | `Integer` | no        | 0                 | This parameter is used to limit the number of detailed results output.                                                                                    |

## Top-Level Function

### Name
The name of the function will be 'Compare-Csv'.

### Purpose
This function is the single top-level function that the user calls to compare 2 csv files. The function will orchestrate a number of steps to complete the compare process. Refer to the steps section below for a detailed specification of steps to execute.

### Steps
The function will perform the following steps in sequential order:

| Step Group | Step                        | Precondition              | Function to Call       | Parameters to Pass In                                                     | Variable To Assign Result To | Description / Notes                                    |
| ---------- | --------------------------- | ------------------------- | ---------------------- | ------------------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------ |
| Validation | Validate KeyColumns         | n/a                       | `Parse-List`           | `$KeyColumns`                                                             | `$keyColumnsArray`           | Parses the `$KeyColumns` parameter into an array.      |
| Validation | Validate ExcludeColumns     | n/a                       | `Parse-List`           | `$ExcludeColumns`                                                         | `$excludeColumnsArray`       | Parses the `$ExcludeColumns` parameter into an array.  |
| Validation | Validate NullValues         | n/a                       | `Parse-List`           | `$NullValues`                                                             | `$nullValuesArray`           | Parses the `$NullValues` parameter into an array.      |
| Validation | Validate ColumnTypes        | n/a                       | `Parse-Hashtable`      | `$ColumnTypes`                                                            | `$columnTypesHashtable`      | Parses the `$ColumnTypes` parameter into a hashtable.  |
| Validation | Validate RoundRules         | n/a                       | `Parse-Hashtable`      | `$RoundRules`                                                             | `$RoundRulesHashtable`       | Parses the `$RoundRules` parameter into aa hashtable.  |
| Validation | Validate Left Path          | n/a                       | `Test-Path`            | `$Left`                                                                   | n/a                          | Checks that the left csv file exists.                  |
| Validation | Validate Right Path         | n/a                       | `Test-Path`            | `$Right`                                                                  | n/a                          | Checks that the right csv file exists.                 |
| Read       | Read Left File              | n/a                       | `Read-Csv`             | `$Left`, `$Delimiter`                                                     | `$leftDataset`               | Reads left csv file into dataset object.               |
| Read       | Read Right File             | n/a                       | `Read-Csv`             | `$Right`, `$Delimiter`                                                    | `$rightDataset`              | Reads right csv file into dataset object.              |
| Processing | Remove Left Columns         | n/a                       | `Remove-Columns`       | `$leftDataset`, `$excludeColumnsArray`                                    | `$leftDataset`               | Removes any unwanted columns from the left dataset.    |
| Processing | Remove Right Columns        | n/a                       | `Remove-Columns`       | `$rightDataset`, `$excludeColumnsArray`                                   | `$rightDataset`              | Removes any unwanted columns from the right dataset.   |
| Processing | Trim Left Dataset           | `$ApplyTrim` = `$true`    | `Trim-Dataset`         | `$leftDataset`                                                            | `$leftDataset`               | Trims cells in left dataset.                           |
| Processing | Trim Right Dataset          | `$ApplyTrim` = `$true`    | `Trim-Dataset`         | `$rightDataset`                                                           | `$rightDataset`              | Trims cells in right dataset.                          |
| Processing | Nulls Left Dataset          | n/a                       | `Apply-NullValues`     | `$leftDataset`, `$nullValuesArray`                                        | `$leftDataset`               | Sets null values in left dataset.                      |
| Processing | Nulls Right Dataset         | n/a                       | `Apply-NullValues`     | `$rightDataset`, `$nullValuesArray`                                       | `$rightDataset`              | Sets null values in right dataset.                     |
| Processing | RowId Left Dataset          | n/a                       | `Add-RowId`            | `$leftDataset`, `$RowIdName`                                              | `$leftDataset`               | Adds row id in left dataset.                           |
| Processing | RowId Right Dataset         | n/a                       | `Add-RowId`            | `$rightDataset`, `$RowIdName`                                             | `$rightDataset`              | Adds row id in right dataset.                          |
| Processing | Get DataTypes Left Dataset  | n/a                       | `Get-DataTypes`        | `$leftDataset`, `$AutoDetectTypes`, `$ScanRows`, `$columnTypesHashtable`  | `$leftDatasetColumnTypes`    | Gets column types in left dataset.                     |
| Processing | Get DataTypes Right Dataset | n/a                       | `Get-DataTypes`        | `$rightDataset`, `$AutoDetectTypes`, `$ScanRows`, `$columnTypesHashtable` | `$rightDatasetColumnTypes`   | Gets column types in right dataset.                    |
| Processing | Cast Left Dataset           | n/a                       | `Cast-Dataset`         | `$leftDataset`, `$leftDatasetColumnTypes`                                 | `$leftDataset`               | Casts columns in left dataset.                         |
| Processing | Cast Right Dataset          | n/a                       | `Cast-Dataset`         | `$rightDataset`, `$rightDatasetColumnTypes`                               | `$rightDataset`              | Casts columns in right dataset.                        |
| Processing | Round Left Dataset          | n/a                       | `Round-Dataset`        | `$leftDataset`, `$leftDatasetColumnTypes`, `$RoundRulesHashtable`         | `$leftDataset`               | Rounds values in columns in left dataset.              |
| Processing | Round Right Dataset         | n/a                       | `Round-Dataset`        | `$rightDataset`, `$rightDatasetColumnTypes`, `$RoundRulesHashtable`       | `$rightDataset`              | Rounds values in columns in right dataset.             |
| Processing | Add Key Column Left         | n/a                       | `Add-Key`              | `$leftDataset`, `$keyColumnsArray`                                        | `$leftDataset`               | Adds a new metadata column __key to the left file.     |
| Processing | Add Key Column Right        | n/a                       | `Add-Key`              | `$rightDataset`, `$keyColumnsArray`                                       | `$rightDataset`              | Adds a new metadata column __key to the right file.    |
| Processing | Get Left Keys               | n/a                       | `Get-DistinctValues`   | `$leftDataset`, `$keyColumnsArray`                                        | `$leftKeys`                  | Gets all the unique keys in the left csv file.         |
| Processing | Get Right Keys              | n/a                       | `Get-DistinctValues`   | `$rightDataset`, `$keyColumnsArray`                                       | `$rightKeys`                 | Gets all the unique keys in the right csv file.        |
| Processing | Check Unique Left           | n/a                       | `Check-KeyUnique`      | `$leftDataset`                                                            | n/a                          | Checks that the left csv file key columns are unique.  |
| Processing | Check Unique Right          | n/a                       | `Check-KeyUnique`      | `$rightDataset`                                                           | n/a                          | Checks that the right csv file key columns are unique. |
| Processing | Compare schemas             | n/a                       | `Compare-Schemas`      | `$leftDatasetColumnTypes`, `$rightDatasetColumnTypes`                     | `$schemaResults`             | Compares the 2 schemas.                                |
| Output     | Write schema output         | n/a                       | `Output-SchemaResults` | `$schemaResults`                                                          | `$outputSchemaOk`            | Writes schema results to console.                      |
| Processing | Compare datasets            | `$outputSchemaOk`=`$true` | `Compare-Datasets`     | `$leftDataset`, `$rightDataset`                                           | `$results`                   | Compares the 2 datasets.                               |
| Output     | Write output                | `$outputSchemaOk`=`$true` | `Output-Results`       | `$results`, `$SummariseResults`, `$DetailedRows`                          | n/a                          | Writes results to console.                             |

### Notes:
1. When calling the above functions in order, the overall process should stop immediately if any step / function throws an exception.

## Helper Functions
This section includes a list of helper functions used by the top-level function. Each does a specific part of the overall csv compare process.

### Parse-List

#### Purpose
Takes a string input that represents a set of values delimited by a character (e.g. comma character). Splits the string input by that character, ensuring that an array is always returned. Note special cases below:
- If the input string is null or empty, the return value is an empty array (0 elements)
- If the input string is a single value with no delimiters, the return value is an array with a single element

#### Parameters
| Parameter Name | Data Type | Mandatory | Default | Purpose                        |
| -------------- | --------- | --------- | ------- | ------------------------------ |
| `$Value`       | `String`  | `$false`  | ''      | The input string               |
| `$Delimiter`   | `String`  | No        | ','     | The string delimiter character |

#### Processing
- If `$Value` is `$null` or an empty string return an empty array `@()`.
- Otherwise, split `$Value` using the `$Delimiter` character, and return the array, wrapping the result in `@(...)` to ensure an array is returned even if there is only 1 element in the array.

#### Output
Returns a string array.

### Parse-Hashtable

#### Purpose
Takes a string input in the format: 'key1:value1,key2:value2,key3:value3' and converts to a hashtable:
``` ps
@{
   "key1" = "value1"
   "key2" = "value2"
   "key3" = "value3"
}
```

#### Parameters
| Parameter Name       | Data Type | Mandatory | Default | Purpose                                                                     |
| -------------------- | --------- | --------- | ------- | --------------------------------------------------------------------------- |
| `$Value`             | `String`  | `$false`  | ''      | The input string                                                            |
| `$PairDelimiter`     | `String`  | No        | ','     | The string delimiter character to separate each element in the hashtable    |
| `$KeyValueDelimiter` | `String`  | No        | ':'     | The string delimiter character to separate an individual key from its value |

#### Exceptions
An exception is thrown if the input string `$Value` is not in the correct format to convert to a hashtable.

#### Processing
1. Create a new variable `$results` of type `hashtable`.
2. If `$Value` is $null or empty string, return an empty hashtable @{}.
3. Split `$Value` string by the `$PairDelimiter` character. Assign the result to a variable `$elements` of type `String[]`.
4. For each `$element` in `$elements`:
   1. Split `$element` by the `$KeyValueDelimiter` character. Assign the result to a variable `$keyValueArray` of type `String[]`.
   2. if `$keyValueArray.Count` != 2 then throw an exception: 'Input string not in correct format to convert to a hashtable!'.
   3. Create a new key-value pair `$kvp` and assign:
      1. `$kvp.Key` = `$keyValueArray[0]`.
      2. `$kvp.Value` = `$keyValueArray[1]`.
   4. Add `$kvp` to `$results`.
5. Return `$results`.

#### Returns
Returns a hashtable containing the keys and values specified in the input string.

### Test-Path

#### Purpose
Takes a string input that represents a file path. Checks that the file exists. If the file does not exist then throws an exception.

#### Parameters
| Parameter Name | Data Type | Mandatory | Default | Purpose            |
| -------------- | --------- | --------- | ------- | ------------------ |
| `$Path`        | `String`  | Yes       | n/a     | The path of a file |

#### Exceptions
Throws an exception of 'The file: $Path does not exist!' if the file denoted by `$Path` does not exist.

#### Output
Returns `$true` if the file exists. Otherwise throws an exception with message: "The file: $Path does not exist!". 

### Read-Csv

#### Purpose
Reads a csv file using the standard PowerShell function: `Import-Csv`.

| Parameter Name | Data Type | Mandatory | Default | Purpose                  |
| -------------- | --------- | --------- | ------- | ------------------------ |
| `$Path`        | `String`  | Yes       | n/a     | The path to the csv file |
| `$Delimiter`   | `String`  | No        | ','     | The  delimiter character |

#### Exceptions
Throws an exception of 'Csv file contains no data!' if there are no rows read.

#### Output
Returns a `PSCustomObject[]` array of elements. Each element in the return object represents 1 row of the csv file. Each property name in a single `PSCustomObject` object represents the csv column name, and the property value of a single `PSCustomObject` object represents a single row cell value in the csv file.

### Concatenate-Values

#### Purpose
Concatenates multiple values on a row into a single value. Used for to create a single key value when a composite key is defined on a table.

#### Parameters
| Parameter Name | Data Type        | Mandatory | Default                         | Purpose           |
| -------------- | ---------------- | --------- | ------------------------------- | ----------------- |
| `$Row`         | `PSCustomObject` | Yes       | n/a                             | The input row     |
| `$columnArray` | `String[]`       | Yes       | n/a                             | The columns array |
| `$Delimiter`   | `String`         | No        | ASCII char 124 (pipe character) | The key delimiter |

#### Processing
1. Get all the property values in the row for each property names that exist in the `$columnsArray` array.
2. Concatenate all the above values using `$Delimiter` as the concatenation character, with the following rules being applied to each value before concatenation:
   1. `$null` value should be converted to empty string.
   2. Each non `$null` value should be cast to a string before concatenation.
   3. If the string value contains a value matching `$Delimiter` then this should be escaped in the value by using a backslash prior to the delimiter character.
3. Return the resulting concatenated string.

#### Returns
Returns a string value representing the concatenation of row values (each cast to string). Null values are converted to empty space ('') before doing the concatenation.

### Add-Key

#### Purpose
Adds a metadata column called '__key' to a dataset to allow a single-column key to exist. Makes comparisons easier when composite key is defined on the data.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose               |
| -------------- | ------------------ | --------- | ------- | --------------------- |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset     |
| `$KeyColumns`  | `String[]`         | Yes       | n/a     | The key columns array |

#### Processing
1. For each row `$row` in `$Dataset`:
   1. Call `Concatenate-Values` passing in the values of `$row`, `$KeyColumns`. Assign the result to a local variable: `$key`
   2. Add a new property '__key' to the `$row` object using the syntax: `$row | Add-Member -MemberType NoteProperty -Name '__key' -Value $key`
2. Return `$Dataset`

#### Returns
Returns the `$Dataset` object, but with an additional key column called '__key' added.

### Get-DistinctValues

#### Purpose
Returns the distinct values in a dataset for a column. Used to get the set of distinct key values in a dataset.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose                                    |
| -------------- | ------------------ | --------- | ------- | ------------------------------------------ |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset                          |
| `$Columns`     | `String[]`         | Yes       | n/a     | The columns to get the distinct values for |

#### Processing
1. Get the names of all the columns in the dataset by calling `Get-ColumnNames` with the parameter of `Dataset`. Assigns the result to a variable called `$datasetColumns`.
2. For each `$column` in `$Columns` check that `$column` exists in `$datasetColumns`. If not, throw an exception: 'Column `$column` does not exist in dataset.'.
3. Create a new variable called `$ht` of type `hashtable` to store the distinct values.
4. Loop through each row in the dataset and do the following for each row:
   1. For each row, `$row` in the dataset, get a single string value by calling the `Concatenate-Values` function, passing in parameters of `$row`, `$Columns`. Assign the result to a variable `$value`.
   2. Set the `$ht[$value]` to `$row`.
5. Return the keys in `$ht`, i.e. `$ht.Keys`. This will be the distinct set of values of the keys, with each key (if a composite key) reduced to a delimited string value.

#### Exceptions
Throw an exception of 'Column `$column` does not exist in dataset.' if any of the `$column` elements in the `$Columns` array parameter do not exist in the `$datasetColumns` array.

#### Returns
Returns a `String[]` array containing the set of distinct values. Each element in the array is a string representation of the distinct values being compared.

### Get-ColumnNames

#### Purpose
Reads the 1st row of a dataset to get the columns names. Assumes that the dataset is regular in shape and all rows have the same columns (which should be true for a csv file). Column names are exactly as written in the csv file. If the header row contains spaces, these will for part of the name. For example, if the csv header row is 'columna, columnb ,columnc', then this will result in column names:
- 'columna'
- ' columnb '
- 'columnc'

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose           |
| -------------- | ------------------ | --------- | ------- | ----------------- |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset |

#### Output
Returns a `String[]` object containing a list of column names.

### Get-RowCount

#### Purpose
Gets the row count for a dataset. A dataset is simply an `PSCustomObject[]` array. The row count is calculated simply as the count of elements in the array.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose           |
| -------------- | ------------------ | --------- | ------- | ----------------- |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset |

#### Returns
Returns an `Integer` value representing the count of rows in the `$Dataset` array.

### Check-KeyUnique

#### Purpose
Checks that the '__key' column for a csv file contain unique values for the entire file.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose           |
| -------------- | ------------------ | --------- | ------- | ----------------- |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset |

#### Exceptions
If `$datasetRowCount` != `$keyRowCount` as detailed in the processing section below, throw an exception: 'The key column does not contain all unique values!`.

#### Processing
1. Calculate the number of rows in `$Dataset`. Call the `Get-RowCount` passing in `$Dataset`, and assign the result to a variable `$datasetRowCount`.
2. Calculate the number of distinct key values in the dataset by calling `Get-DistinctValues` passing in parameters of `$Dataset` and the literal key names: `@('__key')`. Count the count of the return array to a variable `$keyRowCount`.
4. Return `$true` if `$datasetRowCount` = `$keyRowCount`. Otherwise throw an exception.

#### Returns
Returns true if the key columns include no duplicates.

### Remove-Columns

#### Purpose
Removes unwanted columns from an array of `PSCustomObject` elements.

#### Parameters
| Parameter Name    | Data Type          | Mandatory | Default | Purpose               |
| ----------------- | ------------------ | --------- | ------- | --------------------- |
| `$Dataset`        | `PSCustomObject[]` | Yes       | n/a     | The input dataset     |
| `$ExcludeColumns` | `String[]`         | Yes       | n/a     | The columns to remove |

#### Processing
1. For each `$column` in `$ExcludeColumns` except '__key' if specified (which is an internal column and should never be deleted):
   1. For each row `$row` in `$Dataset`
      1. if `$row` contains the property `$column`, then remove the column
      2. If `$row` does not contain the property `$column`, continue. Do not raise an exception.
2. Return `$Dataset`.

#### Returns
Returns the `$Dataset` object, but with columns removed.

### Trim-Dataset

#### Purpose
Trims all string cells in a dataset.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose           |
| -------------- | ------------------ | --------- | ------- | ----------------- |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset |

#### Processing
1. For each `$row` in `$Dataset`.
2. For each property `$name` in `$row`.
   1. If the value of `$row[$name]` is `$null`, then continue.
   2. If the data type of `$row[$name]` is `String`, then trim the value.
3. Return `$Dataset`

#### Returns
Returns the `$Dataset` object, but with all text cells trimmed.

### Get-DataTypes

#### Purpose
Gets the data types of all columns in a dataset. The data types are defined in a custom enum: `DataTypeEnum` defined elsewhere in this specification.
Column types are by default `STRING` unless another type is detected during auto detect scanning (`$AutoDetectTypes` = `$true`), or the user manually specifies column types. Any manually specified column types override auto-detected types.

#### Assumptions
It is assumed that `$Dataset` contains an array of elements. `Get-DataTypes` must always run BEFORE `Cast-Dataset`. The cell values at this point are normally strings, but there are cases when this is not the case (for example, if a RowID column is added, this will contain integer values).

#### Parameters
| Parameter Name          | Data Type          | Mandatory | Default | Purpose                                                                                                         |
| ----------------------- | ------------------ | --------- | ------- | --------------------------------------------------------------------------------------------------------------- |
| `$Dataset`              | `PSCustomObject[]` | Yes       | n/a     | The input dataset                                                                                               |
| `$AutoDetectTypes`      | `Boolean`          | No        | $false  | Set to true to auto-detect types                                                                                |
| `$ScanRows`             | `Integer`          | No        | $null   | Defines the number of rows to scan to guess the data types                                                      |
| `$ColumnTypesHashtable` | `hashtable`        | No        | $null   | Optional parameter specifying column type overrides as an array. Keys are column names, values are column types |

#### Validations
The function should perform the following validations at the start of the function:
- If `$AutoDetectTypes` = `$true`, then `$ScanRows` must be != `$null`, and must be > 0. Throw an exception if `$AutoDetectTypes` = `$true`, and (`$ScanRows` = `$null` OR `$ScanRows` < 1)

#### Processing
1. Get the column names for the dataset, by calling the `Get-ColumnNames` function, passing in `$Dataset`. Assign the result to a variable called `$columnNames`.
2. Create a variable called `$output` of type `hashtable` to store the results. The key will be the column name, and the value (type `DataTypeEnum`) will be the data type of the column.
3. Initialise the `$output` hashtable. For each `$column` in `$columnNames`, add a key-value pair into $output as follows:
   1. Key = `$column`
   2. Value = `DataTypeEnum.STRING`
4. If `$AutoDetectTypes` is set to `$true`, then calculate the data types of each column as follows:
   1. For each `$columnName` in `$columnNames`:
      1. Get the top n rows for that column, by calling the function `Get-TopNValues`, passing in `$Dataset`, `$columnName`, and `$ScanRows`. Assign the result to a variable: `$values`.
      2. Create a variable with local scope within the `$columNames` loop called `$dataTypes` of type `DataTypeEnum[]`.
      3. For each `$value` in `$values`:
         1. Call the `Get-CellDataType` function, passing in `$value` (cast to a string). Add the result to the `$dataTypes` array.  
      4. Update `$output[$columnName]` to be one of the following values:
      5. `DataTypeEnum.BOOLEAN` if all values in `$dataTypes` are `DataTypeEnum.BOOLEAN`
      6. `DataTypeEnum.INTEGER` if all values in `$dataTypes` are `DataTypeEnum.INTEGER`
      7. `DataTypeEnum.DECIMAL` if all values in `$dataTypes` are `DataTypeEnum.DECIMAL`
      9. `DataTypeEnum.DATETIME` if all values in `$dataTypes` are `DataTypeEnum.DATETIME`
      10. Otherwise `DataTypeEnum.STRING`
5. If `$ColumnTypesHashtable` is set to a non `$null` value (!= `$null`) and contains at least 1 key, then do the following for each key `$key` in `$ColumnTypesHashtable.Keys`:
      1. Update `$output`, setting `$output[$key]` to `$ColumnTypesHashtable[$key]` (cast as a `DataTypeEnum` type).  
6. Return the variable `$output`

#### Returns
Returns a `hashtable`. The keys are the column names and are of type `String`. Each key value denotes the column type and is of type: `DataTypeEnum`.

### Get-TopNValues
Gets the top-n values of a single column for a dataset.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose                        |
| -------------- | ------------------ | --------- | ------- | ------------------------------ |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset              |
| `$ColumnName`  | `String`           | Yes       | n/a     | The name of the column         |
| `$TopN`        | `Integer`          | Yes       | n/a     | The number of values to return |

#### Processing
1. Get the row count of the input dataset, by calling `Get-RowCount`, passing in a parameter of `$Dataset`. Assign the result to the variable `$rowCount`.
2. Create a variable `$output` of type `String[]`
3. Create a variable called `$i` which is the lower of `$TopN` and `$rowCount`
4. Create a loop, with iterator of `$j` which loops from `0 to $i-1`
   1. For each iteration of the loop, read the `$ColumnName` property value from `$j`-th data row from $Dataset (0-index) and add the string value to `$output`.
5. return `$output`

#### Returns
Returns a `String[]` array of values.

### Get-CellDataType

#### Purpose
Parses a string cell value in a csv file, and determines the data type based on the format of the string and regex rules. See the **Regex Rules** section below.

#### Assumptions
- Values should already be trimmed at this point. However, this function trims again to be sure.
- Regex matching should be case-sensitive. If any case-insensitive matching is required, this should be specified individually in the regex rules below (e.g. `(?i)`).

#### DataTypeEnum enum
A `DataTypeEnum` enum is defined as follows:

| Enum     | Value | Notes                                                                |
| -------- | ----- | -------------------------------------------------------------------- |
| NONE     | 0     | Represents absence of data type or column (similar to a null value). |
| BOOLEAN  | 1     | Represents a boolean value (true/false)                              |
| INTEGER  | 2     | Represents a whole signed number                                     |
| DECIMAL  | 3     | Represents a signed number with decimal precision                    |
| DATETIME | 5     | Represents a date or date time value                                 |
| STRING   | 6     | Represents a string value                                            |

This enum defines the possible data types. Each `DataTypeEnum` has a regex matching rule defined below. This enum should be defined in the PowerShell script as a PowerShell enum.

#### RegEx Rules
Sting input values are assigned a particular data type based on matching a regex rule. The regex rules are checked according to the table below in the order listed below. The data type for a value is deemed to be the first type where a regex match returns true.
- BOOLEAN: `^(true|false)$`
- INTEGER: `^-?\d+$`
- DECIMAL: `^[+-]?(?:\d+\.?\d*|\.\d+)$`
- DATETIME: `^\d{4}-\d{2}-\d{2}(?:[T\s]\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?(?:Z|[+\-]\d{2}:\d{2})?)?$`
- STRING: `^.*$`

Notes:
- Only ISO‑8601 dates are supported.

#### Parameters
| Parameter Name | Data Type | Mandatory | Default | Purpose         |
| -------------- | --------- | --------- | ------- | --------------- |
| `$Value`       | `String`  | Yes       | n/a     | The input value |

#### Exceptions
If the $Value parameter cannot be matched by any regex rules, throw the exception 'Value cannot be parsed by any regex rules!'.

#### Processing
1. Trim `$Value`
2. Iterate through the regex patterns in the order listed in the **Regex Rules** section above. If the regex rule matches `$Value` then return the `DataTypeEnum` enum value corresponding to the matched regex rule.
3. If no regex rules are matched, throw an exception (see above **Exceptions** section).

#### Returns
Returns an enum value of type `DataTypeEnum`.

### Apply-NullValues

#### Purpose
Replaces null-like values with `$null` in a dataset. By default any empty string csv cell values ('') are also converted to `$null`. Empty string values in csv files are always treated as `$null` in this specification.

#### Parameters
| Parameter Name     | Data Type          | Mandatory | Default | Purpose                          |
| ------------------ | ------------------ | --------- | ------- | -------------------------------- |
| `$Dataset`         | `PSCustomObject[]` | Yes       | n/a     | The input dataset                |
| `$NullValuesArray` | `String[]`         | No        | `$null` | The null-like values as an array |

#### Processing
1. Get the column names for the dataset, by calling the `Get-ColumnNames` function, passing in `$Dataset`. Assign the result to a variable called `$columnNames`.
2. For each `$columnName` in `$columnNames`
   1. for each `$row` in `$Dataset`:
      1. if `$NullValuesArray` != `$null` and contains elements then:
         1. If the value `$row[$columnName]` is contained in the `$NullValuesArray` array, then set `$row[$columnName]` to `$null`.
      2. If the value `$row[$columnName]` is an empty string, then set `$row[$columnName]` to `$null`.
3. Return `$Dataset`

#### Returns
Returns the `$Dataset` object, but with all null-like values set to `$null`.

### Add-RowId

#### Purpose
Optionally adds a auto-increment column to a dataset, with values starting at 1. This is useful if the csv files to be compared don't have a natural key, and should be based purely on the order within the files.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose                              |
| -------------- | ------------------ | --------- | ------- | ------------------------------------ |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset                    |
| `$RowIdName`   | `String`           | `$false`  | ''      | The name of the row id column to add |

#### Exceptions
Throw an exception if the column `$RowIdName` already exists in the dataset `$Dataset`.

#### Processing
1. Check that `$RowIdName` is not `$null` and not an empty string. If either, then return `$Dataset` unmodified, and exit function.
2. If `$RowIdName` is not `$null` then:
   1. Call the `Get-ColumnNames` function, passing in `$Dataset`. Assign the result to a variable called `$columnNames`.
   2. Check that `$RowIdName` does not exist in the `$columnNames` array. If it does, then the row id column name specifies already exists in the dataset, which would result in data being overwritte. In this case, throw an exception: '{$RowIdName} already exists in dataset!'.
3. Initialise a row number `Integer` variable `$i` to 1.
4. Loop through each row $row in $Dataset:
   1. Add a new property to `$row` (does not matter what position in the object), setting `$row[$RowIdName]` to `$i`.
   2. Increment `$i` by 1.
5. Return `$Dataset`

#### Returns
Returns the `$Dataset` object, but with an additional row id column added.

### Cast-Dataset

#### Purpose
Casts all columns in a dataset to the correct types based on a previous scan of data types. Note that all types are nullable - existing `$null` values should be left as `$null`.

#### Assumptions
The `$ColumnTypes` parameter in the special `hashtable` format, is generated by the `Get-DataTypes` function.

#### Parameters
| Parameter Name | Data Type          | Mandatory | Default | Purpose                         |
| -------------- | ------------------ | --------- | ------- | ------------------------------- |
| `$Dataset`     | `PSCustomObject[]` | Yes       | n/a     | The input dataset               |
| `$ColumnTypes` | `hashtable`        | Yes       | n/a     | The column names and data types |

#### Processing
1. For each `$columnName` in the keys of `$ColumnTypes` (`$ColumnTypes.Keys`):
   1. For each row, `$row` in `$Dataset`
      1. if `$row[$columnName]` != `$null`
         1. If `$ColumnTypes[$columnName]` = `DataTypeEnum.BOOLEAN`, then TryParse the value of `$row[$columnName]` to a `Boolean` type. If TryParse returns false, throw an exception: 'Value: $row[$columnName] cannot be converted to a BOOLEAN.'
         2. If `$ColumnTypes[$columnName]` = `DataTypeEnum.INTEGER`, then TryParse the value of `$row[$columnName]` to an `Integer` type. If TryParse returns false, throw an exception: 'Value: $row[$columnName] cannot be converted to an INTEGER.'
         3. If `$ColumnTypes[$columnName]` = `DataTypeEnum.DECIMAL`, then TryParse the value of `$row[$columnName]` to a `Decimal` type. If TryParse returns false, throw an exception: 'Value: $row[$columnName] cannot be converted to a DECIMAL.'
         5. If `$ColumnTypes[$columnName]` = `DataTypeEnum.DATETIME`, then TryParse the value of `$row[$columnName]` to a DateTime type. If TryParse returns false, throw an exception: 'Value: $row[$columnName] cannot be converted to a DATETIME.'
         6. If `$ColumnTypes[$columnName]` = `DataTypeEnum.STRING`, then continue
2. Return `$Dataset` 

#### Notes
The TryParse methods require a local variable to be initialised as the [ref] variable prior to the TryParse method call.

#### Exceptions
If column of any row cannot be cast safely, throws an exception.

#### Returns
Returns the `$Dataset` object, but with columns cast to their correct types.

### Round-Dataset

#### Purpose
Rounds data in a dataset according to rules passed in.

#### Parameters
| Parameter Name         | Data Type          | Mandatory | Default | Purpose                         |
| ---------------------- | ------------------ | --------- | ------- | ------------------------------- |
| `$Dataset`             | `PSCustomObject[]` | Yes       | n/a     | The input dataset               |
| `$DatasetColumnTypes`  | `hashtable`        | Yes       | n/a     | The column names and data types |
| `$RoundRulesHashtable` | `hashtable`        | Yes       | n/a     | The rounding rules              |

#### Round Types
The following rounding types exists:

| Type | Rounding                                | Data Types Supported |
| ---- | --------------------------------------- | -------------------- |
| sf   | Rounds to nearest x significant figures | INTEGER, DECIMAL     |
| dp   | Rounds to nearest x decimal points      | DECIMAL              |
| se   | Rounds to nearest x seconds             | DATETIME             |
| mi   | Rounds to nearest x minutes             | DATETIME             |
| hr   | Rounds to nearest x hours               | DATETIME             |
| dy   | Rounds to nearest x days                | DATETIME             |

#### Exceptions
Throw an exception in a number of places.

#### Processing
1. For each key `$key` in `$RoundRulesHashtable.Keys`:
   1. If `$key` does not exist in `$DatasetColumnTypes.Keys`, throw an exception: 'The rounding column: $key does not exist in the dataset.'.
   2. Attempt to match the rounding rule: `$RoundRulesHashtable[$key]` to the regex pattern: '^(?<size>\d{1,2})(?<type>sf|dp|se|mi|hr|dy)$', assigning the match groups to 2 local variables, `$size` (`Integer`) and `$type` (`String`).
      1. If the rule does not match the regex pattern, throw an exception: 'Rule: $RoundRulesHashtable[$key] does not match any rounding pattern!'.
      2. If the rule does match the regex pattern, the following capture group variables should exist and have values assigned:
         1. `$size`: should be an integer between 1 and 99.
         2. `$type`: should be one of 'sf', 'dp', 'se', 'mi', 'hr'.
      3. Get the column type. Assign `$DatasetColumnTypes[$key]` to a variable `$columnType` (type is `DataTypeEnum`).
      4. For the captured value `$type` refer to the above 'Round Types' table. If `$columnType` is not one of the supported data types for `$type`, then throw an exception: 'Rounding by $type is not support for column type $columnType'.
      5. If `$columnType` is a supported type then:
         1. Look through each row, `$row` in `$Dataset`.
         2. Round the value `$row[$key]` as follows:
            1. If `$type` = 'sf', round the value to nearest `$size` significant figures.
            2. If `$type` = 'dp', round the value to nearest `$size` decimal places.
            3. If `$type` = 'se', round the value to nearest `$size` seconds.
            4. If `$type` = 'mi', round the value to nearest `$size` minutes.
            5. If `$type` = 'hr', round the value to nearest `$size` hours.
            6. If `$type` = 'dy', round the value to nearest `$size` days.
4. Return `$Dataset`.

#### Returns
Returns the `$Dataset` object, but with values in columns rounded per the rounding rules supplied.

### Compare-Schemas

#### Purpose
Compares the 2 schemas for left and right datasets. Verifies that both schemas have same column names, and that columns are of the same types, and that no dataset has columns that are not in the other dataset.

#### Parameters
| Parameter Name             | Data Type   | Mandatory | Default | Purpose                                              |
| -------------------------- | ----------- | --------- | ------- | ---------------------------------------------------- |
| `$LeftDatasetColumnTypes`  | `hashtable` | Yes       | n/a     | The column names and data types of the left dataset  |
| `$RightDatasetColumnTypes` | `hashtable` | Yes       | n/a     | The column names and data types of the right dataset |

#### SchemaComparisonResult custom type
A custom class is defined to store schema comparison results as follows:

| Property Name | Data Type      | Mandatory | Default | Purpose                                          |
| ------------- | -------------- | --------- | ------- | ------------------------------------------------ |
| `ColumnName`  | `String`       | Yes       | n/a     | The name of the column                           |
| `LeftType`    | `DataTypeEnum` | Yes       | n/a     | The data type of the column in the left dataset  |
| `RightType`   | `DataTypeEnum` | Yes       | n/a     | The data type of the column in the right dataset |

#### Processing
1. Create a variable `$results` of type `SchemaComparisonResult[]` to store the results.
2. For each key-value pair: `$leftItem` in `$LeftDatasetColumnTypes`:
   1. Create a new variable: `$result` of type `SchemaComparisonResult` and set values as follows:
      1. `ColumnName` = `$leftItem.Key`
      2. `LeftType` = $leftItem.Value`
      3. `RightType` = `DataTypeEnum.NONE`
   2. Add `$result` to `$results`
3. For each key-value pair: `$rightItem` in `$RightDatasetColumnTypes`:
   1. Search the `$results` array. If an element has a `ColumnName` property that matches `$rightItem.Key` then:
      1. update that element, setting `RightType` to `$rightItem.Value`
   2. Otherwise:
      1. create a new variable: `$result` of type `SchemaComparisonResult` and set values as follows:
         1. `ColumnName` = `$rightItem.Key`
         2. `LeftType` = `DataTypeEnum.NONE`
         3. `RightType` = `$rightItem.Value`
      2. Add `$result` to `$results`
4. Return `$results`.

#### Returns
Returns results as a `SchemaComparisonResult[]` object. Each element in the array will contain information about 1 column. 

### Compare-Datasets

#### Purpose
Performs comparison of 2 datasets. The comparison does a row-by-row, column-by-column check.

#### Assumptions
The 2 datasets must have matching schemas at this point. If the schemas are not the same, the top-level function will not call this function.

#### Parameters
| Parameter Name  | Data Type          | Mandatory | Default | Purpose           |
| --------------- | ------------------ | --------- | ------- | ----------------- |
| `$LeftDataset`  | `PSCustomObject[]` | Yes       | n/a     | The left dataset  |
| `$RightDataset` | `PSCustomObject[]` | Yes       | n/a     | The right dataset |

#### CompareTypeEnum Enum
A custom enum class should be created to denote the type of comparison result:

| Enum           | Value | Description                                                                                                          | ColumnName | KeyValues | Left | Right |
| -------------- | ----- | -------------------------------------------------------------------------------------------------------------------- | ---------- | --------- | ---- | ----- |
| KEY_LEFT_ONLY  | 1     | Denotes that a key in the left dataset does not exist in the right dataset                                           | Yes        | Yes       | No   | No    |
| KEY_RIGHT_ONLY | 2     | Denotes that a key in the right dataset does not exist in the left dataset                                           | Yes        | Yes       | No   | No    |
| DIFFERENT      | 3     | Denotes that a row has been matched in both left and right files, but contains different values in a particular cell | Yes        | Yes       | Yes  | Yes   |

The above table also identifies for each compare type, which additional values are required on the `CompareType` custom object. This enum should be defined in the PowerShell script as a PowerShell enum.

#### CompareType PSCustomObject Definition
Each comparison result will be stored as a `PSCustomObject` object with the following properties:

| Property      | Data Type         | Purpose                                                                                            |
| ------------- | ----------------- | -------------------------------------------------------------------------------------------------- |
| `CompareType` | `CompareTypeEnum` | Denotes the type of match. Is of type `CompareTypeEnum`                                            |
| `ColumnName`  | `String`          | String value denoting the column being matched. This only applies where CompareType is 'DIFFERENT' |
| `KeyValues`   | `String`          | String concatenation of the key values of the row                                                  |
| `Left`        | `String`          | The value of the cell in the left dataset                                                          |
| `Right`       | `String`          | The value of the cell in the right dataset                                                         |

#### Processing
1. Create a variable `$results` which is an array of PSCustomObjects whose structure is defined in the above section: **CompareType PSCustomObject Definition**.
2. Create a new variable `$htLeft` of type `hashtable`. For each row `$row` in `$LeftDataset`, add a new key-value pair to `$htLeft`:
   1. key = `$row['__key']`
   2. value = `$row`
3. Create a new variable `$htRight` of type `hashtable`. For each row `$row` in `$RightDataset`, add a new key-value pair to `$htRight`:
   1. key = `$row['__key']`
   2. value = `$row`
4. For each key `$key` in `$htLeft` that does not exist in `$htRight`, add a row into `$results` with the following values:
      1. `KeyValues`: `$key`
      2. `CompareType`: `CompareTypeEnum.KEY_LEFT_ONLY`
      3. `ColumnName`: `$null`
      4. `Left`: `$null`
      5. `Right`: `$null`
5. For each key `$key` in `$htRight` that does not exist in `$htLeft`, add a row into `$results` with the following values:
      1. `KeyValues`: `$key`
      2. `CompareType`: `CompareTypeEnum.KEY_RIGHT_ONLY`
      3. `ColumnName`: `$null`
      4. `Left`: `$null`
      5. `Right`: `$null`
6. For each key `$key` in `$htLeft` that also exists in `$htRight`:
   1. Assign `$htLeft[$key]` to a variable `$leftRow`
   2. Assign `$htRight[$key]` to a variable `$rightRow`
   3. For each property `$property` in the properties of `$leftRow` (except for the property '__key'), compare `$leftRow[$property]` to `$rightRow[$property]`.
      1. if the values are different add a row into `$results` with the following values:
         1. `KeyValues`: `$key`
         2. `CompareType`: `CompareTypeEnum.DIFFERENT`
         3. `ColumnName`: `$property`
         4. `Left`: `$leftRow[$property]`
         5. `Right`: `$rightRow[$property]`
      2. Otherwise, continue.
7. return `$results`

#### General Processing Notes:
- Use invariant culture ([datetime]::TryParseExact with ISO formats) when comparing DateTime values.
- When writing values to the `Left` and `Right` properties of the $results variable, always cast to a `String` before writing values.

#### Returns
Returns a `PSCustomObject[]` array. Each element has the properties defined in the `CompareType` PSCustomObject Definition (above).

### Output-SchemaResults

### Purpose
Outputs the results of the Compare-Schema function which compares 2 schemas.

#### Parameters
| Parameter Name             | Data Type                  | Mandatory | Default | Purpose                       |
| -------------------------- | -------------------------- | --------- | ------- | ----------------------------- |
| `$SchemaComparisonResults` | `SchemaComparisonResult[]` | Yes       | n/a     | The schema comparison results |

#### Processing
1. Write output of "SCHEMA RESULTS" and add underline above/below the title, to the standard output / console.
2. Sort the `$SchemaComparisonResults` array by the `ColumnName` property ascending.
3. Format the array as a table, and write to the standard output / console.
4. If there are any elements `$element` in `$SchemaComparisonResults` where `$element.LeftType` != `$element.RightType` then:
   1. Write "Schema differences found. Row-level comparison not performed"
   2. return `$false`
5. Otherwise:
   1. Write "Schemas match. Continuing to perform row-by-row comparison..."
   2. return `$true`

#### Returns
Returns `$true` if the schemas are the same. Otherwise returns `$false`. If the schemas are not the same, the main function ceases any further processing.

### Output-Results

#### Purpose
Outputs the results to the console.

#### Parameters
| Parameter Name       | Data Type          | Mandatory | Default | Purpose                                                                                                       |
| -------------------- | ------------------ | --------- | ------- | ------------------------------------------------------------------------------------------------------------- |
| `$ComparisonResults` | `PSCustomObject[]` | Yes       | n/a     | The comparison results                                                                                        |
| `$SummariseResults`  | `Boolean`          | Yes       | n/a     | The summarise results flag. If set, only summarised results are output. Otherwise detailed results are output |
| `$DetailedRows`      | `Integer`          | Yes       | n/a     | Defines the maximum number of detailed rows to output                                                         |

#### Grouped Results Data Type
If results are grouped, each grouping result should be stored in a `PSCustomObject` object with the following properties:

| Property      | Data Type         | Purpose                                                                                                                   |
| ------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `CompareType` | `CompareTypeEnum` | The type of comparison result                                                                                             |
| `ColumnName`  | `String`          | `String` value denoting the column being matched. $null values should be considered as empty string for grouping purposes |
| `Count`       | `String`          | The number of results in the grouping                                                                                     |

#### Processing
1. Write output of "ROW LEVEL RESULTS" and underline above/below title, to the standard output / console.
2. If `$SummariseResults` = `$false`:
   1. Format `$ComparisonResults` as a table and output to the console / standard output.
   2. Order `$ComparisonResults` by the following properties / columns:
      1. CompareType ASC
      2. ColumnName ASC
      3. KeyValues ASC
   3. Limit the number of rows output to `$DetailedRows`
3. If `$SummariseResults` - `$true`:
   1. Create a new variable called `$resultsGrouped` of type `PSCustomObject[]` (an array of `PSCustomObject`). Each element will have the properties defined in the 'Grouped Results Data Type' section (above). 
   2. Group the `$ComparisonResults` array as follows and assign the resulting grouped results to the variable `$resultsGrouped`:
      1. Grouping columns: `CompareType`, `ColumnName`. Note that before grouping, normalise any null values in both grouping columns to empty strings ('') before applying the grouping.
      2. Add another property to each group called 'Count', which is the count of rows in each group.
   3. Order `$resultsGrouped` by:
      1. CompareType ASC
      2. ColumnName ASC
   4. Format `$resultsGrouped` to a table, and output to the console / standard output.

#### General Notes
- Display column headers on all tables.

#### Returns
Void. The function outputs results to the console only.

--- end of document ---