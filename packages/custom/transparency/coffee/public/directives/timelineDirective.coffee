'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaTimeline', ($rootScope, $window) ->
     restrict: 'EA'
     scope:
          data: '='
          events: '='
          getCurrentLanguage: '&'
     link: ($scope,element,attrs) ->
          margin = {top: 50, right: 100, bottom: 75, left: 100}

          updateDiagram = (oldValue, newValue) ->
               data = () ->
                    result = [
                         {
                              values:
                                   [
                                   ]
                         }
                    ]
                    if $scope.data and $scope.data.data and $scope.data.data.values
                         max = Number.NEGATIVE_INFINITY
                         min = Number.POSITIVE_INFINITY
                         for transfer in $scope.data.data.values
                              if max < transfer[1] and transfer[1] isnt 0
                                   max = transfer[1]
                              if min > transfer[1] and transfer[1] isnt 0
                                   min = transfer[1]

                         for transfer in $scope.data.data.values
                              str = ""+transfer[0]
                              label = (""+transfer[0]).substring 0, 4
                              if (str.indexOf '.25') != -1
                                   label += "/Q2"
                              if (str.indexOf '.5') != -1
                                   label += "/Q3"
                              if (str.indexOf '.75') != -1
                                   label += "/Q4"
                              if (str.indexOf '.') is -1
                                   label += "/Q1"

                              color = "steelblue"
                              if (transfer[1] is min)
                                   color = "lightgreen"
                              else if (transfer[1] is max)
                                   color = "lightcoral"

                              result[0].values.push {
                                   label: label,
                                   value: transfer[1],
                                   color: color
                              }
                    result


               svgNS = "http://www.w3.org/2000/svg";

               drawText = (x, y, text, className) ->
                    newText = document.createElementNS(svgNS,"text");
                    newText.setAttributeNS(null,"x",x);
                    newText.setAttributeNS(null,"y",y);
                    newText.setAttributeNS(null, "class", "event eventText " + className);
                    textNode = document.createTextNode(text);
                    newText.appendChild(textNode);
                    document.getElementById("timeline").appendChild(newText);

               drawLine = (x, y1, y2, className) ->
                    line = document.createElementNS(svgNS,"line");
                    line.setAttributeNS(null,"id","line");
                    line.setAttributeNS(null,"x1",x);
                    line.setAttributeNS(null,"x2",x);
                    line.setAttributeNS(null,"y1",y1);
                    line.setAttributeNS(null,"y2",y2);
                    line.setAttributeNS(null, "class", "event eventLine " + className);
                    document.getElementById("timeline").appendChild(line);

               drawSymbol = (x, y, className, type) ->
                    document.getElementById "timeline"
                    symbol = document.createElementNS(svgNS, "text");
                    symbol.setAttributeNS(null,"x",x);
                    symbol.setAttributeNS(null,"y",y);
                    symbol.setAttributeNS(null, 'font-family', 'Glyphicons Halflings')
                    symbol.setAttributeNS(null, 'font-size', '10pt')
                    if type and type is "start"
                         symbol.setAttributeNS(null, "class", "event eventText start " + className);
                         textNode = document.createTextNode(" " + String.fromCharCode(0xE069));
                    else if type and type is "end"
                         symbol.setAttributeNS(null, "class", "event eventText end " + className);
                         textNode = document.createTextNode(String.fromCharCode(0xE077) + " ");
                    else if type and type is "standard"
                         symbol.setAttributeNS(null, "class", "event eventText " + className);
                         textNode = document.createTextNode(String.fromCharCode(0xE069) + " " + String.fromCharCode(0xE077));
                    else if className is "predictable"
                         symbol.setAttributeNS(null, "class", "event eventText " + className);
                         textNode = document.createTextNode(String.fromCharCode(0xE023));
                    else if className is "inpredictable"
                         symbol.setAttributeNS(null, "class", "event eventText " + className);
                         textNode = document.createTextNode(String.fromCharCode(0xE162));

                    symbol.appendChild(textNode);
                    document.getElementById("timeline").appendChild(symbol);

               drawEventGuideline = (numericDate, date, bars, className, eventName, y1, y2, type) ->
                    #calculate containing bar
                    index = Math.floor((numericDate - $scope.data.data.values[0][0]) / 0.25)
                    x = margin.left
                    x += (bars[index].transform.animVal[0].matrix.e)
                    x += (bars[index].firstChild.width.animVal.value * (((numericDate - $scope.data.data.values[0][0])/0.25)%1))
                    drawLine(x, y1, y2, className)
                    drawSymbol x, y1 - margin.top + 12, className
                    drawText(x, y1 - margin.top + 24, eventName, className)
                    drawText(x, y1 - margin.top + 36,  date.getDate() + '.' + (date.getMonth() + 1), className)
                    drawSymbol x, y1 - margin.top + 48, className, type

               drawEvents = (events) ->
                    groupOfBars = d3.select('.timeline svg').selectAll('.nv-bar')
                    if !groupOfBars or groupOfBars.length is 0 or groupOfBars[0].length is 0
                         return
                    y1 = margin.top
                    y2 = margin.top + groupOfBars[0][0].transform.animVal[0].matrix.f + groupOfBars[0][0].firstChild.height.animVal.value

                    for event in events
                         className = "predictable"
                         if !event.predictable
                              className = "inpredictable"

                         if !event.numericEndDate
                              drawEventGuideline event.numericStartDate, new Date(event.startDate), groupOfBars[0], className, event.name, y1, y2, "standard"
                         else
                              drawEventGuideline event.numericStartDate, new Date(event.startDate), groupOfBars[0], className, event.name, y1, y2, "start"
                              drawEventGuideline event.numericEndDate, new Date(event.endDate), groupOfBars[0], className, event.name, y1, y2, "end"


               nv.addGraph () ->
                    d3.select(".timeline svg").selectAll(".event").remove()
                    chart = nv.models.discreteBarChart()
                    .x((d) ->
                         d.label)
                    .y((d) ->
                         d.value)
                    .staggerLabels(true)
                    .margin(margin)
                    .duration(0)

                    chart.yAxis.tickFormat (d) -> d.toLocaleString $scope.getCurrentLanguage(), {style:"currency",currency:"EUR"}

                    d3.select('.timeline svg')
                    .datum(data)
                    .call(chart);

                    angular.element($window).bind('resize', () ->
                         updateDiagram())

                    if $scope.events and $scope.events.length > 0
                         drawEvents($scope.events)
                    chart

          $scope.$watch 'data', updateDiagram, true
          $scope.$watch 'events', updateDiagram, true