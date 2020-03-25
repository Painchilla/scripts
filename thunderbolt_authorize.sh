#! /bin/bash
DEVICES=(/sys/bus/thunderbolt/devices/*/authorized)
NAMES=(/sys/bus/thunderbolt/devices/*/device_name)
#Read Names from device_name-Files found in thunderbolt-dir
i=0
for name in ${NAMES[@]}
do
	NAMES[$i]=$(cat $name)
	i=$(( $i + 1 ))
done

#Now Iterate over all Devices
i=0
for device in ${DEVICES[@]}
do
#Check if Device is not authorized
if [ $(cat $device) -eq 0 ]
then
	#Device not authorized. Change to authorized by User
	echo 1 > $device
	echo "Authorized new Device: " ${NAMES[$i]}
else
	#Device already authorized
	echo "${NAMES[$i]} already Authorized"
fi
i=$(( $i + 1 ))
done
