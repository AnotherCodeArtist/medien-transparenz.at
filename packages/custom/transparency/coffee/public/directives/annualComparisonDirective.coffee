'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaAnnualcomparison', ($rootScope) ->
     restrict: 'EA'
     scope:
          data: '='
     link: ($scope,element,attrs) ->
          updateDiagram = (oldValue, newValue) ->
               data = () ->
                    if $scope.data
                         result = [
                              {
                                   key: "Difference",
                                   values:
                                        [
                                        ]
                              }
                         ]
                         for i in [1...$scope.data.length]
                              for quarter in [1...5]
                                   result[0].values.push {
                                        label: $scope.data[i].key + "/Q" + quarter
                                        value: $scope.data[i].values[quarter-1].y - $scope.data[i-1].values[quarter-1].y
                                   }
                         result

               nv.addGraph () ->
                    chart = nv.models.discreteBarChart()
                    .x((d) ->
                         d.label)
                    .y((d) ->
                         d.value)
                    .staggerLabels(true)
                    .color((d) ->
                         "steelblue"
                    )
                    .margin({top: 30, right: 100, bottom: 75, left: 100})
                    d3.select('.annualGraph svg')
                    .datum(data)
                    .call(chart);

                    nv.utils.windowResize(chart.update);

                    chart

          $scope.$watch 'data', updateDiagram, true