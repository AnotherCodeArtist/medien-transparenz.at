'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaLinegraph', ($rootScope) ->
     restrict: 'EA'
     scope:
          data: '='
     link: ($scope,element,attrs) ->
          updateDiagram = (oldValue, newValue) ->
               data = () ->
                    result = [
                         {
                              key: "Difference",
                              values:
                                   [
                                   ]
                         }
                    ]
                    if $scope.data and $scope.data.data and $scope.data.data.values
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

                              result[0].values.push {
                                   label: label,
                                   value: transfer[1]
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
                    d3.select('.lineGraph svg')
                    .datum(data)
                    .call(chart);

                    nv.utils.windowResize(chart.update);

                    chart
          $scope.$watch 'data', updateDiagram, true