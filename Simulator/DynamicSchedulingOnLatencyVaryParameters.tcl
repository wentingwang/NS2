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

set latencyFile [open ./Latency/parameter/4xBW.txt w]

set dataUnit 1525.0
set recordPerFlow 50
set nodeNum 10
set threshold 0.1
set terminationT 0.001
set dataMagnifier 20000.0
set low_bandwidth 40Mb
set high_bandwidth 120Mb




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


#Record the last $recordPerFlow latecy for each flow
for {set i 0} {$i < $nodeNum} {incr i} {
	for {set k 0} {$k < $recordPerFlow} {incr k} {
		set latencyRecord($i,$k) 0
	}
	set recordCount($i) 0
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
		set remainingData($i,$j) [expr $data($i,$j)* $dataMagnifier]
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
#query server
set mongos [$ns node]
$ns duplex-link $router(2) $mongos $low_bandwidth 10ms DropTail

#build links among nodes and routers
for {set i 1} {$i < 4} {incr i} {
	$ns duplex-link $router(0) $router($i) $high_bandwidth 10ms DropTail
}

for {set i 0} {$i < 3} {incr i} {
	$ns duplex-link $router(1) $n($i) $low_bandwidth 10ms DropTail
}

for {set i 3} {$i < 6} {incr i} {
	$ns duplex-link $router(2) $n($i) $low_bandwidth 10ms DropTail
}

for {set i 6} {$i < 10} {incr i} {
	$ns duplex-link $router(3) $n($i) $low_bandwidth 10ms DropTail
}


for {set i 0} {$i < $nodeNum} {incr i} {

	for {set j 0} {$j < $nodeNum} {incr j} {
		if { $i != $j } {
			set tcpAssign($i,$j) 0
		}
	}
}
for {set i 0} {$i < 4} {incr i} {
	set LatencyAverageRecord($i) 0
}
set totalLatencyAverage 0
set lastLatency 0
set currentLatency 0
set lastTCPNum 0
set currentTCPNum 0
set prevDerivative 0
set currentDerivative 0
set safepoint 0
set safepointLatency 0
set safepointTCP 0

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
proc getAveragedLatency {} {
	global 	latencyAverage latencyRecord recordCount recordPerFlow nodeNum totalLatencyAverage

	set total 0
	for {set i 0} {$i < $nodeNum} {incr i} {
		set sum 0
		for {set k 0} {$k < $recordPerFlow} {incr k} {
			if {[expr $recordCount($i)%$recordPerFlow] == $k} {
				set sum [expr $sum+$latencyRecord($i,$k)]
			} else {
				set sum [expr $sum+$latencyRecord($i,$k)]
			}
		}
		set latencyAverage($i)  [expr $sum/$recordPerFlow]
		set total [expr $total + $latencyAverage($i)]
	}
	set totalLatencyAverage [expr $total / $nodeNum]
}
set LatencyRecordCount 0
proc setAverageLatencyRecord {} {
	global LatencyAverageRecord totalLatencyAverage LatencyRecordCount recordPerFlow totalLatencyRecord ns
	set time [expr $recordPerFlow/10]
	set now [$ns now]
	getAveragedLatency
	set LatencyAverageRecord([expr $LatencyRecordCount % $totalLatencyRecord]) $totalLatencyAverage
	
	set LatencyRecordCount [expr $LatencyRecordCount+1]
	
	$ns at [expr $now+$time] "setAverageLatencyRecord"
}

set beforeReconLatency 0
proc initialAverageLatency {} {
	global totalLatencyAverage lastLatency
	getAveragedLatency
	set lastLatency $totalLatencyAverage
}
proc recordLatency { i latency } {
	global latencyRecord recordCount recordPerFlow latencyFile
	set latencyRecord($i,[expr $recordCount($i)%$recordPerFlow]) $latency
	
	if { $recordCount($i) ==[expr $recordPerFlow -1 ] } {
		#for {set j 0} {$j < $recordPerFlow} {incr j} {
		#	puts $latencyFile "$i node latency: $latencyRecord($i,$j)"
		#}
		set recordCount($i) 0
	} else {
		set recordCount($i) [expr $recordCount($i) + 1]
	}
	
}


proc dynamicSchedule {} {
	global tcpAssign latencyAverage recordPerFlow totalLatencyAverage safepoint currentDerivative prevDerivative currentLatency lastLatency currentTCPNum lastTCPNum safepointTCP safepointLatency
	set ns [Simulator instance]

	#Set the time after which the procedure should be called again
    	set time 5.0
	#Re-schedule the next time dynamicSchedule	
	set now [$ns now]
	puts "Current Time: $now"
	
	getAveragedLatency
	set currentLatency $totalLatencyAverage

	set prevDerivative $safepoint
	puts "currentLatency:$currentLatency lastLatency:$lastLatency currentTCPNum:$currentTCPNum lastTCPNum:$lastTCPNum safepointTCP:$lastTCPNum"
	set currentDerivative [derivative $currentLatency $currentTCPNum $lastLatency $lastTCPNum]
	puts "prevDerevative:$prevDerivative currentDerivative:$currentDerivative"
	if { $prevDerivative == 0 } {
		set sd 0
	} else {
               # if { $currentDerivative > $prevDerivative } {
		    set sd  [expr [expr  $currentDerivative - $prevDerivative] / $prevDerivative ]
	#	} else { 
         #           set sd 0
          #      }
       }
	puts "secord derivative: $sd"

	if { [needReassign $sd]==1 } {
		$ns at [expr $now+$time] "dynamicSchedule"
		
		if { [takeoff $sd $currentDerivative] == 1 } {
			#reduce TCP connection #
			decreaseTCP
		} else {
			#double TCP connection #
			increaseTCP
		}
	}	
}
proc needReassign { sd } {
	global ns nodeNum finishTime LatencyRecordCount LatencyAverageRecord totalLatencyRecord continueDecrease decrease ns threshold terminationT
	set now [$ns now]
        set completionTime 0
        for { set i 0 } {$i < $nodeNum } { incr i } {
            # puts "finishTime($i):$finishTime($i)"
              if { $completionTime < $finishTime($i) } {
                   set completionTime $finishTime($i)
              }
        }
	puts "current completon Time: $completionTime now: $now"
	if { [expr $now - 1] <= $completionTime  &&  [expr abs($sd - $threshold)] > $terminationT  } {
		return 1
	} else {
		return 2
	}
}

proc takeoff { sd  currentD} {
	global 	safepoint prevDerivative safepointLatency currentDerivative lastLatency currentLatency lastTCPNum currentTCPNum safepointTCP threshold
	
	if { [expr $sd > $threshold ] || $currentD<0} {
		#decrease
		puts "return 1 need to decrease tcp"
		set lastLatency $currentLatency
		set lastTCPNum $currentTCPNum
		return 1
	} else {
		#increase
		puts "return 2 need to increase tcp"
		set safepoint $currentDerivative
                set safepointLatency $currentLatency
		set safepointTCP $currentTCPNum 
		set lastLatency $currentLatency
		set lastTCPNum $currentTCPNum
		return 0
	} 

}

proc derivative { currentL currentTCP lastL lastTCP } {
        if { $currentTCP != $lastTCP } {
	    set x [expr [expr $currentL-$lastL] / [expr $currentTCP-$lastTCP]]
        } else {
            set x 0
        }
        return $x
}
proc decreaseTCP {} {
	global data dataUnit tcpAssign remainingData ftp tcp sink n nodeNum ns currentTCPNum
	set dataUnit [expr $dataUnit + 100 ]
	set currentTCPNum 0
	set now [$ns now]
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			if {$j != $i} {
				#reset flow with new TCP assignment
				for {set k 0} {$k < $tcpAssign($j,$i)} {incr k} {
					$ns at $now "$ftp($i,$j,$k) stop"
				}
				set x [expr round( $data($j,$i) / $dataUnit)]
				if {$x == 0 } {
					set x 1				
				}
				set tcpAssign($j,$i) $x
				set currentTCPNum [expr $currentTCPNum + $x]
				set dataTransfer [expr $remainingData($j,$i)/$tcpAssign($j,$i)]
				for {set k 0} {$k < $tcpAssign($j,$i) } {incr k} { 
					$ns at $now "$ftp($i,$j,$k) send $dataTransfer"
				}

			}
		
		}
	}
	printTcpAssign
}

proc increaseTCP {} {
	global data dataUnit tcpAssign remainingData ftp tcp sink n nodeNum ns currentTCPNum
	set dataUnit [expr $dataUnit /2 ]
	set currentTCPNum 0
	set now [$ns now]
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			if {$j != $i} {
				#reset flow with new TCP assignment
				for {set k 0} {$k < $tcpAssign($j,$i)} {incr k} {
					$ns at $now "$ftp($i,$j,$k) stop"
				}
				set originalTCP $tcpAssign($j,$i)
				set x [expr round( $data($j,$i) / $dataUnit)]
				if { $x == 0 } {
					set x 1				
				}
#				while { $x == $originalTCP } {
 #                                    set dataUnit [expr $dataUnit - 100 ]
  #                                   set x [expr round( $data($j,$i)/ $dataUnit)]
   #                                  if {$x == 0 } {
    #                                      set x 1
     #                                }
#				     puts "$dataUnit;$x;$originalTCP"
 #                               }
				set tcpAssign($j,$i) $x
				set currentTCPNum [expr $currentTCPNum + $x]
				set dataTransfer [expr $remainingData($j,$i)/$tcpAssign($j,$i)]
				for {set k 0} {$k < $tcpAssign($j,$i) } {incr k} { 
					if { $k < $originalTCP  } {
						$ns at $now "$ftp($i,$j,$k) send $dataTransfer"
					} else {
						set tcp($i,$j,$k) [new Agent/TCP]
				
						$tcp($i,$j,$k) set fid_ $i$j
						$ns attach-agent $n($i) $tcp($i,$j,$k)
			
						set sink($j,$i,$k) [new Agent/TCPSinkMonitor]
						$ns attach-agent $n($j) $sink($j,$i,$k)

						$ns connect $sink($j,$i,$k)  $tcp($i,$j,$k)
						set ftp($i,$j,$k) [$tcp($i,$j,$k) attach-source FTP]
						#puts "$i,$j,$k"
						$ns at $now "$ftp($i,$j,$k) send $dataTransfer "
					}
				}

			}
		
		}
	}
	printTcpAssign
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
			set bytes($i,$j) 0
			if {$j != $i} {
				for {set k 0} {$k<$tcpAssign($i,$j)} { incr k} {
					set bytes($i,$j) [expr $bytes($i,$j) + [$sink($i,$j,$k) set recvbytes_]]
					#Reset the bytes_ values on the traffic sinks
					$sink($i,$j,$k) set recvbytes_ 0			
				}
				if { $bytes($i,$j) !=0 } {
					set realFinishTimeMatrix($i,$j) $now
				}
				puts -nonewline $fin($i) "$bytes($i,$j)\t"	
		 
				#record remaining data
				setRemainingData $i $j $bytes($i,$j)
		
				#record current time 
				if { $bytes($i,$j) !=0 } {
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


proc setTCPAssign { dataUnit } {
	global data tcpAssign DataPerNode nodeNum currentTCPNum
	for {set j 0} {$j < $nodeNum} {incr j} {
		for {set i 0} {$i < $nodeNum} {incr i} {
			if {$j != $i} {
				set x [expr round($data($i,$j)/$dataUnit)]
				if { $x == 0} {
					set x 1			
				}
				set tcpAssign($i,$j) $x
				set currentTCPNum [expr $currentTCPNum + $x]
			} else {
				set tcpAssign($i,$j) 0
			}
		
		}
	}
	printTcpAssign
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
	global tcpAssign currentTCPNum nodeNum
	for {set i 0} {$i < $nodeNum} {incr i} {
		for {set j 0} {$j < $nodeNum} {incr j} {
			puts -nonewline "$tcpAssign($i,$j)\t"
		}
		puts ""
	}
	puts "total TCP: $currentTCPNum"
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

proc printAverageLatency {} {
	puts "Average Bandwidth Matrix"
	global latencyAverage
	for {set i 0} {$i < 10} {incr i} {
		for {set j 0} {$j < 10} {incr j} {
			puts -nonewline "$latencyAverage($i)\t"
		}
		puts ""
	}
}

setTCPAssign $dataUnit

#Create a TCP agent and attach it to nodes
for {set i 0} {$i < $nodeNum} {incr i} {
	for {set j 0} {$j < $nodeNum} {incr j} {
		if {$j != $i} {
			# i sends data to j
			set x [expr $tcpAssign($j,$i)] 
			if { $x!=0 } {
				for {set k 0} {$k < $x} { incr k} {
					set tcp($i,$j,$k) [new Agent/TCP]
					$tcp($i,$j,$k) set fid_ $i$j		

					$ns attach-agent $n($i) $tcp($i,$j,$k)
					
					set sink($j,$i,$k) [new Agent/TCPSinkMonitor]
					#puts sink($j,$i,$k)
					$ns attach-agent $n($j) $sink($j,$i,$k)

					$ns connect $sink($j,$i,$k)  $tcp($i,$j,$k)
					set ftp($i,$j,$k) [$tcp($i,$j,$k) attach-source FTP]
					$ns at 100.0 "$ftp($i,$j,$k) send [expr $data($j,$i)/$x * $dataMagnifier] "
					#$ns at [expr $rank($i)*1.0] "$ftp($i,$j,$k) send [expr $data($j,$i)/$x * 10000] "
				
			
				}
			}
		}	
	}
}

#initialize the tcp connection between mongos and mongod
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
}


proc uniformWorkload {} {
	global sender receiver ns nodeNum
	#every t seconds
	set t 0.1
	set now [$ns now]
	
	for {set i 0} {$i < $nodeNum} {incr i} {
		#puts "$now sender($i) send 10"
		$ns at $now "$sender($i) send 10 \"$receiver($i) app-recv $receiver($i) $sender($i) $now $i \" "
	}
	
	$ns at [expr $now+$t] "uniformWorkload"	
}

Application/TcpApp instproc app-recv { recv send sendTime i} {
	global ns
	#puts "receive time: [$ns now] send time: $sendTime"
	$ns at [$ns now] "$recv send 2000 \"$send app-recv1 $i $sendTime\""	
}

Application/TcpApp instproc app-recv1 { rece sendTime } {
	global ns latencyFile
	set now [$ns now]
	puts $latencyFile "$now: Latency for $rece: [expr $now - $sendTime]"
	recordLatency $rece [expr $now - $sendTime]
}

#start experiments
$ns at 0.0 "recordCompletionTime"
$ns at 0.1 "uniformWorkload"
#$ns at 0.0 "setAverageLatencyRecord"
$ns at 100.0 "initialAverageLatency"
$ns at 105.0 "dynamicSchedule"
$ns at 700.0 "printFinish"
$ns at 700.0 "finish"

$ns run

