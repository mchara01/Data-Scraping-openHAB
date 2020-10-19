## openHAB data scraping and analysis
![alt text](https://github.com/mchara01/Data-Mining-openHab/blob/main/images/openhab_logo.JPG?raw=true)

Implementation of a data collection and analysis script from the openHAB platform. Retrieval and processing of data from the openHAB server is accomplished though a script written in Bash. The data are extracted through openHAB REST API endpoints

### Architecture 
The central node of the automation system is the VM which has the role of the server with the openHAB server installed. The VM depicted in the illustration below is located within the closed network of the IT Department. Because there are no IoT devices within this network, a free weather service provider is used named OpenWeatherMap (https://openweathermap.org/api).

![alt text](https://github.com/mchara01/Data-Mining-openHab/blob/main/images/architecture.JPG?raw=true)

### Functionalities
1. `./openhab_scraping.sh -d`<br /> Downloads from openHAB the information of a collection of items and stores the data locally in a directory in the current location. A .json file will be created for each item.
1. `./openhab_scraping.sh -p`<br /> Queries made on data stored locally. More specifically,information are read from the item json files and will an HTML file will be created that looks like the image below.
1. `./openhab_scraping.sh -v`<br /> Creates a graphical representation of the data in the form of a graph using the Gnuplot tool (http://www.gnuplot.info/).
1. `./openhab_scraping.sh -c`<br /> Combination of data from different bindings.
![alt text](https://github.com/mchara01/Data-Mining-openHab/blob/main/images/app_results.JPG?raw=true)


