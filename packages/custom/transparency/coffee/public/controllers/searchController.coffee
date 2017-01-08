'use strict'

app = angular.module 'mean.transparency'

app.controller 'SearchCtrl',['$scope','TPAService','$q','$interval','$state','$stateParams',($scope,TPAService,$q,$interval,$state,$stateParams) ->
    fieldsToStore = ['name','result','orgCollapse','mediaCollapse']
    itemId = 'searchState'
    $scope.name = ''
    $scope.orgCollapse = true
    $scope.mediaCollapse = true
    $scope.periods = []
    $scope.globalSearch = false;
    $scope.firstInYear = (year) -> $scope.periods.filter((p) -> p.year == year).pop().period.toString()
    $scope.lastInYear = (year) -> $scope.periods.filter((p) -> p.year == year)[0].period.toString()
    TPAService.periods().then (res) ->
        $scope.periods = res.data
        if not $scope.globalSearch
            TPAService.restoreState itemId, fieldsToStore, $scope
    $scope.search = ->
        if $scope.name.length > 1
            TPAService.search(name: $scope.name)
            .then (res) ->
                $scope.result = res.data
            .catch (err) ->
                $scope.error = err
    store = (o,n) ->
        TPAService.saveState itemId, fieldsToStore, $scope if o isnt n

    $scope.onSearchFormSubmit = ->
        $scope.globalSearch = true;
        $state.go 'search'
        store(0,1);

    $scope.$watch 'result',store
    $scope.$watch 'orgCollapse',store
    $scope.$watch 'mediaCollapse',store
    window.scrollTo 0, 0
]