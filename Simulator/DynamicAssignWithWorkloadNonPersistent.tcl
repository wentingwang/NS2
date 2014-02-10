set ns [new Simulator]

#set nf [open out.nam w]
#$ns namtrace-all $nf

#Open the Trace file
#set tf [open out.tr w]
#$ns trace-all $tf

set finishTime(0) 0
set finishTime(1) 0
set finishTime(2) 0
set finishTime(3) 0
set finishTime(4) 0
set finishTime(5) 0
set finishTime(6) 0
set finishTime(7) 0
set finishTime(8) 0
set finishTime(9) 0

set fin(0) [open Result/ds_in0.txt w]
set fin(1) [open Result/ds_in1.txt w]
set fin(2) [open Result/ds_in2.txt w]
set fin(3) [open Result/ds_in3.txt w]
set fin(4) [open Result/ds_in4.txt w]
set fin(5) [open Result/ds_in5.txt w]
set fin(6) [open Result/ds_in6.txt w]
set fin(7) [open Result/ds_in7.txt w]
set fin(8) [open Result/ds_in8.txt w]
set fin(9) [open Result/ds_in9.txt w]

set fout(0) [open Result/ds_out0.txt w]
set fout(1) [open Result/ds_out1.txt w]
set fout(2) [open Result/ds_out2.txt w]
set fout(3) [open Result/ds_out3.txt w]
set fout(4) [open Result/ds_out4.txt w]
set fout(5) [open Result/ds_out5.txt w]
set fout(6) [open Result/ds_out6.txt w]
set fout(7) [open Result/ds_out7.txt w]
set fout(8) [open Result/ds_out8.txt w]
set fout(9) [open Result/ds_out9.txt w]

set latency [open Latency/all.txt w]

set dataUnit 150.0
set recordPerFlow 50
set nodeNum 10

proc finish {} {
	global fin tf fout nodeNum
	for {set j 0} {$j < $nodeNum} {incr j} {
		close $fin($j)
		close $fout($j)
	}
	#close $tf
        exit 0

exit 0
}

proc printFinish {} {
	global finishTime realFinishTimeMatrix nodeNum
	set totalTime 0	
	for {set i 0} {$i < $nodeNum} {incr i} {
		if {$totalTime < $finishTime($i)} {
			set totalTime $finishTime($i)
		}
		for {set j 0} {$j < $nodeNum} {incr j} {
			if {$i !=$j} {
			puts -nonewline "$realFinishTimeMatrix($i,$j)\t"
			} else {
				puts -nonewline "0\t"
			}
		}
		puts ""
	}
	
	puts "total Completion Time: $totalTime"
}


#Averaged Bandwidth 
for {set i 0} {$i < $nodeNum} {incr i} {
	for {set j 0} {$j < $nodeNum} {incr j} {
		set bwAverage($i,$j) 0
	}
}

#Record the last 50 bandwidth for each flow
for {set i 0} {$i < $nodeNum} {incr i} {
	for {set j 0} {$j < $nodeNum} {incr j} {
		for {set k 0} {$k < $recordPerFlow} {incr k} {
			set bwRecord($i,$j,$k) 0
		}
		set recordCount($i,$j) 0
	}
}


#Read input file 
#define how much data need to be transferred from one node to another
set fp [open "skewData3" r]
set file_data [read $fp]
set lines [split $file_data "\n"]
set i 0
foreach line $lines {
	puts $line
	set j 0
	set cell [split $line " "]
	foreach c $cell {
		set data($i,$j) $c
		set j [expr $j + 1]
	}
	set i [expr $i + 1]
}
close $fp


#Record remaining data
for {set i 0} {$i < $nodeNum} {incr i} {
	for {set j 0} {$j < $nodeNum} {incr j} {
		set remainingData($i,$j) [expr $data($i,$j)* 10000.0]
	}
}


#initialize the routers
for {set i 0} {$i < 4} {incr i} {
	set router($i) [$ns node]
}

#initialize the nodes
for {set i 0} {$i < 10} {incr i} {
	set n($i) [$ns node]
}

set mongos [$ns node]
$ns duplex-link $router(2) $mongos 10Mb 10ms DropTail

#build links among nodes and routers
for {set i 1} {$i < 4} {incr i} {
	$ns duplex-link $router(0) $router($i) 30Mb 10ms DropTail
}

for {set i 0} {$i < 3} {incr i} {
	$ns duplex-link $router(1) $n($i) 10Mb 10ms DropTail
}

for {set i 3} {$i < 6} {incr i} {
	$ns duplex-link $router(2) $n($i) 10Mb 10ms DropTail
}

for {set i 6} {$i < 10} {incr i} {
	$ns duplex-link $router(3) $n($i) 10Mb 10ms DropTail
}


for {set i 0} {$i < $nodeNum} {incr i} {
	for {set j 0} {$j < $nodeNum} {incr j} {
		set finishTimeMatrix($i,$j) 0
		set realFinishTimeMatrix($i,$j) 0
	}
}


for {set i 0} {$i < $nodeNum} {incr i} {
	for {set j 0} {$j < $nodeNum} {incr j} {
		if { $i != $j } {
			set tcpAssign($i,$j) 0
		}
	}
}



proc setRemainingData { i  j  data } {
	global remainingData 

	#puts "$i $j $packet $lossPacket $data "
	
	if { [expr $remainingData($i,$j) - $data] < 0} {
		#puts "wrong!"
		set remainingData($i,$j) 0
	} else {
		set remainingData($i,$j) [expr $remainingData($i,$j) - $data]
	}
}
proc getAveragedBW {} {
	global 	bwAverage bwRecord recordCount recordPerFlow nodeNum
	puts "bwRecord: "
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			if {$i != $j } {
				set sum 0
				for {set k 0} {$k < $recordPerFlow} {incr k} {
					if {[expr $recordCount($i,$j)%$recordPerFlow] == $k} {
						set sum [expr $sum+[expr 20 * $bwRecord($i,$j,$k)]]
						#set sum [expr $sum+$bwRecord($i,$j,$k)]
					} else {
						set sum [expr $sum+$bwRecord($i,$j,$k)]
					}
					#puts -nonewline "$i $j $k: $bwRecord($i,$j,$k)\t"
				}
				#puts ""
				set bwAverage($i,$j) [expr $sum/[expr $recordPerFlow+19]]
				#set bwAverage($i,$j)  [expr $sum/$recordPerFlow]
			}
		}
	}
}

proc recordBW { i j bw } {
	global bwRecord recordCount recordPerFlow
	set bwRecord($i,$j,[expr $recordCount($i,$j)%$recordPerFlow]) $bw
}
proc recordOutcomingBW { } {
	#printRemainingData
	global sink tcpAssign recordCount fout realFinishTimeMatrix nodeNum
	#Set the time after which the procedure should be called again
	set ns [Simulator instance]
    	set time 0.1
	#Re-schedule the next time dynamicSchedule	
	set now [$ns now]
	#How many bytes have been received by the traffic sinks?
	for {set i 0} {$i < $nodeNum} {incr i} {
		puts -nonewline $fout($i) "$now\t"	
		for {set j 0} {$j < $nodeNum} {incr j} {
			set bw($i,$j) 0
			#puts "$i $j"
			if {$j != $i} {
				for {set k 0} {$k<$tcpAssign($j,$i)} { incr k} {
					set bw($i,$j) [expr $bw($i,$j) + [$sink($j,$i,$k) set recvbytes_]]
					#puts [$sink($j,$i,$k) set recvbytes_]
					#Reset the bytes_ values on the traffic sinks
					$sink($j,$i,$k) set recvbytes_ 0			
				}
				puts -nonewline $fout($i) "$bw($i,$j)\t"	
				#puts -nonewline $fout($i) "[expr $bw($i,$j)/$time*8/1000000]\t"	
				
			} else {
				puts -nonewline $fout($i) "0\t"	
			}
		}
		puts $fout($i) ""
	}
	$ns at [expr $now+$time] "recordOutcomingBW"
}
proc recordCompletionTime { } {
	#printRemainingData
	global sink finishTime tcpAssign recordCount fin realFinishTimeMatrix nodeNum
	#Set the time after which the procedure should be called again
	set ns [Simulator instance]
    	set time 0.1
	#Re-schedule the next time dynamicSchedule	
	set now [$ns now]
	#How many bytes have been received by the traffic sinks?
	for {set i 0} {$i < $nodeNum} {incr i} {
		puts -nonewline $fin($i) "$now\t"	
		for {set j 0} {$j < $nodeNum} {incr j} {
			set bw($i,$j) 0
			set packet($i,$j) 0
			set lossPacket($i,$j) 0
			if {$j != $i} {
				for {set k 0} {$k<$tcpAssign($i,$j)} { incr k} {
					set bw($i,$j) [expr $bw($i,$j) + [$sink($i,$j,$k) set recvbytes_]]
					set packet($i,$j) [expr $packet($i,$j) + [$sink($i,$j,$k) set npkts_] ]
					set lossPacket($i,$j) [$sink($i,$j,$k) set nlost_]
					#Reset the bytes_ values on the traffic sinks
					$sink($i,$j,$k) set npkts_ 0	
					$sink($i,$j,$k) set nlost_ 0
					$sink($i,$j,$k) set recvbytes_ 0			
				}
				if { $bw($i,$j) !=0 } {
					set realFinishTimeMatrix($i,$j) $now
				}
				puts -nonewline $fin($i) "$bw($i,$j)\t"	
				#record bandwidth
				set recordCount($i,$j) [expr $recordCount($i,$j)+1]
				recordBW $i $j [expr $bw($i,$j)/$time]
		 
				#record remaining data
				setRemainingData $i $j $bw($i,$j)
		
				#record current time 
				if { $bw($i,$j) !=0 } {
					set finishTime($i) $now	
				}
			} else {
				puts -nonewline $fin($i) "0\t"	
			}
		}
		puts $fin($i) ""
	}
	$ns at [expr $now+$time] "recordCompletionTime"
}

proc dynamicSchedule {} {
	global tcpAssign bwAverage slowsender slowreceiver fastsender fastreceiver recordPerFlow
	set ns [Simulator instance]

	#Set the time after which the procedure should be called again
    	set t $recordPerFlow/10
	#Re-schedule the next time dynamicSchedule	
	set now [$ns now]
	
	puts "Current Time: $now"
	#get the averaged bandwidth for each flow
	getAveragedBW
	printAverageBW

	#find the slowest flow
	computeCompletionTime
	findSlowFlow
	#findGlobalFastFlow
	findFastFlow $slowsender
	printFinishTimeMatrix
	puts "slowsender:$slowsender"
	puts "slowreceiver:$slowreceiver"

	puts "fastsender:$fastsender"
	puts "fastreceiver:$fastreceiver"

	#add TCP to slowest flow & reset the flow
	addTCP $slowsender $slowreceiver 1 $now $ns
	substractTCP $fastsender $fastreceiver 1 $now $ns
	printTcpAssign
	if { [expr $now+$t] < 60 } {
		$ns at [expr $now+$t] "dynamicSchedule"
	}
	
}
set slowsender -1
set slowreceiver -1

set fastsender -1
set fastreceiver -1

proc computeCompletionTime {} {
	global finishTimeMatrix remainingData bwAverage slowsender slowreceiver fastsender fastreceiver tcpAssign nodeNum
	#recompute finishTime for each flow
	printRemainingData
	
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			if { $i != $j} {
				#puts "$i $j"
				if {$bwAverage($i,$j) != 0} {
					set newFinishTime [expr $remainingData($i,$j)/$bwAverage($i,$j)]
				} else {
					set newFinishTime 0
				}
				set finishTimeMatrix($i,$j) $newFinishTime
			}
		}
	}
}

proc findSlowFlow {} {
	global finishTimeMatrix remainingData bwAverage slowsender slowreceiver fastsender fastreceiver tcpAssign nodeNum
	#recompute finishTime for each flow
	set max 0
	set slowsender -1
	set slowreceiver -1
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			if { $i != $j} {
				if {$max < $finishTimeMatrix($i,$j)  } {
					set max $finishTimeMatrix($i,$j)
					set slowsender $j
					set slowreceiver $i
				}
			}
		}
	}
	
}

proc findFastFlow { j } {
	global finishTimeMatrix remainingData bwAverage slowsender slowreceiver fastsender fastreceiver tcpAssign nodeNum
	#recompute finishTime for each flow
	set min 100000

	set fastsender -1
	set fastreceiver -1
	for {set i 0} {$i < $nodeNum} {incr i} {
		if { $i != $j} {
			#puts "$i,$j"
			if {$min > $finishTimeMatrix($i,$j) && $tcpAssign($i,$j) >2 && $finishTimeMatrix($i,$j)!=0} {
				set min $finishTimeMatrix($i,$j)
				set fastsender $j
				set fastreceiver $i
			}
		}	
			
	}
	
	
}

proc findGlobalFastFlow {  } {
	global finishTimeMatrix remainingData bwAverage slowsender slowreceiver fastsender fastreceiver tcpAssign nodeNum
	#recompute finishTime for each flow
	set min 100000

	set fastsender -1
	set fastreceiver -1
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
		if { $i != $j} {
			#puts "$i,$j"
			if {$min > $finishTimeMatrix($i,$j) && $tcpAssign($i,$j) >2 && $finishTimeMatrix($i,$j)!=0} {
				set min $finishTimeMatrix($i,$j)
				set fastsender $j
				set fastreceiver $i
			}
		}	
		}	
	}
	
	
}

proc substractTCP {sender receiver tcpNum now ns} {
	global tcpAssign remainingData ftp tcp sink n
	printTcpAssign
	#reset flow with new TCP assignment
	for {set k 0} {$k < $tcpAssign($receiver,$sender)} {incr k} {
		$ns at $now "$ftp($sender,$receiver,$k) stop"
	}
	set tcpAssign($receiver,$sender) [expr $tcpAssign($receiver,$sender)-$tcpNum]
	printTcpAssign
	set data [expr $remainingData($receiver,$sender)/$tcpAssign($receiver,$sender)]

	puts " $data = $remainingData($receiver,$sender) / $tcpAssign($receiver,$sender)"
	for {set k 0} {$k < $tcpAssign($receiver,$sender) } {incr k} { 
		 
		$ns at $now "$ftp($sender,$receiver,$k) send $data"
		
	}

}

proc addTCP {sender receiver tcpNum now ns} {
	global tcpAssign remainingData ftp tcp sink n
	printTcpAssign
	#reset flow with new TCP assignment
	for {set k 0} {$k < $tcpAssign($receiver,$sender)} {incr k} {
		$ns at $now "$ftp($sender,$receiver,$k) stop"
	}
	set tcpAssign($receiver,$sender) [expr $tcpAssign($receiver,$sender)+$tcpNum]
	printTcpAssign
	set data [expr $remainingData($receiver,$sender)/$tcpAssign($receiver,$sender)]

	puts " $data = $remainingData($receiver,$sender) / $tcpAssign($receiver,$sender)"
	for {set k 0} {$k < $tcpAssign($receiver,$sender) } {incr k} { 
		if { $k < $tcpAssign($receiver,$sender) - $tcpNum } {
			$ns at $now "$ftp($sender,$receiver,$k) send $data"
		} else {
			set tcp($sender,$receiver,$k) [new Agent/TCP]
				
			$tcp($sender,$receiver,$k) set fid_ $sender$receiver
			$ns attach-agent $n($sender) $tcp($sender,$receiver,$k)
			
			set sink($receiver,$sender,$k) [new Agent/TCPSinkMonitor]
			$ns attach-agent $n($receiver) $sink($receiver,$sender,$k)

			$ns connect $sink($receiver,$sender,$k)  $tcp($sender,$receiver,$k)
			set ftp($sender,$receiver,$k) [$tcp($sender,$receiver,$k) attach-source FTP]
			puts "$sender,$receiver,$k"
			$ns at $now "$ftp($sender,$receiver,$k) send $data "
		}
	}

}
for {set j 0} {$j < $nodeNum} {incr j} {
	set DataPerNode($j) 0 
	set rank($j) 9
}
proc initialTCPAssign {} {
	global data dataUnit tcpAssign DataPerNode nodeNum
	for {set j 0} {$j < $nodeNum} {incr j} {
		set nodeSum 0
		for {set i 0} {$i < $nodeNum} {incr i} {
			if {$j != $i} {
				#set x 1
				#if { [ifSameZone $i $j] == 0 } {
				#	set dataUnit 250.0
				#} else {
				#	set dataUnit 100.0
				#}
				set x [expr round($data($i,$j)/$dataUnit)]
				if { $x == 0} {
					set x 1			
				}
				set tcpAssign($i,$j) $x
				set nodeSum [expr $nodeSum +$data($i,$j) ]
			} else {
				set tcpAssign($i,$j) 0
			}
		
		}
		set DataPerNode($j) $nodeSum
	}
	printTcpAssign
	rank
}

proc ifSameZone { i j } {
	if { ($i < 3 && $j < 3) || ($i >= 3 && $i < 6 && $j >= 3 && $j<6) || ($i >= 6 && $j >=6) } {
		return 0
	} else {
		return 1
	}
}

proc rank {} {
	global rank DataPerNode nodeNum
	for {set j 0} {$j < 9} {incr j} { 
		set max -1
		set maxPos -1
		for {set i 0} {$i < $nodeNum} {incr i} { 
			if { $DataPerNode($i) != 0 && $DataPerNode($i)>$max} {
				set max $DataPerNode($i)
				set maxPos $i
			}
		}
		set rank($maxPos) $j
		set DataPerNode($maxPos) 0 
	}
	for {set j 0} {$j < $nodeNum} {incr j} { 
		puts -nonewline "$rank($j)\t"
	}
	puts ""
}


proc printTotalCompletionTime {} {
	global finishTime nodeNum
	set completionTime 0
	for {set j 0} {$j < $nodeNum} {incr j} {
		#puts $finishTime($j)
		if { $completionTime < $finishTime($j) } {
			set completionTime $finishTime($j)
		}
	}
	puts "Finish Time: $completionTime"
}
proc printTcpAssign {} {
	puts "TCP number Matrix"
	global tcpAssign nodeNum
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			puts -nonewline $tcpAssign($i,$j)
			puts -nonewline "\t"
		}
		puts ""
	}
}

proc printFinishTimeMatrix {} {
	puts "Finish Time Matrix"
	global finishTimeMatrix nodeNum
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			puts -nonewline "$finishTimeMatrix($i,$j)\t"
		}
		puts ""
	}
}
proc printAverageBW {} {
	puts "Average Bandwidth Matrix"
	global bwAverage nodeNum
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			puts -nonewline "$bwAverage($i,$j)\t"
		}
		puts ""
	}
}

proc printRemainingData {} {
	puts "Remaining Matrix"
	global remainingData nodeNum
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			puts -nonewline $remainingData($i,$j)
			puts -nonewline "\t"
		}
		puts ""
	}
}



initialTCPAssign
set totalTCP 0
#Create a TCP agent and attach it to nodes
for {set i 0} {$i < $nodeNum} {incr i} {
	for {set j 0} {$j < $nodeNum} {incr j} {
		if {$j != $i} {
			set x [expr $tcpAssign($j,$i)]
			if { $x!=0 } {
				for {set k 0} {$k < $x} { incr k} {
					set totalTCP [expr $totalTCP + 1]
					set tcp($i,$j,$k) [new Agent/TCP]
					$tcp($i,$j,$k) set fid_ $i$j		

					$ns attach-agent $n($i) $tcp($i,$j,$k)
					
					set sink($j,$i,$k) [new Agent/TCPSinkMonitor]
					#puts sink($j,$i,$k)
					$ns attach-agent $n($j) $sink($j,$i,$k)

					$ns connect $sink($j,$i,$k)  $tcp($i,$j,$k)
					set ftp($i,$j,$k) [$tcp($i,$j,$k) attach-source FTP]
					#puts "$i,$j,$k"
					#puts "at [expr $rank($i)*1.0 + $rank($j)*0.1] ftp($i,$j,$k) run"
					#$ns at [expr $rank($i)*1.0 + $rank($j)*0.1] "$ftp($i,$j,$k) send [expr $data($j,$i)/$x * 10000] 
					$ns at 100.0 "$ftp($i,$j,$k) send [expr $data($j,$i)/$x * 10000] "
					#$ns at [expr $rank($i)*1.0] "$ftp($i,$j,$k) send [expr $data($j,$i)/$x * 10000] "
				
			
				}
			}
		}	
	}
}

puts -nonewline "total TCP:"
puts  $totalTCP


proc uniformWorkload {} {
	global ns nodeNum n mongos
	#every t seconds
	set t 0.1
	set now [$ns now]
	
	for {set i 0} {$i < $nodeNum} {incr i} {
		set mongoSink($i) [new Agent/TCP/FullTcp]
		set mongoTcp($i) [new Agent/TCP/FullTcp]
		$ns attach-agent $n($i) $mongoSink($i)
		$ns attach-agent $mongos $mongoTcp($i)
		$mongoSink($i) listen
		$mongoTcp($i) listen
		$ns connect $mongoSink($i) $mongoTcp($i)
		$mongoSink($i) set fid_ [expr $i*10000]
		$mongoTcp($i) set fid_ [expr $i*100000]

		set sender($i) [new Application/TcpApp  $mongoTcp($i)]
		set receiver($i) [new Application/TcpApp  $mongoSink($i)]
		$sender($i) connect $receiver($i)
		$ns at $now "$sender($i) send 10 \"$receiver($i) app-recv $receiver($i) $sender($i) $now $i \" "
	}
	
	$ns at [expr $now+$t] "uniformWorkload"	
}

Application/TcpApp instproc app-recv { recv send sendTime i} {
	global ns
	#puts "receive time: [$ns now] send time: $sendTime"
	$ns at [$ns now] "$recv send 1000 \"$send app-recv1 $i $sendTime\""
	
}

Application/TcpApp instproc app-recv1 { rece sendTime } {
	global ns latency
	set now [$ns now]
	#puts "$now: Latency for $rece: [expr $now - $sendTime]"
	puts $latency "$now Latency for $rece: [expr $now - $sendTime]"
	
}

#start experiments
#$ns at 0.0 "recordOutcomingBW"
$ns at 0.0 "recordCompletionTime"
$ns at 0.5 "uniformWorkload"
#$ns at 5.0 "dynamicSchedule"
$ns at 250.0 "printFinish"
$ns at 250.0 "finish"

$ns run

