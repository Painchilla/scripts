#! /bin/bash
### Pre-Setup - DO NOT TOUCH!
declare -A STREAMKEYS
declare -A PUBLISHED

### Variables to be Set by User:
TEST=false
RTMP_SERVER_IP="192.168.22.4"
STREAMKEYS["painchilla"]="NO_STREAMKEY_IN_HERE"
STREAMKEYS["example"]="live_12345678_MYRANDOMSTRINGOFCHARSAND123456"

## Variables for Stream-Settings:
# Resolution in Pixels: 1080 for 1920x1080p(FHD), 900 for 1600x900p, 720 for 1280x720p(HD)
RESOLUTION=900
# Framerate in FPS
FRAMERATE=60
# X264-Preset used for Streaming. Adjust if stream becomes unstable. Possible Values: veryfast/fast/medium/slow/slower
X264PRESET=fast
#Bitrate in kbps: 6000 -> 6000kbps -> 6mbps / 3000 -> 3mbps
BITRATE=6000

### Variables not to be set by User:
PIDLOCATION=/run/stream_transcodes

### Functions

## This function gets all Published Streams of an RTMP-Server Stat endpoint and saves them as XML in the PUBLISHED-Array
function getPublishedStreams {
local URL=${1:-"http://localhost:8080/stat"}
# Get XML from nginx-Endpoint
local XML=$(curl $URL 2>/dev/null)
#Parse XML to only contain Stream objects
local STREAMS_STRING=$(echo $XML | xmllint --xpath "//stream" - 2>/dev/null)
#Parse String into Array, each containing one Stream as XML-Object
local STREAMS_ARRAY=$(echo $STREAMS_STRING | tr -d ' ' | sed -e 's/<stream>/\n<stream>/g')
#Iterate over Streams and collect those, which are Published by a client
for i in ${STREAMS_ARRAY[@]}
do
        #Check if Published
        if [ $(echo "$i" | grep 'publishing') != "" ]
        then
                #Get Stream Name
                local NAME=$(echo "$i" | xmllint --xpath "string(//name)" -)
                #Set a new ArrayElement to contain the streamobject
                PUBLISHED["$NAME"]="$i"
        fi
done
}

function transcode_stream {
        local USER=$1
        local KEY=${STREAMKEYS["$USER"]}
        if [ -z $KEY ]
        then
                echo "Streamkey wurde nicht gefunden. Bitte Streamkey eingeben"
                return 1;
        fi

        if [ "$TEST" == "true" ]
        then
                echo "Now Streaming for $USER as a Test-Stream"
                ffmpeg -i "rtmp://$RTMP_SERVER_IP:1935/live/$USER" -preset $X264PRESET -b:a 160k -vf scale=-1:$RESOLUTION:lanczos -r $FRAMERATE -vcodec libx264 -x264-params keyint=$(( 4 * $FRAMERATE )) -pix_fmt yuv420p -level 4 -c:a aac -bf 4 -f flv -b:v $(($BITRATE))k -maxrate $(( $BITRATE * 120 /100))k -bufsize $(( $BITRATE * 50 / 100 ))k "rtmp://live-ams.twitch.tv/app/$KEY?bandwidthtest=true" 2>/dev/null &
                echo $! > $PIDLOCATION/$USER.pid
        else
                echo "Now Streaming for $USER LIVE"
                ffmpeg -i "rtmp://$RTMP_SERVER_IP:1935/live/$USER" -preset $X264PRESET -b:a 160k -vf scale=-1:$RESOLUTION:lanczos -r $FRAMERATE -vcodec libx264 -x264-params keyint=$(( 4 * $FRAMERATE )) -pix_fmt yuv420p -level 4 -c:a aac -bf 4 -f flv -b:v $(($BITRATE))k -maxrate $(( $BITRATE * 120 /100))k -bufsize $(( $BITRATE * 50 / 100 ))k -metadata fps="$FRAMERATE" -metadata displayHeight="" -metadata displayWidth="" -metadata level="4" "rtmp://live-fra.twitch.tv/app/$KEY" 2>/dev/null &
                echo $! > $PIDLOCATION/$USER.pid
        fi
}


### Create PID-location
##mkdir $PIDLOCATION
touch $PIDLOCATION/test

getPublishedStreams "http://$RTMP_SERVER_IP:8080/stat"

for stream in ${PUBLISHED[@]}
do
        STREAMNAME=$(echo "$stream" | xmllint --xpath "string(//name)" -)
        #echo $STREAMNAME
        #Now Check if Stream is already being Transcoded
        if [ ! -f $PIDLOCATION/$STREAMNAME.pid ]
        then
                # Stream is not being Transcoded
                # Echo PID into
                #echo $BASHPID > $PIDLOCATION/$STREAMNAME.pid
                # Now Start a Transcode-Instance for Stream
                transcode_stream $STREAMNAME
        else
                echo "Stream seems to already being transcoded by PID $(cat $PIDLOCATION/$STREAMNAME.pid)"
                ##TODO: Check if PID is really running or dead by accident
                if ps -p $(cat $PIDLOCATION/$STREAMNAME.pid) > /dev/null
                then
                        echo "Transcode is Running fine. Checking for next Stream."
                else
                        echo "Transcode is not running. Strange..."
                        echo "Removing PID-File and starting transcode now."
                #        echo $BASHPID > $PIDLOCATION/$STREAMNAME.pid
                        transcode_stream $STREAMNAME
                fi
        fi
done

exit
