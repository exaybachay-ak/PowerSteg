<#
#############################################################################################################
#############################################################################################################
#############################################################################################################
       Current steg file layout below:
       <--BMPHEADER--><--STEGHEADER--><--STEGDATA--><--BMPDATA-->
                      |               \
                      |                 \
                      |                   \
                      |                     \
                      |                       \
                      |                         \
                      |                           \
                      |                             \
                      |                               \
                      |                                 \
                      |                                   \
                      |                                     \
                      |                                       \
                      |                                         \
                      |                                           \
                      |                                             \
                      |                                               \
                      |                                                 \
                      |                                                   \
                      |                                                     \
                      |                                                       \
                      |                                                         \
		      |                                                           \
                      |--4 bytes, steg data size (in bytes)--|--4 bytes, extension--|
	Example header info:::
	Stegdata length (22)  // 32 bits, 4 bytes
	00000000000000000000000000010110
		
	Stegdata extension (.txt)  //  28 bits, 4 ascii chars
	0101110100001010011011010000
	Stegdata (/bin/sh testcommand.sh)
	000101111001100010001101001001101110000101111001110011001101000000100000001110100001100101001110011001110100001100011001101111001101101001101101001100001001101110001100100 000101110 001110011 001101000
#############################################################################################################
#############################################################################################################
#############################################################################################################
#>

param (
    [Parameter(Mandatory=$true)][string]$InFile,
    [Parameter(Mandatory=$false)][string]$OutFile,
    [Parameter(Mandatory=$false)][string]$StegFile,
    [switch]$desteg = $false
)

#----> Start a timer to report how long execution takes
$stopwatch = [system.diagnostics.stopwatch]::startNew()

<#
#############################################################################################################
###--- ADD FUNCTION HERE TO CHECK FOR FILETYPE AND CONVERT TO BMP IF NECESSARY ---###########################
###--- https://blogs.technet.microsoft.com/heyscriptingguy/2010/07/05/hey-scripting-guy-how-can-i-use-windows-powershell-to-convert-graphics-files-to-different-file-formats/ ---##
###--- https://hazzy.techanarchy.net/posh/powershell/bmp-to-jpg-the-powershell-way/ ---######################
#############################################################################################################
#>

####----> Modifying script for Windows default PATH functionality
$testpath = test-path "/bin/"

####----> If there is no /bin/, it's Windows
if($testpath -ne "True"){
	$tmppath = (pwd).path
	$InFile = $tmppath + '\' + $InFile
	if($OutFile){
		$StegFile = $tmppath + '\' + $StegFile
		$OutFile = $tmppath + '\' + $OutFile
	}
}

####----> Otherwise it is Linux so you need / instead of \
if($testpath -eq "True"){
	$tmppath = (pwd).path
	$InFile = $tmppath + '/' + $InFile
	if($OutFile){
		$StegFile = $tmppath + '/' + $StegFile
		$OutFile = $tmppath + '/' + $OutFile
	}
}

####----> read bytes from input file
$bytes = [System.IO.File]::ReadAllBytes($InFile)


<#########################################################################
////////////////////----Write debugging information----///////////////////
#########################################################################>
if($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent){
	write-host "Full input file path is:"
	write-host "------------------------"
	write-host $InFile

	write-host " "
	write-host "Full output file path is:"
	write-host "-------------------------"
	if(!$OutFile){
		write-host "Not defined"
	}
	else{
		write-host $OutFile	
	}

	write-host " "
	write-host "Full steg file path is:"
	write-host "-----------------------"
	if(!$StegFile){
		write-host "Not defined"
	}
	else{
		write-host $StegFile	
	}
	write-host " "
}

<#
////////////////////////////////////////////////////////////////
///////////////////----Enstegcmd function----///////////////////
////////////////////////////////////////////////////////////////
#>
####----> if no desteg flag is set, ensteg the file
if(!$desteg){
	####----> If the data to be added is larger than the target file, notify user and halt execution
	$lengthcheck = (get-item $stegfile).length * 8
	$lengthcheck = $lengthcheck + 60

	$carriercheck = $bytes.length - 54
	write-host "There are $carriercheck bytes available for adding steg data."
	write-host " "

	if($carriercheck -lt $lengthcheck){
		write-host "Your input data is too large for the carrier file.  Please find a larger BMP carrier and try again.  Your file requires $lengthcheck bytes, but your carrier file only has $carriercheck bytes."
		return
	}

	####----> copy infile for writing output to
	Copy-Item $InFile $OutFile

	<#
	///////////////////----Set up steg header----///////////////////
	#>

	<#
	///////////////////----Add steg data length field----///////////////////
	#>

	####----> read in steg data --- need this first to add steg data length field
	[byte[]] $stegbytes = [System.IO.File]::ReadAllBytes($stegfile)

	####----> make array to store new stegged file data
	$stegarr = @()

	####----> add steg header length info
	$stegdatalen = $stegbytes.length
	$stegdatalen = [convert]::tostring($stegdatalen, 2).padleft(32, "0")
	$stegarr += ,$stegdatalen

	$stegdatalendecimal = [convert]::toint32($stegdatalen, 2)
	write-host "Inserted steg data length header is:"
	write-host "------------------------------------"
	write-host $stegdatalen "or $stegdatalendecimal bytes"

	write-host " "
	write-host "The total amount of steg data bits to be added is:"
	write-host "--------------------------------------------------"
	write-host $lengthcheck

	<#
	///////////////////----Add steg extension field----///////////////////
	#>

	####----> get file extension info
	$ext = $Stegfile -replace "\.\/",""
	$reg = [regex]"(\......$|\.....$|\....$)"
	$extension = $reg.match($ext)
	$extension = $extension.Captures[0].value
	$extension = $extension -replace "\.", ""

	####----> add extension to 4-byte header array
	$extarr = @()
	$e = 0
	while ($e -le $extension.length-1){
		$d = [int][char]$extension[$e]
		$extarr += ,$d
		$e += 1
	}

	$extpadded = @()
	$g = 0
	foreach ($c in $extarr){
		$c = [convert]::tostring($c, 2).padleft(7, "0")
		$extpadded += $c
	}

	$extpadded = [system.string]::Join("",($extpadded))
	$stegarr += ,$extpadded.padleft(28, "0")

	write-host " "
	write-host "Inserted steg extension header is:"
	write-host "----------------------------------"
	write-host $extpadded "or $extension"

	####----> Expect ~190 bits added per second
	####----> 3975 bits in ~4.4s, 18159 bits in ~93s, and 40868 bits in ~520 seconds, 55588 bits in ~957 seconds
	####----> Estimating time appears to be meaningless.  Time seems to increase exponentially as size goes up.
	[int]$completionseconds = $lengthcheck / 190
	$completionminutes = $completionseconds / 60
	write-host " "
	write-host "Estimated completion time is:"
	write-host $completionseconds "seconds or $completionminutes minutes"

	<#
	///////////////////----Convert steg data from given stegfile----///////////////////
	#>

	####----> read in the command to steg into our output file
	foreach ($b in $stegbytes){
		$b = [convert]::tostring($b, 2).padleft(8, "0")
		$stegarr += ,$b
	}

	####----> remove spaces and prep array for inserting into file
	$stegarr = [system.string]::Join("",($stegarr))

	####----> read in data for inserting steganography bits
	$filereadStream = [System.IO.File]::Open($infile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
	$reader = New-Object System.IO.BinaryReader($filereadStream)
	$reader.BaseStream.Position = 54;
	$carrierbytes = $reader.ReadBytes($stegarr.length)
	$reader.close()

	####----> privision array and add stegged data into it
	[byte[]] $stegdata = @()
	$j = 0
	while($j -le $stegarr.length-1){
		####----> If the steg data bit is a 1, do AND op to ensure LSB is 1
		if($stegarr[$j] -eq '1'){
			$stegdata += $carrierbytes[$j] -bor 1
		}
		####----> Otherwise, use XOR to ensure LSB is 0
		else{
			$stegdata += $carrierbytes[$j] -band 254
		}
		$j += 1
	}

	<#########################################################################
	////////////////////----Write debugging information----///////////////////
	#########################################################################>
	if($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent){
		write-host " "
		write-host "Default image data is:"
		write-host "----------------------"
		write-host $carrierbytes

		write-host " "
		write-host "File data to be inserted:"
		write-host "-------------------------"
		write-host $stegbytes

		write-host " "
		write-host "Steg bits are:"
		write-host "--------------"
		write-host $stegarr

		write-host " "
		write-host "Inserted steg data is:"
		write-host "----------------------"
		write-host $stegdata

		write-host " "
		write-host "Data format is:"
		write-host "---------------"
		write-host $stegdata.gettype()
		write-host " "
	}
	<#
	///////////////////----Begin actual steg operations, inserting bits into data----///////////////////
	#>

	# stream out the bytes array into the target file
	$fileStream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
	$writer = New-Object System.IO.BinaryWriter($fileStream)
	$writer.BaseStream.Position = 54;
	$writer.write($stegdata)
	$writer.Close()
}

<#
/////////////////////////////////////////////////////////////
///////////////////----Desteg function----///////////////////
/////////////////////////////////////////////////////////////
#>
####----> if desteg switch is not set, desteg command from the stegged file
else{
	####----> Start reading after end of BMP header
	$f = 54
	####----> Set end of loop to be after steg size (54 plus 31)
	$sizeloop = 85
	####----> Set end of loop to be after steg extension (85 plus 28)
	$extloop = 113

	<#
	///////////////////----Retrieve steg data size----///////////////////
	#>
	####----> Make an array for compiling info about header
	$steglength = @()
	$stegmultiple = @()

	####----> Loop through steg header length and put into array
	while($f -le $sizeloop){
		####----> Check to see if byte is 0
		if(($bytes[$f] -band 1) -eq 0){
			$steglength += 0
		}
		####----> Check to see if LSB is 1
		else{
			$steglength += 1
		}
		$f += 1
	}
	$steglength = [system.string]::Join("",($steglength))
	$steglength = [convert]::toint32($steglength,2)

	write-host "Steg data length is:"
	write-host "--------------------"
	write-host $steglength

	<#
	///////////////////----Retrieve steg extension data----///////////////////
	#>
	####----> Make arrays for compiling info about extension
	$extension = @()
	$extfinal = @()

	####----> Loop through steg extension data and put into array
	while($f -le $extloop){
		####----> Check to see if byte is 0
		if(($bytes[$f] -band 1) -eq 0){
			$extension += 0
		}
		####----> Check to see if LSB is 1
		else{
			$extension += 1
		}
		$f += 1
	}
	$extension = [system.string]::Join("",($extension))

	####----> Make array and store extension information
	$extbyte = @()
	$k = 0
	$i = 0
	while ($k -le 27){
		while($i -le 6){
			if($i -eq 6){
				if(($extension[$k] -band 1) -eq 0){
					$extbyte += 0
				}
				else{
					$extbyte += 1
				}
				$extbyte = [system.string]::join("",($extbyte))
				$extbyte = [convert]::tobyte($extbyte, 2)
				$extbyte = [convert]::tochar($extbyte)
				$extfinal += $extbyte
				$extbyte = @()
			}
			elseif(($extension[$k] -band 1) -eq 0){
				$extbyte += 0
			}
			else{
				$extbyte += 1
			}
		$i += 1
		$k += 1
		}
	$i = 0
	}

	$extout = @()

	####----> If the extension data only has 3 values, just store those 3
	if($extfinal[0] -eq 0){
		1..3 | % {
			$extout += [convert]::tochar($extfinal[$_])
		}
	}

	####----> Otherwise, store all 4 values for writing the file later
	else{
		foreach($b in $extfinal){
			$extout += [convert]::tochar($b)
		}
	}

	$extout = [system.string]::Join("",($extout))

	write-host " "
	write-host "Extension information is:"
	write-host "-------------------------"
	write-host $extout
	write-host " "

	<#
	///////////////////----Retrieve steg data----///////////////////
	#>

	####----> Create array to put steg data in
	$stegdata = @()

	####----> Loop through and get data for insertion into array
	$steglength = $steglength * 8
	$stegend = $f + $steglength
	$curbyte = @()
	$outdata = @()
	$tmppath = (pwd).path

	if($testpath -eq "False"){
		$newoutfile = $tmppath + '\stegoutput.' + $extout
	}

	if($testpath -eq "True"){
		$newoutfile = $tmppath + '/stegoutput.' + $extout
	}

	####----> read in data for retrieving steganography data bits
	$filereadStream = [System.IO.File]::Open($infile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
	$reader = New-Object System.IO.BinaryReader($filereadStream)
	$reader.BaseStream.Position = 114;
	$displaystegdata = $reader.ReadBytes($steglength)
	$reader.close()

	####----> Set up variables for writing out steg data
	$stegout = @()
	$stegbyte = @()
	$s = 0
	$iter = 0

	####----> Retrieve stegged info for writing out to file
	while($s -lt $steglength){
		while($iter -le 7){
			if($iter -eq 7){
				if(($displaystegdata[$s] -band 1) -eq 0){
					$stegbyte += 0
				}
				else{
					$stegbyte += 1
				}
				$stegbyte = [system.string]::Join("",($stegbyte))
				$stegbyte = [convert]::toint32($stegbyte, 2)
				$stegout += $stegbyte
				$stegbyte = @()
			}
			elseif(($displaystegdata[$s] -band 1) -eq 0){ 
				$stegbyte += 0
			}
			else{
				$stegbyte += 1
			}
			$iter += 1
			$s += 1
		}	
	$iter = 0
	}

	write-host $stegout
	write-host $newoutfile
	[io.file]::WriteAllBytes($newoutfile, $stegout)
}

$stopwatch.stop()
[int]$exectime = $stopwatch.elapsed.totalseconds

write-host " "
write-host "Script execution took $exectime seconds."
