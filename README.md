# toronto-data-science-jam-311
Visualization of [Toronto Open Data - 311 Service Requests](http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=3cdebe037654f210VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD)

Some prerequisits:

* GDAL tools: `brew install gdal`
* topojson: `npm install -g topojson`
* Jekyll: `gem install jekyll`

Directions:

* Process the data: `make`
* Build the app-site: `cd app/; jekyll serve`
* Direct your browser to [http://localhost:4000](http://localhost:4000)