'use strict'
app = angular.module 'mean.transparency'

app.controller 'OverviewCtrl', ($scope, TPAService, $state, gettextCatalog) ->
    transferTypes = ['2', '4', '31']
    $scope.overview = []
    $scope.types = transferTypes
    $scope.years = -> (q for q in [0 .. $scope.overview.length - 1])
    window.scrollTo 0, 0

    emptyQuarters = -> [["Q1", 0], ["Q2", 0], ["Q3", 0], ["Q4", 0]]

    $scope.options =
        chart:
            type: 'multiBarChart'
            height: 450
            margin:
                top: 20
                right: 20
                bottom: 45
                left: 45
            clipEdge: true
#staggerLabels: true,
            duration: 500
            stacked: false
            showYAxis: false
            xAxis:
                axisLabel: 'Quarters'
                showMaxMin: false
                #tickFormat: (d) -> d3.format(',f')(d)
            yAxis:
                axisLabel: 'Amount [1000 €]'
                axisLabelDistance: -20
                tickFormat: (d) -> d.toLocaleString gettextCatalog.getCurrentLanguage(), {style:"currency",currency:"EUR"}


    prepareDateRow = (data) ->
            key: data.key
            values: data.values.map (v) ->
                x: v[0]
                y: v[1]
                s: v[1].toLocaleString gettextCatalog.getCurrentLanguage(), {style:"currency",currency:"EUR"}

    initYear = (year, type) ->
        newSeries =
            key: year.year
            values: emptyQuarters()
        newSeries.values[entry.quarter - 1][1] = entry.total for entry in year.quarters when entry.transferType is parseInt type
        $scope.data[type].push prepareDateRow newSeries
    initData = ->
        $scope.data = {}
        $scope.yearTotals = {}
        for type in transferTypes
            $scope.data[type] = []
            initYear(entry, type) for entry in $scope.overview


    $scope.typeTexts = {}
    ($scope.typeTexts[type] = gettextCatalog.getString(TPAService.decodeType(type))) for type in [2, 4, 31]

    TPAService.overview().then(
        (result) ->
            $scope.overview = result.data
            initData()
        (error) -> $scope.error = "#{error.status} - #{error.statusText} (#{error.data})"
    )

    $scope.totalPerYearAndType = (series,year) ->
        series.filter((e)->e.key is year)[0].values.map((e)->e.y).reduce(((p,c)->p+c),0)
        .toLocaleString gettextCatalog.getCurrentLanguage(), {style:"currency",currency:"EUR"}
    
    $scope.config =
        labels: false,
        legend:
            display: true,
            position: "right"
        innerRadius: 0,
        lineLegend: "lineEnd"
