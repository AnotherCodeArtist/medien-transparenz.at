'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaTimeline', ($rootScope) ->
     restrict: 'EA'
     scope:
          data: '='
          getCurrentLanguage: '&'
     link: ($scope,element,attrs) ->
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

               nv.addGraph () ->
                    chart = nv.models.discreteBarChart()
                    .x((d) ->
                         d.label)
                    .y((d) ->
                         d.value)
                    .staggerLabels(true)
                    .margin({top: 30, right: 100, bottom: 75, left: 100})

                    chart.yAxis.tickFormat (d) -> d.toLocaleString $scope.getCurrentLanguage(), {style:"currency",currency:"EUR"}

                    d3.select('.timeline svg')
                    .datum(data)
                    .call(chart);

                    nv.utils.windowResize(chart.update);

                    chart
          $scope.$watch 'data', updateDiagram, true