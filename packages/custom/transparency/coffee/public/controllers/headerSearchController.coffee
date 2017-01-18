'use strict'

app = angular.module 'mean.transparency'

app.controller 'HeaderSearchCtrl',['$scope','$state',($scope,$state) ->
    $scope.searchterm = ''

    $scope.onSearchFormSubmit = ->
        $state.go('search', {searchterm: $scope.searchterm})

]