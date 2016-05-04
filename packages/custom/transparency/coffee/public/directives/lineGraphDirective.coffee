'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaLinegraph', ($rootScope) ->
    restrict: 'EA'
    scope:
        data: '='
    link: ($scope,element,attrs) ->
        updateDiagram = (oldValue, newValue) ->
            if ($scope.data and $scope.data.data and $scope.data.data.length is 3)
                nv.addGraph () ->
                    width = 1000
                    height = 300
                    chart = nv.models.stackedAreaChart()
                    .margin({top: 30, right: 60, bottom: 50, left: 150})
                    .width(width).height(height)
                    .x (d) ->
                        d[0]
                    .y (d) ->
                        d[1]
                    .clipEdge(true)
                    .useInteractiveGuideline(true)
                    chart.xAxis.axisLabel('Quartal').tickValues($scope.data.tickvalues).tickFormat (d) ->
                        str = ""+d
                        result = (""+d).substring 0, 4
                        if (str.indexOf '.25') != -1
                            result += "/Q2"
                        if (str.indexOf '.5') != -1
                            result += "/Q3"
                        if (str.indexOf '.75') != -1
                            result += "/Q4"
                        if (str.indexOf '.') is -1
                            result += "/Q1"
                        result
                    chart.yAxis.axisLabel('€').tickFormat(d3.format('.02f'))
                    d3.select('.lineGraph svg').datum(data).transition().duration(500).call(chart).style({ 'width': width, 'height': height })
                    nv.utils.windowResize(chart.update)
                    chart

        data = () ->
            $scope.data.data

        $scope.$watch 'data', updateDiagram, true