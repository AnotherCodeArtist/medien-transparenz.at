'use strict'

app = angular.module 'mean.transparency'

app.controller 'LanguageCtrl',['$scope','gettextCatalog',($scope,gettextCatalog) ->
    $scope.lang = 'de'
    $scope.languages = ['de','en']
    change = (oldValue,newValue) -> gettextCatalog.setCurrentLanguage $scope.lang
    $scope.$watch 'lang',change
]