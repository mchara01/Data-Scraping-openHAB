#!/bin/bash

trap removeFiles 1 2 3 6

removeFiles() {

  echo "A signal is detected. Cleaning process is active."
  
  find . -name '*.dat' -type f -exec rm -rf {} \; 
    
  echo "Cleaning process finished."
  exit 1  
}

# The download_data implements the first functionality of this assignment. First a connection is made with the host.
# With the response we get, we check if the conncection was established successfuly and we close the connection. Then
# again we make a connection to our VM and for each link in the json in each item, we download their content separately. 
download_data() {
	exec 5<>/dev/tcp/10.16.30.35/8080
        echo -ne 'GET /rest/items HTTP/1.1\nHost: epl421-11.in.cs.ucy.ac.cy:8080\nUser-Agent: bash\$BASH_VERSION\nAccept:application/json\nConnection: close\n\n' >&5
	
	status=`cat <&5 | grep "HTTP/1.1" | cut -d" " -f2`
	if [ $status != 200 ]; then
		echo "An error has occured during the connection."
		exit 1
	fi
	
	exec 5>&-
        exec 5<&-

	exec 5<>/dev/tcp/10.16.30.35/8080
        echo -ne 'GET /rest/items HTTP/1.1\nHost: epl421-11.in.cs.ucy.ac.cy:8080\nUser-Agent: bash\$BASH_VERSION\nAccept:application/json\nConnection: close\n\n' >&5

        links=`cat <&5 | sed 's/,/\n/g' | grep 'link' | sed 's/:/ /1' | awk -F" " '{print $2}' | sed -e 's/^\"//' -e 's/\"$//' | cut -d"/" -f6`
	
	exec 5>&-
        exec 5<&-
	
	mkdir -p "items"
	cd "items/"
        for i in $links
        do
                temp="/rest/items/"$i
                exec 5<>/dev/tcp/10.16.30.35/8080
                echo -ne 'GET '$temp'  HTTP/1.1\nHost: epl421-11.in.cs.ucy.ac.cy:8080\nUser-Agent: bash\$BASH_VERSION\nAccept:application/json\nConnection: close\n\n' >&5
                cat <&5 | grep 'link' >> $i".json"
                exec 5>&-
                exec 5<&-
        done
}

# The process_data function processes the .json files we created in the first function. For each item, we get the name and
# the state of it. We then proceed to create an html file contailing this info in a user friendly way.
process_data() {
  	cd "items/"
	filenames=`ls | grep "^WeatherAndForecast_" | grep "\.json$"`
        echo "<html> <body> <table> <tr> <th colspan=\"3\"; style=\"border-bottom: 1px solid grey; font-size:300%; background-color: #C0C0C0;\">Wheather And Forecast</th></tr>" > "WheatherAndForecast.html"
        for i in $filenames
        do
		field_name=`cat $i | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f1 | sed 's/[A-Z]/ &/2'`
		state=`cat $i | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2,3`

                case $field_name in
                       "Station Id") echo "<tr> <td> <img src=\"icons/text.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
                  	[a-zA-Z]*" Temperature") state=`echo $state | cut -d" " -f1`
                                state=$state" °C"
                                echo "<tr> <td> <img src=\"icons/temperature.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
                        "Rain") echo "<tr> <td> <img src=\"icons/rain.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
                        [a-zA-Z]*" Time") state=`echo $state | sed 's/T/ /g' | cut -d"." -f1`
                                echo "<tr> <td> <img src=\"icons/time.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
                        "Atmospheric Humidity") echo "<tr> <td> <img src=\"icons/humidity.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
                        "Wind Speed") echo "<tr> <td> <img src=\"icons/wind.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
                        "Barometric Pressure") echo "<tr> <td> <img src=\"icons/pressure.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
			"Cloudiness") echo "<tr> <td> <img src=\"icons/cloudiness.png\" width=\"60%\"> </td>" >> "WheatherAndForecast.html";;
			*) echo "<tr> <td> </td>" >> "WheatherAndForecast.html";;
                esac

                echo "<td style=\"border-bottom: 1px solid grey;\"> "$field_name" </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherAndForecast.html"

        done
        echo "</table> </body> </html>" >> "WheatherAndForecast.html"         
}

# In visualize_data we create a graph to study the change of each one of this items. The graphs are created with
# the help of the gnuplot tool. All forecasted fields are left out due to the fact their would be nothing to
# study from their graph. For each graph the x-axis is the observation time item. The result is saved in a .png
# image.
visualize_data() {	
  	cd "items/"
	filenames=`ls | grep "^WeatherAndForecast_" | grep "\.json$"`

        for i in $filenames
        do
                field_name=`cat $i | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f1 | sed 's/[A-Z]/ &/2'`
                if [[ $field_name =~ "Forecast".* ]]; then
                        continue
                fi

                if [[ $field_name = "Observation Time" ]]; then
                        x_axis=`cat $i | sed 's/,/ /g' | awk '{print $2}' | sed -e 's/\"//g' -e 's/:/ /1' -e 's/\+/ /g'| cut -d" " -f2  | sed 's/\./ /1' | cut -d" " -f1`
                       x_array=($x_axis)
                fi
        done

	for i in $filenames
        do
                field_name=`cat $i | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f1 | sed 's/[A-Z]/ &/2'`

                if [[ $field_name =~ "Forecast".* ]]; then
                        continue
                fi


                if [[ $field_name != "Station Id" && $field_name != "Observation Time" ]]; then
                        y_axis=`cat $i | sed 's/,/ /g' | awk '{print $2}' | sed -e 's/\"//g' -e 's/:/ /1' -e 's/\+/ /g'| cut -d" " -f2`
                        y_array=($y_axis)
                        for ((j=0; j<${#x_array[@]}; j++))
                        do
                                echo "${x_array[$j]}"",""${y_array[$j]}" | sort -k 1 | sed 's/T/ /1' >> $i".dat" 
                   		
		   	done
			start_time=`head -1 $i".dat" | awk -F"," '{print $1}'`
			end_time=`tail -1 $i".dat" | awk -F"," '{print $1}'`
	   	   	start_date=`date +%s -d "$start_time"`
		        end_date=`date +%s -d "$end_time"`
			range_time=$((end_date-start_date))
		        x_ticks=$((range_time/5))
			gnuplot <<-EOFMarker  2> /dev/null
				set terminal pngcairo size 1000,500 enhanced font 'Verdana,8'
				set xdata time
				set timefmt '%Y-%m-%d %H:%M:%S'
				set format x "%d-%m\n%H:%M"
				set xzeroaxis linetype 3 linewidth 1.5		
				set ylabel "$field_name"
                                set xlabel "Observation Time"
                                set title "$field_name and time"
                                set term png
                                set output "$field_name.png"
				set datafile separator ","
                                set grid
				set xtics $x_ticks
				set style line 1 linetype 1 linecolor rgb "blue" linewidth 2.000
				plot '$i.dat' using 1:2 w l ls 1 title '$field_name'
			EOFMarker
	       fi

        done
        
        rm -rf *".dat" 
}

# For the fourth functionality I chose to combine the data of the openweathermap and the astro binding found in openhab.
# Some interesting information can be found in the html created from the combination of this two bindings names WeatherSunMoon.html.
# The astro binding provides us with some interesting information for the sun and moon. A recommendations.txt is also created.
combine_data() {
    echo "<html> <body> <table style=\"margin-left: auto; margin-right: auto;\"> <tr> <th colspan=\"3\"; style=\"border-bottom: 1px solid grey; font-size:200%; background-color: 33B8FF;\">Wheather forecast, Sun and Moon stuff!</th></tr>" > "WheatherSunMoon.html"
	for i in *.json
        do
                field_name=`cat $i | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f1 | sed 's/[A-Z]/ &/2'`
                state=`cat $i | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2,3`
                          
                case $field_name in           
                        "Rain") echo "<tr> <td> <img src=\"icons/rain.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\"> "$field_name" </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";; 
                        "Atmospheric Humidity") echo "<tr> <td> <img src=\"icons/humidity.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\"> "$field_name" </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                        "Wind Speed") echo "<tr> <td> <img src=\"icons/wind.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\"> "$field_name" </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                        "Cloudiness") echo "<tr> <td> <img src=\"icons/cloudiness.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\"> "$field_name" </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                        "Outdoor Temperature") state=`echo $state | cut -d" " -f1`;
                                state=$state" °C";
                                echo "<tr> <td> <img src=\"icons/temperature.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\"> "$field_name" </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;            
               esac
              
               case $i in
                   "LocalSun_Set_StartTime.json") state=`echo $state | sed 's/T/ /g' | cut -d"." -f1` 
                    echo "<tr> <td> <img src=\"icons/sunset.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\"> Sun set </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                   "LocalSun_Season_SeasonName.json")  echo "<tr> <td> <img src=\"icons/season.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\"> Season </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                   "LocalSun_Rise_StartTime.json") state=`echo $state | sed 's/T/ /g' | cut -d"." -f1` 
                    echo "<tr> <td> <img src=\"icons/sunrise.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Sun rise </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                  "LocalSun_Phase_SunPhaseName.json")  echo "<tr> <td> <img src=\"icons/sun.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Sun phase </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                  "LocalMoon_Zodiac_Sign.json")  echo "<tr> <td> <img src=\"icons/moon.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Current Zodiac Sign </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                  "LocalMoon_Rise_StartTime.json") state=`echo $state | sed 's/T/ /g' | cut -d"." -f1`  
                  echo "<tr> <td> <img src=\"icons/moon.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Moon rise </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                  "LocalMoon_Phase_MoonPhaseName.json")  echo "<tr> <td> <img src=\"icons/moon.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Moon phase </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                  "LocalMoon_Eclipse_TotalEclipse.json") state=`echo $state | sed 's/T/ /g' | cut -d"." -f1`  
                  echo "<tr> <td> <img src=\"icons/calendar.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Next total eclipse </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                   "LocalMoon_Eclipse_PartialEclipse.json") state=`echo $state | sed 's/T/ /g' | cut -d"." -f1`  
                   echo "<tr> <td> <img src=\"icons/calendar.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Next partial eclipse </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;
                   "LocalMoon_Distance_Distance.json")  echo "<tr> <td> <img src=\"icons/zoom.png\" width=\"60%\"> </td> <td style=\"border-bottom: 1px solid grey;\">  Distance from moon </td> <td style=\"text-align: right; border-bottom: 1px solid grey; color: grey\"> "$state" </td> </tr>" >> "WheatherSunMoon.html";;                   
              esac
        done
        echo "</table> </body> </html>" >> "WheatherSunMoon.html"
        
        # recomendations.txt is created below.
        TIME_VALUE=`cat "WeatherAndForecast_Current_ObservationTime.json" | tail -1 | sed 's/,/ /g' | awk '{print $2}' | sed -e 's/\"//g' -e 's/:/ /1' -e 's/\+/ /g'| cut -d" " -f2  | sed 's/\./ /1' | cut -d" " -f1 | sed 's/T/ /1'`
        RAIN_VALUE=`cat "WeatherAndForecast_Current_Rain.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2`
        declare -i HUMIDITY_VALUE=`cat "WeatherAndForecast_Current_AtmosphericHumidity.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2`
        WIND_VALUE=`cat "WeatherAndForecast_Current_WindSpeed.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2`
        TEMPERATURE_VALUE=`cat "WeatherAndForecast_Current_OutdoorTemperature.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2`    
        SEASON_VALUE=`cat "LocalSun_Season_SeasonName.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2`    
        ZODIAC_VALUE=`cat "LocalMoon_Zodiac_Sign.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2`    
        ECLIPSE_VALUE=`cat "LocalMoon_Eclipse_TotalEclipse.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2 | sed 's/T/ /g' | cut -d"." -f1`  
        DISTANCE_VALUE=`cat "LocalMoon_Distance_Distance.json" | tail -1 | cut -d"," -f1,2 | awk -F"_" '{print $NF}' | sed -e 's/\",\"/ /g' -e 's/\":\"/ /g' -e 's/\"//g' -e 's/state//g' | tr -s " " | cut -d" " -f2`  
             
        echo "Recomendations for day" $TIME_VALUE >> "recomendations.txt"
        echo "-------------------------------------" >> "recomendations.txt"
        
        if [ $RAIN_VALUE != "0.0" ]; then
            echo "->Today it will rain. Don't forget to get your ombrella if you are leaving the house." >> "recomendations.txt"     
        else
            echo "->It will not rain today." >> "recomendations.txt" 
        fi 
        
        if [ $HUMIDITY_VALUE -gt 30 ]; then
            echo "->The level of humidity today looks high("$HUMIDITY_VALUE" %)! It is recommended that people with breathing problems stay indoors." >> "recomendations.txt"     
        else
            echo "->The humidity level seem low today." >> "recomendations.txt" 
        fi 
        
        if [ $WIND_VALUE != "0.0" ]; then
            echo "->Looks kind of windy today("$WIND_VALUE" m/s)! Make sure you grab a jacket with you." >> "recomendations.txt"     
        else
            echo "->Seems today will not be so windy." >> "recomendations.txt" 
        fi 
        
        if (( $(echo "$TEMPERATURE_VALUE >= 25.0" | bc -l) )); then
           echo "->The temperature for the day is looking good("$TEMPERATURE_VALUE" C). Whear your shorts and do not forget to put on you sun block." >> "recomendations.txt"     
        else
           echo "->The temperature is looking kind of low today("$TEMPERATURE_VALUE" C). Make sure you wear sufficient clothes." >> "recomendations.txt" 
        fi
         
        echo "*************************************" >> "recomendations.txt"  
        echo "Interesting astronomical stuff!" >> "recomendations.txt"
        echo "-------------------------------------" >> "recomendations.txt"
        echo "Season: "$SEASON_VALUE >> "recomendations.txt"
        echo "Current Zodiac sign: "$ZODIAC_VALUE >> "recomendations.txt"
        echo "Next total eclipse: "$ECLIPSE_VALUE >> "recomendations.txt"
        echo "Distance from moon: "$DISTANCE_VALUE" km" >> "recomendations.txt"
        echo "-------------------------------------" >> "recomendations.txt"
        printf "\n\n" >> "recomendations.txt"        
}

# Starting point of my script. First the necessary checks are made to see
# if the correct amount of arguments are given. If the argument given is
# valid, we call the appropriate function correspondig to the argument.

if [ $# != 1 ]; then
	echo "Usage: ./openhab_scraping.sh <one of the following arguments: -d(download data), -p(process data), -v(visualize), -c(combine data)>"
	exit 1
elif [[ $1 != "-d" && $1 != "-p" && $1 != "-v" && $1 != "-c" ]]; then
	echo "Wrong argument given!"
	exit 1
else
	argument=$1
fi


if [ $argument = "-d" ]; then
	download_data
elif [ $argument = "-p" ]; then
	process_data
elif [ $argument = "-v" ]; then
	visualize_data
elif [ $argument = "-c" ]; then
	download_data
 	combine_data
fi

