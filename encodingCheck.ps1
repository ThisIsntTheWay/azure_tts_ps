$bytes = [IO.File]::ReadAllBytes('sample.txt')
[Text.Encoding]::GetEncodings() | % {
    $_|Add-Member -pass Noteproperty Text ($_.GetEncoding().GetString($bytes))
} | fl Name,Codepage,Text