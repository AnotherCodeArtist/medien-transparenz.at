'use strict'


class TPAService
    constructor: (@$http) ->

    search: (query) ->
        @$http.get 'api/transparency/search', params: query

    top: (params)->
        @$http.get 'api/transparency/top', params: params

    flows: (params) ->
        @$http.get 'api/transparency/flows', params: params

    flowdetail: (params) ->
        @$http.get 'api/transparency/flowdetail', params: params

    annualcomparison: (params) ->
        @$http.get 'api/transparency/annualcomparison', params: params

    list: (params) ->
        @$http.get 'api/transparency/list', params: params

    count: (params) ->
        @$http.get 'api/transparency/count', params: params

    overview: ->
        @$http.get 'api/transparency/overview'

    saveState:  (itemId, fieldsToStore,$scope)->
        state = fieldsToStore.reduce ((s,f) -> s[f] = $scope[f];s),{}
        sessionStorage.setItem itemId, JSON.stringify state

    restoreState:  (itemId, fieldsToStore, $scope) ->
        savedState = sessionStorage.getItem itemId
        if savedState
            fieldsToStore.reduce ((s,f) ->
                if $scope[f] isnt null and typeof $scope[f] is 'object'
                    angular.merge $scope[f],s[f]
                else
                    $scope[f] = s[f]
                s) , JSON.parse savedState

    years: ->
        @$http.get 'api/transparency/years'

    periods: ->
        @$http.get 'api/transparency/periods'

    decodeType: (type) -> switch type
        when 2 then "Payments according to §2 MedKF-TG (Media Cooperations)"
        when 4 then "Payments according to §4 MedKF-TG (Funding)"
        when 31 then "Payments according to §31 ORF-G (Charges)"


app = angular.module 'mean.transparency'
app.service 'TPAService', ["$http", TPAService]