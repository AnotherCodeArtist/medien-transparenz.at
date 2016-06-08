'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaLinegraph', ($rootScope) ->
    restrict: 'EA'
    scope:
        data: '='
    link: ($scope,element,attrs) ->
        updateDiagram = (oldValue, newValue) ->
            if ($scope.data and $scope.data.data and $scope.data.data.values)
                ###
                nv.addGraph () ->
                    chart = nv.models.stackedAreaChart()
                    .margin({top: 30, right: 60, bottom: 50, left: 150})
                    .x (d) ->
                        d[0]
                    .y (d) ->
                        d[1]
                    .clipEdge(true)
                    .useInteractiveGuideline(true)

                    $scope.data.tickvalues.push 2014.37
                    chart.xAxis.axisLabel('Quartal').tickValues($scope.data.tickvalues).tickFormat (d) ->
                        result = ""
                        if (events[d])
                            result = events[d][0]

                        else
                            str = ""+d
                            result += (""+d).substring 0, 4
                            if (str.indexOf '.25') != -1
                                result = "Q2"
                            if (str.indexOf '.5') != -1
                                result = "Q3"
                            if (str.indexOf '.75') != -1
                                result = "Q4"
                            if (str.indexOf '.') is -1
                                result += "/Q1"
                            result
                    chart.yAxis.axisLabel('€').tickFormat(d3.format('.02f'))
                    d3.select('.lineGraph svg').datum(data).transition().duration(500).call(chart)
                    d3.select('.lineGraph svg').selectAll('g.tick').filter((d) ->
                        d%0.25 != 0)
                    .select('line').style('stroke','red')
                    d3.select('.lineGraph svg').selectAll(".tick > text")
                    .style("font-size", 10);
                    nv.utils.windowResize(chart.update)
                    chart
                ###

                data = [
                    {
                        "key" : "Quantity",
                        "bar": true,
                        "values" : $scope.data.data.values
                    }
                ]

                nv.addGraph () ->
                    events = []
                    events[2014.37] = ["Wahl"]
                    chart = nv.models.linePlusBarChart()
                    .focusEnable(false)
                    .margin({top: 30, right: 100, bottom: 50, left: 100})
                    .x((d,i) ->
                         i)
                    .y((d) ->
                        d[1])
                    .color(d3.scale.category10().range())

                    chart.xAxis
                    .tickValues [0...16]
                    .tickFormat (d) ->
                        dx = $scope.data.data.values[d]
                        result = ""
                        if (events[dx])
                            result = events[dx][0]
                        else
                            str = ""+dx
                            result += (""+dx).substring 0, 4
                            if (str.indexOf '.25') != -1
                                result = "Q2"
                            if (str.indexOf '.5') != -1
                                result = "Q3"
                            if (str.indexOf '.75') != -1
                                result = "Q4"
                            if (str.indexOf '.') is -1
                                result += "/Q1"
                            result

                    chart.y1Axis
                    .tickFormat(d3.format(',f'))

                    chart.y2Axis
                    .tickFormat((d) ->
                         '$' + d3.format(',f')(d))

                    chart.bars.forceY([0])

                    d3.select('.lineGraph svg')
                    .datum(data)
                    .transition().duration(500)
                    .call(chart)

                    #nv.utils.windowResize(chart.update)
                    console.log chart
                    chart


        $scope.$watch 'data', updateDiagram, true
