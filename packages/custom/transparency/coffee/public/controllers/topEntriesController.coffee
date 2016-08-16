'use strict'
app = angular.module 'mean.transparency'

app.controller 'TopEntriesCtrl', ['$scope', 'TPAService', '$q', '$state','gettextCatalog','$rootScope',
($scope, TPAService, $q, $state, gettextCatalog, $rootScope) ->
    params = {}
    stateName = "topState"
    fieldsToStore = ['slider','periods','orgTypes','typesText','rank','orgType', 'selectedFederalState', 'includeGroupings']
    $scope.periods = []
    $scope.slider =
        from: 0
        to: 0
        options:
            step:5
            floor:0
            onEnd: -> change(1,2)
            translate: (value) -> $scope.periods.map((p) -> "#{p.year}/Q#{p.quarter}")[value/5]
    $scope.showSettings = true
    $scope.ranks = [3, 5, 10, 15, 20]
    $scope.rank = 10
    $scope.pieData = []
    window.scrollTo 0, 0

    # register watches to update chart when changes occur
    registerWatches = ->
        $scope.$watch('typesText', change, true)
        $scope.$watch('orgType', change, true)
        $scope.$watch('rank', change, true)
        $scope.$watch('selectedFederalState', change, true)
        $scope.$watch('includeGroupings', change, true)


    #construct the query parameters
    parameters = ->
        params = {}
        params.from = $scope.periods[$scope.slider.from/5].period
        params.to =$scope.periods[$scope.slider.to/5].period
        params.federalState = $scope.selectedFederalState.iso if $scope.selectedFederalState
        params.groupings = $scope.includeGroupings if $scope.includeGroupings
        types = (v.type for v in $scope.typesText when v.checked)
        (params.pType = types) if types.length > 0
        params.x = $scope.rank
        params.orgType = $scope.orgType
        params

    $scope.total = -> if $scope.top then $scope.top.all.toLocaleString() else "0"

    buildPieModel = ->
        $scope.pieData = []
        $scope.pieData.push {key: entry.organisation, y: entry.total, isGrouping: entry.isGrouping} for entry in $scope.top.top
        topSum = $scope.top.top.reduce(
            (sum, entry) ->
                sum + entry.total
            0
        )
        $scope.pieData.push {key: gettextCatalog.getString("Others"), y: $scope.top.all - topSum}

    $scope.toolTipContentFunction = (e) ->
        link = if e.index < $scope.rank then "<br/>"+gettextCatalog.getString("Click for Details") else ""
        numberOptions = {style:'currency',currency:'EUR'}
        """<div class='chartToolTip'>
                <h3>#{e.data.key}</h3>
                <p>#{e.data.y.toLocaleString(gettextCatalog.getCurrentLanguage(),numberOptions)} (#{(e.data.y/$scope.top.all *100).toFixed(2)}%)#{link}</p>
           </div>"""
    #fetch data from server and update the chart
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
        #Federal states selection
        $scope.federalStates  =  (name: gettextCatalog.getString(state.value), value: state.value, iso: state.iso for state in TPAService.staticData 'federal')
        #remove Austria
        if $scope.federalStates.length is 10
            $scope.federalStates.pop()
        savedState = sessionStorage.getItem 'topState'
        if savedState
            TPAService.restoreState stateName, fieldsToStore, $scope
            update()
            registerWatches()
        else
            pY = TPAService.years()
            pY.then (res) ->
                $scope.years = (year: year, checked: false for year in res.data.years)
                $scope.years[0].checked = true;
            pP = TPAService.periods()
            pP.then (res) ->
                $scope.periods = res.data.reverse()
                $scope.slider.options.ceil = ($scope.periods.length - 1)*5
                $scope.slider.from = $scope.slider.options.ceil
                $scope.slider.to = $scope.slider.options.ceil
            types = [2, 4, 31]
            $scope.typesText = (type: type, text: gettextCatalog.getString( TPAService.decodeType(type) ), checked: false for type in types)
            $scope.typesText[0].checked = true
            #Variables for the selection of federalState
            $scope.selectedFederalState = {}
            $scope.orgType = $scope.orgTypes[0].value
            $scope.includeGroupings = false
            $q.all([pY, pP]).then (res) ->
                update()
                registerWatches()

    translate = ->
        $scope.orgTypes[0].name = gettextCatalog.getString('Spender')
        $scope.orgTypes[1].name = gettextCatalog.getString('Recipient')
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type
        $scope.federalStates.forEach (state) -> state.name = gettextCatalog.getString state.value

    $scope.$on 'gettextLanguageChanged', translate

    initState()

    $scope.x = (d) ->
        d.key
    $scope.y = (d) ->
        d.y

    #prevents clicks on "Others" to trigger a navigation        
    $scope.preventClickForOthers = (d) -> d.data.key in ["Others","Andere"]

    $rootScope.$on '$stateChangeStart', (event,toState) ->
        if toState.name isnt "top"
            TPAService.saveState stateName,fieldsToStore, $scope

    #navigate to some other page
    $scope.go = (d) ->
        window.scrollTo 0, 0
        $state.go 'showflow',
            {
                name: d.data.key if not d.data.isGrouping
                orgType: $scope.orgType
                grouping: d.data.key if d.data.isGrouping
                from: $scope.periods[$scope.slider.from/5].period
                to: $scope.periods[$scope.slider.to/5].period
                fedState: $scope.selectedFederalState.iso if $scope.selectedFederalState
                pTypes: $scope.typesText.filter((t) -> t.checked).map (t) -> t.type
            },
            location: true
            inherit: false
            reload: true
]