'use strict'

app = angular.module 'mean.transparency'


app.controller 'ListOrgCtrl', ($scope,TPAService,$q,$interval,$state,$stateParams,$timeout,gettextCatalog,$rootScope) ->
    $scope.title=gettextCatalog.getString "List of Organisations"
    $scope.orgType = 'org'
    fieldsToRestore = ['searchResult','filterResult','items','page','size','name','periods','count']
    stateId = "listOrg"
    $scope.page = 1
    $scope.size = 50
    $scope.count = 0
    $scope.name = ''
    $scope.periods=[]
    $scope.items = []
    $scope.firstInYear = (year) -> $scope.periods.filter((p) -> p.year == year).pop().period.toString()
    $scope.lastInYear = (year) -> $scope.periods.filter((p) -> p.year == year)[0].period.toString()
    $scope.sizes = [10,20,50,100]
    $scope.federalStates  =  (name: gettextCatalog.getString(state.value), value: state.value, iso: state.iso for state in TPAService.staticData 'federal')
    #remove Austria
    if $scope.federalStates.length is 10
        $scope.federalStates.pop()

    $scope.selectedFederalState = {}
    $scope.orgType = "org"
    $scope.searchResult = []
    $scope.filterResult = []
    TPAService.restoreState stateId, fieldsToRestore, $scope
    page = $scope.page
    $timeout (-> $scope.page=page),100
    updateCount = ->
        searchObject =
            orgType: $scope.orgType
            federalState: $scope.selectedFederalState.iso if $scope.selectedFederalState
        prom = TPAService.count searchObject
        prom.then (res) ->
            $scope.count = res.data
        prom.catch (err) -> $scope.error = "Could not load Organizations: #{err.data}"
    update = ->
        if $scope.name.length > 2
            updatePage()
        else
            $scope.searchResult = []
            TPAService.list
                page: $scope.page - 1
                size: $scope.size
                orgType: $scope.orgType
                federalState: $scope.selectedFederalState.iso if $scope.selectedFederalState
            .then (res) ->
                $scope.items = res.data[$scope.orgType]
            .catch (err) -> $scope.error = "Could not load Organizations: #{err.data}"
    init = ->
        $scope.name = ''
        $scope.searchResult = []
        pP = TPAService.periods()
        pP.then (res) ->
            $scope.periods = res.data
        .catch (err) -> $scope.error = "Could not load Periods: #{err.data}"
        cP = updateCount()
        $q.all([pP,cP]).then update
    if $scope.items.length is 0
        init()
    changeListener = (newValue,oldValue)->
        if newValue isnt oldValue
            update()
    updatePage = ->
        $scope.items = $scope.filterResult[($scope.page-1)*$scope.size..($scope.page-1)*$scope.size+$scope.size]
    applyFilter = ->
        $scope.filterResult = $scope.searchResult.filter (e) -> e.name.toLowerCase().indexOf($scope.name.toLowerCase()) > -1
        $scope.count = $scope.filterResult.length
        $scope.page = 1
        updatePage()
    updateFilter = (newName,oldName)->
        return if newName is oldName
        newName = newName or ''
        if newName.length > oldName.length
            if $scope.searchResult.length is 0 and newName.length > 2
                TPAService.search( {name: $scope.name, orgType: $scope.orgType, federalState: $scope.selectedFederalState.iso if $scope.selectedFederalState})
                .then (res) ->
                    $scope.searchResult = res.data[$scope.orgType]
                    $scope.filterResult = $scope.searchResult
                    $scope.count = $scope.filterResult.length
                    updatePage()
                .catch (err) -> $scope.error = err.data
            else
                if $scope.searchResult.length > 0
                    applyFilter()
        else
            if newName.length <= 2 and oldName.length > 2
                updateCount()
                update()
            if newName.length > 2
                applyFilter()
    changeFederalState = ->
        updateCount()
        update()
        if $scope.name
            TPAService.search( {name: $scope.name, orgType: $scope.orgType, federalState: $scope.selectedFederalState.iso if $scope.selectedFederalState})
            .then (res) ->
                $scope.searchResult = res.data[$scope.orgType]
                $scope.filterResult = $scope.searchResult
                $scope.count = $scope.filterResult.length
                updatePage()
            .catch (err) -> $scope.error = err.data
    $scope.$watch 'page', changeListener
    $scope.$watch 'size', changeListener
    $scope.$watch 'selectedFederalState', changeFederalState
    $scope.$watch 'name', updateFilter
    $rootScope.$on '$stateChangeStart', ->
        TPAService.saveState stateId,fieldsToRestore, $scope

    translate = ->
        $scope.title=gettextCatalog.getString "List of Organisations"
        $scope.federalStates.forEach (state) -> state.name = gettextCatalog.getString state.value

    $scope.$on 'gettextLanguageChanged', translate



app.controller 'ListMediaCtrl', ($scope,TPAService,$q,$interval,$state,$stateParams,$timeout,gettextCatalog,$rootScope) ->
    $scope.title=gettextCatalog.getString "List of Media Companies"
    $scope.orgType = 'org'
    fieldsToRestore = ['searchResult','filterResult','items','page','size','name','periods','count']
    stateId = "listMedia"
    $scope.page = 1
    $scope.size = 50
    $scope.count = 0
    $scope.name = ''
    $scope.periods=[]
    $scope.items = []
    $scope.firstInYear = (year) -> $scope.periods.filter((p) -> p.year == year).pop().period.toString()
    $scope.lastInYear = (year) -> $scope.periods.filter((p) -> p.year == year)[0].period.toString()
    $scope.sizes = [10,20,50,100]
    $scope.orgType = "media"
    $scope.searchResult = []
    $scope.filterResult = []
    TPAService.restoreState stateId, fieldsToRestore, $scope
    page = $scope.page
    $timeout (-> $scope.page=page),100
    updateCount = ->
        prom = TPAService.count orgType: $scope.orgType
        prom.then (res) ->
            $scope.count = res.data
        prom.catch (err) -> $scope.error = "Could not load Media: #{err.data}"
    update = ->
        if $scope.name.length > 2
            updatePage()
        else
            $scope.searchResult = []
            TPAService.list
                page: $scope.page - 1
                size: $scope.size
                orgType: $scope.orgType
            .then (res) ->
                $scope.items = res.data[$scope.orgType]
            .catch (err) -> $scope.error = "Could not load Media: #{err.data}"
    init = ->
        $scope.name = ''
        $scope.searchResult = []
        pP = TPAService.periods()
        pP.then (res) ->
            $scope.periods = res.data
        .catch (err) -> $scope.error = "Could not load Periods: #{err.data}"
        cP = updateCount()
        $q.all([pP,cP]).then update
    if $scope.items.length is 0
        init()
    changeListener = (newValue,oldValue)->
        if newValue isnt oldValue
            update()
    updatePage = ->
        $scope.items = $scope.filterResult[($scope.page-1)*$scope.size..($scope.page-1)*$scope.size+$scope.size]
    applyFilter = ->
        $scope.filterResult = $scope.searchResult.filter (e) -> e.name.toLowerCase().indexOf($scope.name.toLowerCase()) > -1
        $scope.count = $scope.filterResult.length
        $scope.page = 1
        updatePage()
    updateFilter = (newName,oldName)->
        return if newName is oldName
        newName = newName or ''
        if newName.length > oldName.length
            if $scope.searchResult.length is 0 and newName.length > 2
                TPAService.search( {name: $scope.name, orgType: $scope.orgType})
                .then (res) ->
                    $scope.searchResult = res.data[$scope.orgType]
                    $scope.filterResult = $scope.searchResult
                    $scope.count = $scope.filterResult.length
                    updatePage()
                .catch (err) -> $scope.error = err.data
            else
                if $scope.searchResult.length > 0
                    applyFilter()
        else
            if newName.length <= 2 and oldName.length > 2
                updateCount()
                update()
            if newName.length > 2
                applyFilter()
    $scope.$watch 'page', changeListener
    $scope.$watch 'size', changeListener
    $scope.$watch 'name', updateFilter
    $rootScope.$on '$stateChangeStart', ->
        TPAService.saveState stateId,fieldsToRestore, $scope

    translate = ->
        $scope.title=gettextCatalog.getString "List of Media Companies"

    $scope.$on 'gettextLanguageChanged', translate
