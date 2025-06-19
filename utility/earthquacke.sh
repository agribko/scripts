#!/bin/bash
 place=`curl -s https://earthquake.usgs.gov/fdsnws/event/1/query\?format\=geojson\&minlatitude\=30\&maxlatitude\=40\&minlongitude\=130\&maxlongitude\=142\&endtime\=now`
 country="Japan"
 echo "Today's earthquakes:"
 for i in {0..5}
 do
  x="$(echo $place | jq -r ".features[$i].properties.place" | awk '{print $6}')"
  updated="$(echo $place | jq -r ".features[$i].properties.time" | awk '{print substr($0,1,10)}')"
  if [ "$x" = "$country" ]
  then
    echo "Time: " $(gdate -d @$updated +"%Y-%m-%dT%H-%M"); echo $place | jq -r ".features[$i].properties.title"
  fi
 done
