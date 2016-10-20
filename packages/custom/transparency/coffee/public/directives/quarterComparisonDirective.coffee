'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaQuartercomparison', ($rootScope, $window) ->
     restrict: 'EA'
     scope:
          data: '='
          events: '='
          getCurrentLanguage: '&'
     link: ($scope,element,attrs) ->
          updateDiagram = (oldValue, newValue) ->
               margin = {top: 30, right: 100, bottom: 75, left: 100}
               data = () ->
                    if $scope.data
                         result = [
                              {
                                   values:
                                        [
                                        ]
                              }
                         ]
                         min = Number.POSITIVE_INFINITY
                         max = Number.NEGATIVE_INFINITY
                         for i in [0...$scope.data.length]
                              for quarter in [1...5]
                                   valueQuarter = $scope.data[i].values[quarter-1].y
                                   if i is 0
                                        valuePreviousQuarter = 0
                                   else
                                        valuePreviousQuarter = $scope.data[i-1].values[quarter-1].y
                                   if i isnt 0 and valueQuarter isnt 0 and valuePreviousQuarter isnt 0
                                        difference = valueQuarter - valuePreviousQuarter
                                        if min > difference
                                             min = difference
                                        if max < difference
                                             max = difference
                         for i in [0...$scope.data.length]
                              for quarter in [1...5]
                                   valueQuarter = $scope.data[i].values[quarter-1].y
                                   if i is 0
                                        valuePreviousQuarter = 0
                                   else
                                        valuePreviousQuarter = $scope.data[i-1].values[quarter-1].y
                                   if i is 0 or valueQuarter is 0 or valuePreviousQuarter is 0
                                        result[0].values.push {
                                             label: $scope.data[i].key + "/Q" + quarter
                                             value: 0
                                             color: 'gray'
                                        }
                                   else
                                        difference = valueQuarter - valuePreviousQuarter
                                        color = 'steelblue'
                                        if difference is min
                                             color = 'lightgreen'
                                        else if difference is max
                                             color = 'lightcoral'
                                        result[0].values.push {
                                             label: $scope.data[i].key + "/Q" + quarter
                                             value: difference
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
                    document.getElementById("quarterComparison").appendChild(newText);

               drawLine = (x, y1, y2, className) ->
                    line = document.createElementNS(svgNS,"line");
                    line.setAttributeNS(null,"id","line");
                    line.setAttributeNS(null,"x1",x);
                    line.setAttributeNS(null,"x2",x);
                    line.setAttributeNS(null,"y1",y1);
                    line.setAttributeNS(null,"y2",y2);
                    line.setAttributeNS(null, "class", "event eventLine " + className);
                    document.getElementById("quarterComparison").appendChild(line);

               drawEventGuideline = (numericDate, date, bars, className, eventName, y1, y2, additionalText) ->
                    #calculate containing bar
                    index = Math.floor((numericDate - (Number($scope.data[0].key) + $scope.data[0].values[0].x)) / 0.25)
                    x = margin.left
                    x += (bars[index].transform.animVal[0].matrix.e)
                    x += (bars[index].firstChild.width.animVal.value * ((((numericDate - (Number($scope.data[0].key) + $scope.data[0].values[0].x))/0.25)%1)))
                    drawLine(x, y1, y2, className)
                    if additionalText
                         drawText(x, y1 - margin.top + 12, additionalText + eventName, className)
                    else
                         drawText(x, y1 - margin.top + 12, eventName, className)
                    drawText(x, y1 - margin.top + 24,  date.getDate() + '.' + (date.getMonth() + 1) + '.' + date.getFullYear(), className)



               drawEvents = (events) ->
                    groupOfBars = d3.select('.quartercomparison svg').selectAll('.nv-bar')
                    if !groupOfBars or groupOfBars.length is 0 or groupOfBars[0].length is 0
                         return
                    y1 = margin.top
                    y2 = d3.select('#quarterComparison')[0][0].height.animVal.value - margin.bottom #margin.top + groupOfBars[0][0].transform.animVal[0].matrix.f + groupOfBars[0][0].firstChild.height.animVal.value

                    for event in events
                         className = "predictable"
                         if !event.predictable
                              className = "inpredictable"

                         if !event.numericEndDate
                              drawEventGuideline event.numericStartDate, new Date(event.startDate), groupOfBars[0], className, event.name, y1, y2
                         else
                              drawEventGuideline event.numericStartDate, new Date(event.startDate), groupOfBars[0], className, event.name, y1, y2, "Start: "
                              drawEventGuideline event.numericEndDate, new Date(event.endDate), groupOfBars[0], className, event.name, y1, y2, "End: "



               nv.addGraph () ->
                    d3.select(".quartercomparison svg").selectAll(".event").remove()
                    chart = nv.models.discreteBarChart()
                    .x((d) ->
                         d.label)
                    .y((d) ->
                         d.value)
                    .staggerLabels(true)
                    .margin(margin)
                    .duration(0)

                    chart.yAxis.tickFormat (d) -> d.toLocaleString $scope.getCurrentLanguage(), {style:"currency",currency:"EUR"}
                    
                    d3.select('.quartercomparison svg')
                    .datum(data)
                    .call(chart);

                    angular.element($window).bind('resize', () ->
                         updateDiagram()
                    )

                    if $scope.events and $scope.events.length > 0
                         drawEvents($scope.events)
                    chart

          $scope.$watch 'data', updateDiagram, true