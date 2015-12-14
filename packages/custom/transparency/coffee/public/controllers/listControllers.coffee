'use strict'

app = angular.module 'mean.transparency'

app.controller 'ListOrgCtrl',['$scope','TPAService','$q','$interval','$state','$stateParams','$timeout','gettextCatalog'
($scope,TPAService,$q,$interval,$state,$stateParams,$timeout,gettextCatalog) ->
    $scope.title=gettextCatalog.getString "List of Organisations"
    $scope.orgType = 'org'
    fieldsToRestore = ['page','size']
    stateId = "listOrg"
    $scope.page = 1
    $scope.size = 50
    TPAService.restoreState stateId, fieldsToRestore, $scope
    page = $scope.page
    $timeout (-> $scope.page=page),100
    $scope.count = 0

    $scope.sizes = [10,20,50,100]
    orgType = "org"
    TPAService.count
        orgType: $scope.orgType
    .then (res) ->
        $scope.count = res.data
    .catch (err) -> $scope.error = "Could not load Organizations: #{err.data}"
    update = ->
        TPAService.list
            page: $scope.page - 1
            size: $scope.size
            orgType: $scope.orgType
        .then (res) ->
            $scope.items = res.data[$scope.orgType]
        .catch (err) -> $scope.error = "Could not load Organizations: #{err.data}"
    update()
    changeListener = (newValue,oldValue)->
        if newValue isnt oldValue
            TPAService.saveState stateId,fieldsToRestore, $scope
            update()

    $scope.$watch 'page', changeListener
    $scope.$watch 'size', changeListener

    translate = ->
        $scope.title=gettextCatalog.getString "List of Organisations"

    $scope.$on 'gettextLanguageChanged', translate
]

app.controller 'ListMediaCtrl',['$scope','TPAService','$q','$interval','$state','$stateParams','$timeout','gettextCatalog',
    ($scope,TPAService,$q,$interval,$state,$stateParams,$timeout,gettextCatalog) ->
        $scope.title=gettextCatalog.getString "List of Media Companies"
        $scope.orgType = 'org'
        fieldsToRestore = ['page','size']
        stateId = "listMedia"
        $scope.page = 1
        $scope.size = 50
        TPAService.restoreState stateId, fieldsToRestore, $scope
        page = $scope.page
        $timeout (-> $scope.page=page),100
        $scope.count = 0

        $scope.sizes = [10,20,50,100]
        $scope.orgType = "media"
        TPAService.count
            orgType: $scope.orgType
        .then (res) ->
            $scope.count = res.data
        .catch (err) -> $scope.error = "Could not load Media: #{err.data}"
        update = ->
            TPAService.list
                page: $scope.page - 1
                size: $scope.size
                orgType: $scope.orgType
            .then (res) ->
                $scope.items = res.data[$scope.orgType]
            .catch (err) -> $scope.error = "Could not load Media: #{err.data}"
        update()
        changeListener = (newValue,oldValue)->
            if newValue isnt oldValue
                TPAService.saveState stateId,fieldsToRestore, $scope
                update()

        $scope.$watch 'page', changeListener
        $scope.$watch 'size', changeListener

        translate = ->
            $scope.title=gettextCatalog.getString "List of Media Companies"

        $scope.$on 'gettextLanguageChanged', translate
]