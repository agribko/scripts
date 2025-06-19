#!/bin/bash
 echo -n `date +"%Y-%m-%d"`;echo -n " Current temeperature: ";curl -s https://api.met.no/weatherapi/locationforecast/2.0/compact\?lat\=35.66\&lon\=139.719\
 | jq -r '.properties.timeseries[0] |"\(.data.instant.details.air_temperature)°C Wind: \(.data.instant.details.wind_speed) m/s Percipitation: \(.data.next_6_hours.details.precipitation_amount)"'
