'use strict'
app = angular.module 'mean.transparency'

app.directive 'tpaQuartercomparison', ($rootScope) ->
     restrict: 'EA'
     scope:
          data: '='
          getCurrentLanguage: '&'
     link: ($scope,element,attrs) ->
          updateDiagram = (oldValue, newValue) ->
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

               nv.addGraph () ->
                    chart = nv.models.discreteBarChart()
                    .x((d) ->
                         d.label)
                    .y((d) ->
                         d.value)
                    .staggerLabels(true)
                    .margin({top: 30, right: 100, bottom: 75, left: 100})

                    chart.yAxis.tickFormat (d) -> d.toLocaleString $scope.getCurrentLanguage(), {style:"currency",currency:"EUR"}
                    
                    d3.select('.quartercomparison svg')
                    .datum(data)
                    .call(chart);

                    nv.utils.windowResize(chart.update);

                    chart

          $scope.$watch 'data', updateDiagram, true