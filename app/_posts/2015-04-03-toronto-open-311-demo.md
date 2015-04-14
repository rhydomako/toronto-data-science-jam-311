---
layout: post
title:  "Toronto 311 service call visualization"
date:   2015-04-03 23:10:34
categories: 
---

<link rel="stylesheet" href="http://cdn.leafletjs.com/leaflet-0.7.3/leaflet.css" />
<link rel="stylesheet" href="/311/css/metricsgraphics.css" />

<style>

path { 
  fill: #777;
  fill-opacity: 0.5;
  stroke: #999;
  stroke-width: 0.5;
}
path:hover {
  fill: #00f;
  fill-opacity: 0.8;
}

.fsa-label {
  fill: #000;
  font-size: 12px;
  font-weight: 300;
  text-anchor: middle;
}
.d3-tip {
  line-height: 1;
  font-weight: bold;
  padding: 12px;
  background: rgba(0, 0, 0, 0.8);
  color: #fff;
  border-radius: 2px;
}

/* Creates a small triangle extender for the tooltip */
.d3-tip:after {
  box-sizing: border-box;
  display: inline;
  font-size: 10px;
  width: 100%;
  line-height: 1;
  color: rgba(0, 0, 0, 0.8);
  content: "\25BC";
  position: absolute;
  text-align: center;
}

/* Style northward tooltips differently */
.d3-tip.n:after {
  margin: -1px 0 0 0;
  top: 100%;
  left: 0;
}

#map {
  width: 960px;
  height: 500px;
}

</style>

<div id="map"></div>
<div id="timeSeries"></div>

<script src="http://d3js.org/d3.v3.min.js"></script>
<script src="http://d3js.org/topojson.v1.min.js"></script>
<script src="http://cdn.leafletjs.com/leaflet-0.7.3/leaflet.js"></script>
<script src="http://labratrevenge.com/d3-tip/javascripts/d3.tip.v0.6.3.js"></script>
<script src="/311/js/metricsgraphics.min.js"></script>

<script>

var color = d3.scale.threshold()
    .domain([0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4])
    .range(["#fff7ec", "#fee8c8", "#fdd49e", "#fdbb84", "#fc8d59", "#ef6548", "#d7301f", "#b30000", "#7f0000"]);

var map = L.map('map').setView([43.708, -79.3703], 11);

L.tileLayer('http://{s}.tiles.mapbox.com/v4/{mapId}/{z}/{x}/{y}.png?access_token={token}', {
    attribution: 'Map data &copy; <a href="http://openstreetmap.org">OpenStreetMap</a> contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-BY-SA</a>, Imagery © <a href="http://mapbox.com">Mapbox</a>',
    maxZoom: 18,
    mapId: 'rhydomako.ll5lnog4',
    token: 'pk.eyJ1Ijoicmh5ZG9tYWtvIiwiYSI6IkZXN0k5em8ifQ.-ZW6vi94OM65M4xGlShDjA'
}).addTo(map);

var svg = d3.select(map.getPanes().overlayPane).append("svg"),
    g = svg.append("g").attr("class", "leaflet-zoom-hide");

var tip = d3.tip()
  .attr('class', 'd3-tip')
  .offset([-5, 0])
  .html(function(d) {
    return "<strong>Total number of service requests:</strong> <span style='color:red'>" + d.properties.Total + "</span><br> \
            <strong>Population:</strong> <span style='color:red'>" + d.properties.Population + "</span><br> \
            <strong>Average service requests per resident:</strong> <span style='color:red'>" + (d.properties.Total/d.properties.Population).toFixed(2) + "</span>";
  });

svg.call(tip);

d3.json("/311/fsas.json", function(error, fsas) {
  if (error) return console.error(error);

  var transform = d3.geo.transform({point: projectPoint}),
    path = d3.geo.path().projection(transform);

  var labels = g.selectAll('.fsa-label')
      .data(topojson.feature(fsas, fsas.objects.fsas).features)
    .enter().append('text')
      .attr("class", function(d) { return "fsa-label " + d.id; })
      .attr("transform", function(d) { return "translate(" + path.centroid(d) + ")"; })
      .attr("dy", ".20em")
      .text(function(d) { return d.id; });

  var feature = g.selectAll('path')
      .data(topojson.feature(fsas, fsas.objects.fsas).features)
    .enter()
      .append("path")
      .style("fill", function(d) { return color(d.properties.Total/d.properties.Population); })
      .attr("d", path)
      .on('mouseover', tip.show)
      .on('mouseout', tip.hide)
      .on('click', plotTS);

  map.on("viewreset", reset);
  reset();

  // Reposition the SVG to cover the features.
  function reset() {
    var bounds = path.bounds(topojson.feature(fsas, fsas.objects.fsas)),
        topLeft = bounds[0],
        bottomRight = bounds[1];

    svg .attr("width", bottomRight[0] - topLeft[0])
        .attr("height", bottomRight[1] - topLeft[1])
        .style("left", topLeft[0] + "px")
        .style("top", topLeft[1] + "px");

    g.attr("transform", "translate(" + -topLeft[0] + "," + -topLeft[1] + ")");

    feature.attr("d", path);
    labels.attr("transform", function(d) { return "translate(" + path.centroid(d) + ")"; })
        .style("font-size", function(d) { return (2*( map.getZoom() - 11) + 12) + "px" });
   }

   function projectPoint(x, y) {
     var point = map.latLngToLayerPoint(new L.LatLng(y, x));
     this.stream.point(point.x, point.y);
   }

   // Plot the timeseries
   function plotTS(x) {

    d3.csv("/311/"+x.id+".csv", function(error, data) {
      if (error) return console.error(error);

      data = MG.convert.date(data, 'date', '%Y-%m-%d');
      data.forEach(function(d){ d['value'] = +d['value']; });

      MG.data_graphic({
        data: data,
        right: 40,
        left:  90,
        bottom: 50,
        width: 1000,
        height: 300,
        target: '#timeSeries',
        title: x.id,
        x_accessor: 'date',
        y_accessor: 'value',
        y_label: 'Number of service requests',
        show_confidence_band: ['lower', 'upper'],
      });
     });
   }

   plotTS({'id':'all'});

});   

</script>

[Source data](http://www1.toronto.ca/wps/portal/contentonly?vgnextoid=3cdebe037654f210VgnVCM1000003dd60f89RCRD&vgnextchannel=1a66e03bb8d1e310VgnVCM10000071d60f89RCRD)


