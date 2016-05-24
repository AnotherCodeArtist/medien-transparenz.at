'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaAnnualcomparison', ($rootScope) ->
     restrict: 'EA'
     scope:
          data: '='
     link: ($scope,element,attrs) ->
          updateDiagram = (oldValue, newValue) ->
               if $scope.data
                    tickvalues = [
                         0, 0.25, 0.5, 0.75
                    ]
                    nv.addGraph () ->
                         chart = nv.models.lineChart()
                         .margin({top: 30, right: 60, bottom: 50, left: 150})
                         .useInteractiveGuideline(true)
                         chart.xAxis
                         .axisLabel('Quartal')
                         .tickValues(tickvalues)
                         .tickFormat (d) ->
                              "Q" + (d*4+1)

                         chart.yAxis
                         .axisLabel('€')
                         .tickFormat(d3.format('.02f'))

                         d3.select('.annualGraph svg')
                         .datum(data())
                         .transition().duration(500)
                         .call(chart)

                         nv.utils.windowResize(chart.update);

                         chart


          data = () ->
               $scope.data

          $scope.$watch 'data', updateDiagram, true