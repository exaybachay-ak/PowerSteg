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
	####----> copy infile real quick
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

	write-host "Inserted steg data length header is:"
	write-host "------------------------------------"
	write-host $stegdatalen

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
	write-host $extpadded

	<#
	///////////////////----Convert steg data from given stegfile----///////////////////
	#>

	write-host " "
	write-host "File data to be inserted:"
	write-host "-------------------------"
	write-host $stegbytes

	####----> read in the command to steg into our output file
	foreach ($b in $stegbytes){
		$b = [convert]::tostring($b, 2).padleft(9, "0")
		$stegarr += ,$b
	}

	####----> remove spaces and prep array for inserting into file
	$stegarr = [system.string]::Join("",($stegarr))

	write-host " "
	write-host "Inserted steg information is:"
	write-host "-----------------------------"
	write-host $stegarr

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
		####----> check to see if image data byte is even, meaning LSB is 0
		if($carrierbytes[$j] % 2 -eq 0){
			if($stegarr[$j] -eq '1'){
				$stegdata += $carrierbytes[$j] + 1
			}
			else{
				$stegdata += $carrierbytes[$j]
			}
		}
		####----> otherwise, image data byte is odd, with LSB of 1
		else{
			if($stegarr[$j] -eq '1'){
				$stegdata += $carrierbytes[$j]
			}
			else{
				$stegdata += $carrierbytes[$j] - 1			
			}
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
		####----> Check to see if byte is 1
		if($bytes[$f] -eq 1){
			$steglength += 1
		}
		####----> Check to see if LSB is 0
		elseif($bytes[$f] % 2 -eq 0){
			$steglength += 0
			}
		####----> Otherwise LSB is 1
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
		####----> Check to see if byte is 1
		if($bytes[$f] -eq 1){
			$extension += 1
			$f += 1
		}
		####----> Check to see if LSB is 0
		elseif($bytes[$f] % 2 -eq 0){
			$extension += 0
			$f += 1
		}
		####----> Otherwise LSB is 1
		else{
			$extension += 1
			$f += 1
		}
	}
	$extension = [system.string]::Join("",($extension))

	####----> Make arrays to store extension information
	$extbyte1 = @()
	$extbyte2 = @()
	$extbyte3 = @()
	$extbyte4 = @()

	$a = 0
	while ($a -le $extension.length-1){
		if($a -lt 7){
			$extbyte1 += $extension[$a]
			$a += 1
		}
		elseif($a -lt 14){
			$extbyte2 += $extension[$a]
			$a += 1
		}
		elseif($a -lt 21){
			$extbyte3 += $extension[$a]
			$a += 1
		}
		else{
			$extbyte4 += $extension[$a]
			$a += 1
		}
	}

	####----> Flatten bytes and convert to ascii chars
	$extbyte1 = [system.string]::Join("",($extbyte1))
	$extbyte2 = [system.string]::Join("",($extbyte2))
	$extbyte3 = [system.string]::Join("",($extbyte3))
	$extbyte4 = [system.string]::Join("",($extbyte4))

	$extbyte1 = [convert]::tobyte($extbyte1,2)
	$extbyte2 = [convert]::tobyte($extbyte2,2)
	$extbyte3 = [convert]::tobyte($extbyte3,2)
	$extbyte4 = [convert]::tobyte($extbyte4,2)

	####----> Check the contents of extbyte1
	if($extbyte1 -eq '0'){
		$extbyte2 = [convert]::tochar($extbyte2)
		$extbyte3 = [convert]::tochar($extbyte3)
		$extbyte4 = [convert]::tochar($extbyte4)

		$extfinal += $extbyte2
		$extfinal += $extbyte3
		$extfinal += $extbyte4
	}

	else{
		$extbyte1 = [convert]::tochar($extbyte1)
		$extbyte2 = [convert]::tochar($extbyte2)
		$extbyte3 = [convert]::tochar($extbyte3)
		$extbyte4 = [convert]::tochar($extbyte4)

		$extfinal += $extbyte1
		$extfinal += $extbyte2
		$extfinal += $extbyte3
		$extfinal += $extbyte4
	}

	$extfinal = [system.string]::Join("",($extfinal))

	write-host " "
	write-host "Extension information is:"
	write-host "-------------------------"
	write-host $extfinal

	<#
	///////////////////----Retrieve steg data----///////////////////
	#>

	####----> Create array to put steg data in
	$stegdata = @()

	####----> Loop through and get data for insertion into array
	$steglength = $steglength * 9
	$stegend = $f + $steglength
	$stegcounter = 0
	$curbyte = @()
	$outdata = @()
	$tmppath = (pwd).path

	if($testpath -eq "False"){
		$newoutfile = $tmppath + '\stegoutput.' + $extfinal
	}

	if($testpath -eq "True"){
		$newoutfile = $tmppath + '/stegoutput.' + $extfinal
	}

	while($stegcounter -lt 9){
		if($f -eq $stegend){
			foreach ($x in $stegdata){
				$x = [convert]::tochar($x)
				$outdata += $x
			}
			$outdata = [system.string]::Join("",($outdata))

			write-host " "
			write-host "Embedded information is:"
			write-host "------------------------"
			write-host $outdata
			[io.file]::WriteAllText($newoutfile, $outdata)
			
			#----> Checking program execution time before returning from script
			$stopwatch.stop()
			$exectime = $stopwatch.elapsed.totalseconds
			write-host " "
			write-host "Script execution took $exectime seconds."
			return
		}
		elseif($stegcounter -eq 8){
			if($bytes[$f] % 2 -eq 0){
				$curbyte += 0
				$f += 1
				$stegcounter = 0
				$curbyte = [system.string]::Join("",($curbyte))
				$curbyte = [convert]::toint32($curbyte, 2)
				$stegdata += $curbyte
				$curbyte = @()
			}
			else{
				$curbyte += 1
				$f += 1
				$stegcounter = 0
				$curbyte = [system.string]::Join("",($curbyte))
				$curbyte = [convert]::toint32($curbyte, 2)
				$stegdata += $curbyte
				$curbyte = @()
			}
		}
		else{
			if($bytes[$f] % 2 -eq 0){
				$curbyte += 0
				$f += 1
				$stegcounter += 1
			}
			else{
				$curbyte += 1
				$f += 1
				$stegcounter += 1
			}
		}
	}
}

$stopwatch.stop()
$exectime = $stopwatch.elapsed.totalseconds

write-host " "
write-host "Script execution took $exectime seconds."
