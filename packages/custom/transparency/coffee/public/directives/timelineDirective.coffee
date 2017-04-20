'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaTimeline', ($rootScope, $window) ->
     restrict: 'EA'
     scope:
          data: '='
          events: '='
          getCurrentLanguage: '&'
          barClick: '&'
     link: ($scope,element,attrs) ->
          margin = {top: 75, right: 100, bottom: 75, left: 100}

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
                                   color: color,
                                   class: 'theBar'
                              }
                    result


               svgNS = "http://www.w3.org/2000/svg";

               drawText = (id, x, y, text, className) ->
                    newText = document.createElementNS(svgNS,"text");
                    newText.setAttributeNS(null,"x",x);
                    newText.setAttributeNS(null,"y",y);
                    newText.setAttributeNS(null, "class", "event eventText " + className + " id" + id);
                    textNode = document.createTextNode(text);
                    newText.appendChild(textNode);
                    document.getElementById("timeline").appendChild(newText);

               drawLine = (id, x, y1, y2, className) ->
                    line = document.createElementNS(svgNS,"line");
                    line.setAttributeNS(null,"id","line");
                    line.setAttributeNS(null,"x1",x);
                    line.setAttributeNS(null,"x2",x);
                    line.setAttributeNS(null,"y1",y1);
                    line.setAttributeNS(null,"y2",y2);
                    line.setAttributeNS(null, "class", "event eventLine " + className);
                    line.setAttributeNS(null, "onclick", "for (let el of document.querySelectorAll('.id" + id + "')) el.style.visibility = (el.style.visibility === 'hidden') ? 'visible' : 'hidden';");
                    document.getElementById("timeline").appendChild(line);

               drawSymbol = (id, x, y, className, type) ->
                    symbol = document.createElementNS(svgNS, "text");
                    symbol.setAttributeNS(null,"x",x);
                    symbol.setAttributeNS(null,"y",y);
                    symbol.setAttributeNS(null, 'font-family', 'Glyphicons Halflings')
                    symbol.setAttributeNS(null, 'font-size', '10pt')
                    if type and type is "start"
                         symbol.setAttributeNS(null, "class", "event eventText start " + className + " id" + id);
                         textNode = document.createTextNode(" " + String.fromCharCode(0xE077));
                    else if type and type is "end"
                         symbol.setAttributeNS(null, "class", "event eventText end " + className + " id" + id);
                         textNode = document.createTextNode(String.fromCharCode(0xE069) + " ");
                    else if type and type is "standard"
                         symbol.setAttributeNS(null, "class", "event eventText " + className + " id" + id);
                         textNode = document.createTextNode(String.fromCharCode(0xE077) + " " + String.fromCharCode(0xE069));
                    else if className is "predictable"
                         symbol.setAttributeNS(null, "class", "event eventText " + className + " id" + id);
                         textNode = document.createTextNode(String.fromCharCode(0xE023));
                    else if className is "inpredictable"
                         symbol.setAttributeNS(null, "class", "event eventText " + className + " id" + id);
                         textNode = document.createTextNode(String.fromCharCode(0xE162));

                    symbol.appendChild(textNode);
                    document.getElementById("timeline").appendChild(symbol);

               drawToggleLabel = (id, x, y, className) ->
                    circle = document.createElementNS(svgNS, "circle");
                    circle.setAttributeNS(null, "cx", x);
                    circle.setAttributeNS(null, "cy", y);
                    circle.setAttributeNS(null, "r",  4);
                    circle.setAttributeNS(null, "id", "id" + id);
                    circle.setAttributeNS(null, "class", "event labelToggle " + className + " circle" + id);
                    circle.setAttributeNS(null, "onclick", "for (let el of document.querySelectorAll('.id" + id + "')) el.style.visibility = (el.style.visibility === 'hidden') ? 'visible' : 'hidden';
                                                            for (let el of document.querySelectorAll('.circle" + id + "')) el.style.fill = (el.style.fill === 'transparent') ? '' : 'transparent';");
                    document.getElementById("timeline").appendChild(circle);

               drawEventGuideline = (id, numericDate, date, bars, className, eventName, y1, y2, type) ->
                    #calculate containing bar
                    index = Math.floor((numericDate - $scope.data.data.values[0][0]) / 0.25)
                    x = margin.left
                    x += (bars[index].transform.animVal.getItem(0).matrix.e)
                    x += (bars[index].firstChild.width.animVal.value * (((numericDate - $scope.data.data.values[0][0])/0.25)%1))
                    drawLine(id, x, y1, y2, className)
                    drawToggleLabel id, x, y1 - margin.top + 60, className
                    drawSymbol id, x, y1 - margin.top + 12, className
                    drawText(id, x, y1 - margin.top + 24, eventName, className)
                    drawText(id, x, y1 - margin.top + 36,  date.getDate() + '.' + (date.getMonth() + 1), className)
                    drawSymbol id, x, y1 - margin.top + 48, className, type

               drawEvents = (events) ->
                    groupOfBars = d3.select('.timeline svg').selectAll('.nv-bar')
                    if !groupOfBars or groupOfBars.length is 0 or groupOfBars[0].length is 0
                         return
                    y1 = margin.top
                    y2 = margin.top + groupOfBars[0][0].transform.animVal.getItem(0).matrix.f + groupOfBars[0][0].firstChild.height.animVal.value

                    for event in events
                         className = "predictable"
                         if !event.predictable
                              className = "inpredictable"

                         if !event.numericEndDate
                              drawEventGuideline event._id, event.numericStartDate, new Date(event.startDate), groupOfBars[0], className, event.name, y1, y2, "standard"
                         else
                              drawEventGuideline event._id, event.numericStartDate, new Date(event.startDate), groupOfBars[0], className, event.name, y1, y2, "start"
                              drawEventGuideline event._id, event.numericEndDate, new Date(event.endDate), groupOfBars[0], className, event.name, y1, y2, "end"


               nv.addGraph (->
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
                         events = []
                         for event in $scope.events
                              if event.selected
                                   events.push event

                         drawEvents(events)
                    chart
               ), ->
                    if $scope.barClick
                         d3.selectAll(".discreteBar").on 'click' , (src) ->
                              d3.selectAll(".nvtooltip").style("opacity", 0)
                              $scope.barClick() src

          $scope.$watch 'data', updateDiagram, true
          $scope.$watch 'events', updateDiagram, true
          $scope.$on 'updateEvents', updateDiagram
          $scope.$on "updateTimeline", updateDiagram