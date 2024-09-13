#!/bin/bash

#NOTES: FIREWALL NEEDS TO BE DISABLED
#NOTES: \r\033[K - CARRIAGE RETURN AND ERASE LINE ABOVE

#VARIABLES
command=0
counter=0
array=()
sp="/-\|"
sc=${sp:0:1}
timestamp_no_echo=$(date +"%s")
option=0
step=0
step_echo=0
comm=0
progress=0
diff=0
column=0
recipe_count=0
#empty_array=(0 0 0 0 0 0 0 0 0 0 0 0 0)


# #ENTRY
echo -e "\nSelect Comms Protocol"
echo "1 - TCP Sockets"
echo "2 - Serial Protocol"


read -r comm 

case $comm in

    1)
    echo "Type IP Address:  xxx.xxx.xxx.xxxx"
    read -r address 
    echo "Type Port: xxxx"
    read -r port 
    ;;

    2)

    echo "Type Serial Port: ttySX or ttyUSBX"
    read -r port 
    ;;

    *)
    echo Invalid Option
	exit
    ;;

esac

#ENTRY
echo -e "\nSelect an Option"
echo "1 - Read Recipe from PLC to CSV"
echo "2 - Write Recipe from CSV to PLC"


read -r option 

case $option in

    1)
    echo -e "\nRead Recipe from PLC Selected"
    echo -e "\nType file name with CSV extension: e.g. recipe.csv"
    read -r filename 
    rm -f /p/a/t/h $filename
    rm -f /p/a/t/h temp1.csv
    touch $filename #create empty file
    touch temp1.csv #create empty file
    
    ;;

    2)

    echo "Write Recipe to PLC Selected"
    echo "Type file name with CSV extension: e.g. recipe.csv"
    read -r filename 
    
    ;;

    *)
    echo Invalid Option
	exit
    ;;

esac
# comm=1
# option=2
# address="192.168.5.252"
# port="1800"
# filename="recipe.csv"






#SET COMMS OPTIONS
if [ $comm == 1 ]; then

	fd=5
    comms_par=5
   # exec 5<&- #close connection if open
    echo "Estabilishing Comms..."
    exec 5<>/dev/tcp/$address/$port || exit
    echo "Comms Started!"
    echo -e "Address:"$address
    echo -e "Port:"$port'\n'
    
	

elif [ $comm == 2 ]; then

    echo "Estabilishing Comms..."
   
    echo "Comms Started!"
    comms_par="/dev/$port"
    echo -e "Port:"$comms_par'\n'
    #comms_par="/dev/pts/3"
#	stty -F /dev/$PORT 9600 cs8 -cstopb -parenb -crtscts

        
    
fi



###########FUNCTIONS############



#RUN ECHO
run_echo(){
if [ $comm == 1 ]; then
		 
         $1 >& $2
        # echo $key
    elif [ $comm == 2 ]; then
		
          $1> $2
       
    fi
}


#SET COMMS OPTIONS TO PLC
if [ $option == 1 ]; then #receive recipes from PLC

    run_echo "echo -e O1" $comms_par #Send command encoded to PLC	
    recipe_count=899

elif [ $option == 2 ]; then #send recipes to PLC

    run_echo "echo -e O2" $comms_par #Send command encoded to PLC
    recipe_count=$(head -n +1 $filename | tr -cd ';' | wc -c | awk '{print $1+1}') #count columns in CSV file
    recipe_count=$(expr $recipe_count - 2 ) #offset because first column is empty and starts at 1, and step at 0c 

fi

sleep 0.5s




########FIRST STEP######################
step=$(expr $step)
step_out="S""${step}" #Encode Step
timestamp_start=$(date +"%s")


run_echo "echo -e $step_out" $comms_par #Send command 
#echo -e "\nStep Sent:$step"
######READ FROM PLC RECIPE################
read_recipe() {


    
    if [ $comm == 1 ]; then
		# echo -e "\r\033[KWaiting Echo"
      #   step_read=$(timeout 0.25s cat <&$comms_par) #TCP
         read -st 0.25 step_read <&$comms_par
    elif [ $comm == 2 ]; then
		#echo -e "\r\033[Waiting Echo"
        read -st 0.25 step_read < "$comms_par" #serial
    fi
    step_echo=${step_read:1:5}


   # sleep 3s 
    if [ ! -z "$step_read" ]; then #check if not empty
      #  echo -e "\nStep Sent:$step"
      #   echo -e "\nStep plain:$step_read\n"
        if [ "$step_read" == "$step_out" ]; then
         #   echo -e "\nStep Received:$step_echo\n"
  
            
            #read data from outputfile to an element
            if [ $comm == 1 ]; then
              #  parameter=$(timeout 0.01s cat <&$comms_par) 
                read -s -t 0.5  parameter <&$comms_par #TCP

            elif [ $comm == 2 ]; then
                read -s -t 0.5 parameter < "$comms_par" #serial
            fi
        #     echo -e "${parameter[@]}"
            parameter_t=${parameter#*A} # receive encoded data after'A' - added in PLC
            parameter_t=${parameter_t%:*} # removes garbage data after end delimiter ':' - added in PLC
            read -a array <<< $parameter_t #data is parsed as array - on PLC side a white space was added after each value as array element delimiter. 
             
         #  echo -e "${array[@]}"
           

            #Create temp.csv file and parse array to it
            rm -f /p/a/t/h temp.csv
            touch temp.csv
            index=0
            for record in "${array[@]}"
            do
                echo $record >> temp.csv
          #      echo "Record at index-${index} : $record" #display elements - for debuging
                ((index++))
            done 
            # #Join  temp with temp1. Temp1 holds the data for the next iteration
            paste -d ';' temp1.csv  temp.csv > $filename # after -d ';' is the separator
            #copy the output file to temp1 for the next iteration
            cp $filename temp1.csv

            #sleep 0.5s
            progress=$((($step*100) / 899))

            echo -ne "\033[K\rUpload Completion:" $progress "% - Recipe Received:" $step " of 899 and Stored"
           

            #INCREMENT STEP
            step=$(expr $step + 1)
            step_out="S""${step}" #encode step
            run_echo "echo -e $step_out" $comms_par #Send command 
            timestamp_start=$(date +"%s")
        fi
  
    fi
}


######WRITE TO PLC RECIPE##################
write_recipe() {


 run_echo "echo -e $step_out" $comms_par #Send command 

    if [ $comm == 1 ]; then
	#	 echo -e "\nWaiting Echo"
        # step_read=$(timeout 60s cat <&$comms_par)
         read -st 0.25 step_read <&$comms_par
        # echo $key
    elif [ $comm == 2 ]; then
	#	echo -e "\nWaiting Echo"
        read -st 0.25 step_read < "$comms_par"
        
    fi
    step_echo=${step_read:1:5}

    if [ ! -z "$step_read" ]; then #check if not empty
     #   echo -e "\nStep Received:$step_echo\n"
        if [ $step_read == $step_out ]; then

          #  sleep 0.01s
            #Parse CSV to array - whole line
            # while IFS= read -a line 
            # do
            #     array+=("$line")
            # done < $filename


            column=$(expr $step + 2) #First column is empty. Column starts at 1 , but step at 0, hence the '2' offset.
            #Parse CSV to array, one column at a time
            array=( $(tail -n +1 $filename | cut -d ';' -f$column) ) # after -d is the separator. The parameter fXXX is the column to cut from the csv file. 
            #tail +1 starts at first line

            array[0]="D""${array[0]}" # encode 'D"  to indicate start of array data
            #display elements - for debuging
            # index=0
            # for record in "${array[@]}"
            # do
            #     echo "Record at index-${index} : $record"
            #     ((index++))
            # done
           
           
            #Parse array to output
            run_echo "echo -e ${array[*]}" $comms_par #Send array to output


            
            progress=$((($step*100) / $recipe_count))

            echo -ne "\033[K\rDownload Completion:" $progress "% - Recipe Sent:" $step "of" $recipe_count
            
            #INCREMENT STEP
            step=$(expr $step + 1)
            step_out="S""${step}"
             # echo -e "\nStep Sent:$step"
          #  run_echo "echo -e $step_out" $comms_par #Send command 
            timestamp_start=$(date +"%s")
           
        fi
  
    fi
}



#SPINNING BAR - NOT USED ON THIS PROJECT
spinning_bar() {
    
    ctu=$[ctu+1]
    #spinning bar
    echo -ne  '\rWaiting Command...'$sc
    sc=${sp:ctu:1}
    #echo $ctu
    if [ $ctu -gt 3 ] ; then
        sc='/'
        ctu=0
        
    fi
    
 
   # sleep 0.25s


}



#CHECK COMMS - NOT FUNCTIONAL
check_tcp () {

if ! exec 5>/dev/tcp/192.168.2.252/2103 ; then

	echo "No Connection!"
	exec 5<&-
	exit
fi

}





#FOREVER LOOP
while true; do

    timestamp_now=$(date +"%s")

    #spinning_bar
    #check_tcp


    if [ $option == 1 ]; then

        read_recipe
    
    elif [ $option == 2 ]; then

        write_recipe

    fi

    #last recipe
    if [ $step -gt $recipe_count ]; then
        rm -f /p/a/t/h temp1.csv
        rm -f /p/a/t/h temp.csv
        echo -ne '\r\033[KOperation Completed!\n'
        if [ $comm == 1 ]; then
            exec 5<&- #close TCP connection if open
        fi
        exit
    fi
	
    
    #timeout no received command within time
    diff=$((timestamp_now-timestamp_start))
    if [ $diff -ge 15 ]; then
        echo -ne '\r\033[KTimeout Comm!\n'
     #   echo $diff
    exit
    fi
    # echo $diff
    

#printf "GET /gethighscore?level=1 HTTP/1.1\r\n" >&5

#response=$(timeout 0.5s cat <&5)


#echo $response

done
