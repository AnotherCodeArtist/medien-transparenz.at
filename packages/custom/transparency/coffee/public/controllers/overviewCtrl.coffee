'use strict'
app = angular.module 'mean.transparency'

app.controller 'OverviewCtrl', ($scope,TPAService,$state,gettextCatalog) ->
  transferTypes = ['2','4','31']
  $scope.overview = []
  $scope.types = transferTypes
  $scope.years = -> (q for q in [0 .. $scope.overview.length-1])
  window.scrollTo 0,0

  emptyQuarters = -> [["Q1",0],["Q2",0],["Q3",0],["Q4",0]]

  initYear = (year,type) ->
    newSeries =
      key: year.year
      values: emptyQuarters()
    newSeries.values[entry.quarter-1][1] = entry.total for entry in year.quarters when entry.transferType is parseInt type
    $scope.data[type].push newSeries

  initData = ->
    $scope.data = {}
    for type in transferTypes
      $scope.data[type] = []
      initYear(entry,type) for entry in $scope.overview


  $scope.typeTexts={}
  ($scope.typeTexts[type] = gettextCatalog.getString(TPAService.decodeType(type))) for type in [2,4,31]

  TPAService.overview().then(
    (result) ->
      $scope.overview = result.data
      initData()
    (error) -> $scope.error = "#{error.status} - #{error.statusText} (#{error.data})"
  )

  $scope.config =
    labels: false,
    legend:
      display: true,
      position: "right"
    innerRadius: 0,
    lineLegend: "lineEnd"
