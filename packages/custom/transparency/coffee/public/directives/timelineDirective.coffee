'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaTimeline', ($rootScope, $window) ->
     restrict: 'EA'
     scope:
          data: '='
          events: '='
          getCurrentLanguage: '&'
     link: ($scope,element,attrs) ->
          margin = {top: 30, right: 100, bottom: 75, left: 100}

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

               drawText = (x, y, text, color) ->
                    newText = document.createElementNS(svgNS,"text");
                    newText.setAttributeNS(null,"x",x);
                    newText.setAttributeNS(null,"y",y);
                    newText.setAttributeNS(null,"style","text-anchor: middle;");
                    newText.setAttributeNS(null, "class", "event");
                    newText.setAttributeNS(null, "fill", color)
                    newText.setAttributeNS(null, "font-size", "10")
                    textNode = document.createTextNode(text);
                    newText.appendChild(textNode);
                    document.getElementById("timeline").appendChild(newText);

               drawLine = (x, y1, y2, color) ->
                    line = document.createElementNS(svgNS,"line");
                    line.setAttributeNS(null,"id","line");
                    line.setAttributeNS(null,"x1",x);
                    line.setAttributeNS(null,"x2",x);
                    line.setAttributeNS(null,"y1",y1);
                    line.setAttributeNS(null,"y2",y2);
                    line.setAttributeNS(null,"stroke",color);
                    line.setAttributeNS(null,"stroke-width",1);
                    line.setAttributeNS(null, "class", "event");
                    document.getElementById("timeline").appendChild(line);

               drawEventGuideline = (numericDate, date, bars, color, eventName, y1, y2, additionalText) ->
                    #calculate containing bar
                    index = Math.floor((numericDate - $scope.data.data.values[0][0]) / 0.25)
                    x = margin.left
                    x += (bars[index].transform.animVal[0].matrix.e)
                    x += (bars[index].firstChild.width.animVal.value * (((numericDate - $scope.data.data.values[0][0])/0.25)%1))
                    drawLine(x, y1, y2, color)
                    if additionalText
                         drawText(x, y1 - margin.top + 12, additionalText + eventName, color)
                    else
                         drawText(x, y1 - margin.top + 12, eventName, color)
                    drawText(x, y1 - margin.top + 24,  date.getDate() + '.' + (date.getMonth() + 1) + '.' + date.getFullYear(), color)



               drawEvents = (events) ->
                    groupOfBars = d3.select('.timeline svg').selectAll('.nv-bar')
                    if !groupOfBars or groupOfBars.length is 0 or groupOfBars[0].length is 0
                         return
                    y1 = margin.top
                    y2 = margin.top + groupOfBars[0][0].transform.animVal[0].matrix.f + groupOfBars[0][0].firstChild.height.animVal.value

                    for event in events
                         color = "darkblue"
                         if !event.predictable
                              color = "red"

                         if !event.numericEndDate
                              drawEventGuideline event.numericStartDate, event.startDate, groupOfBars[0], color, event.name, y1, y2
                         else
                              drawEventGuideline event.numericStartDate, event.startDate, groupOfBars[0], color, event.name, y1, y2, "Start: "
                              drawEventGuideline event.numericEndDate, event.endDate, groupOfBars[0], color, event.name, y1, y2, "End: "


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
                         updateDiagram()
                         scope.$digest())

                    #nv.utils.windowResize(updateDiagram)
                    if $scope.events and $scope.events.length > 0
                         drawEvents($scope.events)
                    chart

          $scope.$watch 'data', updateDiagram, true
          $scope.$watch 'events', updateDiagram, true