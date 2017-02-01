'use strict'
app = angular.module 'mean.transparency'

app.directive 'uniqueGroupNameIn', ($rootScope, $window) ->
    require: 'ngModel'
    scope: {
        uniqueGroupNameIn: '&'
    }
    link: (scope, element, attr, mCtrl) ->
        myValidation = (value) ->
            if value.toLowerCase() in scope.uniqueGroupNameIn().map((v)->v.name.toLowerCase())
                mCtrl.$setValidity('uniqueGroupName', false)
            else
                mCtrl.$setValidity('uniqueGroupName', true)
            value
        mCtrl.$parsers.push(myValidation);