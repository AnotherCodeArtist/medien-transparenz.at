'use strict'

app = angular.module 'mean.transparency'

app.controller 'LanguageCtrl',['$scope','gettextCatalog','$rootScope',($scope,gettextCatalog,$rootScope) ->
    $scope.lang = 'de'
    $rootScope.language= $scope.lang
    $scope.languages = ['de','en']
    $scope.setLanguage = (lang) -> $scope.lang = lang
    change = (oldValue,newValue) ->
        gettextCatalog.setCurrentLanguage $scope.lang
        $rootScope.language= $scope.lang
    $scope.$watch 'lang',change
]