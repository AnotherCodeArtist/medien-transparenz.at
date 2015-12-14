'use strict'
app = angular.module 'mean.transparency'

app.controller 'TopEntriesCtrl', ['$scope', 'TPAService', '$q', '$state','gettextCatalog',
($scope, TPAService, $q, $state, gettextCatalog) ->
    params =
        quarters: [2]
        years: [2013, 2014]
    fieldsToStore = ['years','periods','quarters','orgTypes','typesText','rank','orgType']
    $scope.years = []
    $scope.showSettings = true
    $scope.ranks = [3, 5, 10, 15, 20]
    $scope.rank = 10
    $scope.pieData = []
    window.scrollTo 0, 0

    registerWatches = ->
        $scope.$watch('years', change, true)
        $scope.$watch('quarters', change, true)
        $scope.$watch('typesText', change, true)
        $scope.$watch('orgType', change, true)
        $scope.$watch('rank', change, true)


    parameters = ->
        params = {}
        years = (v.year for v in $scope.years when v.checked)
        quarters = (v.quarter for v in $scope.quarters when v.checked)
        types = (v.type for v in $scope.typesText when v.checked)
        (params.years = years) if years.length > 0
        (params.quarters = quarters) if quarters.length > 0
        (params.pType = types) if types.length > 0
        params.x = $scope.rank
        params.orgType = $scope.orgType
        params

    saveState = ->
        state = fieldsToStore.reduce ((s,f) -> s[f] = $scope[f];s),{}
        sessionStorage.setItem 'topState', JSON.stringify state



    buildPieModel = ->
        $scope.pieData = []
        $scope.pieData.push {key: entry.organisation, y: entry.total} for entry in $scope.top.top
        topSum = $scope.top.top.reduce(
            (sum, entry) ->
                sum + entry.total
            0
        )
        $scope.pieData.push {key: "Others", y: $scope.top.all - topSum}

    $scope.toolTipContentFunction = (key, y, e, graph) ->
        link = if e.pointIndex < $scope.rank then "<br/>Click for Details" else ""
        """<div class='chartToolTip'>
                <h3>#{key}</h3>
                <p>#{y} &euro;  (#{parseFloat((y.replace(/,/g,''))/$scope.top.all *100).toFixed(2)}%)#{link}</p>
           </div>"""


    update = ->
        TPAService.top(parameters())
        .then((res) ->
            init = true
            $scope.top = res.data
            buildPieModel()
        )
    change = (oldValue, newValue) ->
        update() if (oldValue isnt newValue)

    initState = ->
        $scope.orgTypes = [
            {name: gettextCatalog.getString('Spender'), value: 'org'},
            {name: gettextCatalog.getString('Recipient'), value: 'media'}
        ]
        savedState = sessionStorage.getItem 'topState'
        if savedState
            fieldsToStore.reduce ((s,f) -> $scope[f] = s[f];s) , JSON.parse savedState
            update()
            registerWatches()
        else
            pY = TPAService.years()
            pY.then (res) ->
                $scope.years = (year: year, checked: false for year in res.data.years)
                $scope.years[0].checked = true;
            pP = TPAService.periods()
            pP.then (res) ->
                $scope.periods = res.data
                $scope.quarters[4 - $scope.periods[0].quarter].checked = true
            $scope.quarters = (quarter: quarter, checked: false for quarter in [4..1])
            types = [2, 4, 31]
            $scope.typesText = (type: type, text: gettextCatalog.getString( TPAService.decodeType(type) ), checked: false for type in types)
            $scope.typesText[0].checked = true
            $scope.orgType = $scope.orgTypes[0].value
            $q.all([pY, pP]).then (res) ->
                update()
                registerWatches()

    translate = ->
        $scope.orgTypes[0].name = gettextCatalog.getString('Spender')
        $scope.orgTypes[1].name = gettextCatalog.getString('Recipient')
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type

    $scope.$on 'gettextLanguageChanged', translate

    initState()

    $scope.x = (d) ->
        d.key
    $scope.y = (d) ->
        d.y

    $scope.go = (d) ->
        saveState()
        window.scrollTo 0, 0
        $state.go 'showflow',
            {
                name: d.data.key
                orgType: $scope.orgType
                years: $scope.years.filter((y) -> y.checked).map (y) -> y.year
                quarters: $scope.quarters.filter((q) -> q.checked).map (q) -> q.quarter
                pTypes: $scope.typesText.filter((t) -> t.checked).map (t) -> t.type
            },
            location: true
            inherit: false
            reload: true







]