'use strict'


getNumericDate = (date) ->
    start = new Date(date.getFullYear(), 0, 0);
    diff = date - start;
    oneDay = 1000 * 60 * 60 * 24;
    day = Math.floor(diff / oneDay);
    date.getFullYear() + day/365

class TPAService
    constructor: (@$http) ->

    search: (query) ->
        @$http.get 'api/transparency/search', params: query

    top: (params)->
        @$http.get 'api/transparency/top', params: params

    flows: (params) ->
        @$http.get 'api/transparency/flows', params: params

    list: (params) ->
        @$http.get 'api/transparency/list', params: params

    count: (params) ->
        @$http.get 'api/transparency/count', params: params

    overview: ->
        @$http.get 'api/transparency/overview'

    getEvents: (params) ->
        @$http.get 'api/transparency/events', params: params

    getEventTags: ->
        @$http.get 'api/transparency/events/tags'

    createEvent: (params) ->
        params.numericStartDate = getNumericDate params.startDate
        if params.endDate
            params.numericEndDate = getNumericDate params.endDate
        @$http.post 'api/transparency/events', params

    updateEvent: (params) ->
        params.numericStartDate = getNumericDate params.startDate
        if params.endDate
            params.numericEndDate = getNumericDate params.endDate
        @$http.put 'api/transparency/events', params

    removeEvent: (params) ->
        console.log params
        @$http.delete 'api/transparency/events', params: params

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

    federalstates: (params) ->
        @$http.get 'api/transparency/federalstates', params: params

    decodeType: (type) -> switch type
        when 2 then "Payments according to §2 MedKF-TG (Media Cooperations)"
        when 4 then "Payments according to §4 MedKF-TG (Funding)"
        when 31 then "Payments according to §31 ORF-G (Charges)"

    #Function to define static data, e.g. federal states
    staticData: (type, data)->
        federalStates =
             [
                 {name: 'Burgenland',value: 'Burgenland', iso: 'AT-1'}
                 {name: 'Carinthia', value: 'Carinthia', iso: 'AT-2' }
                 {name: 'Lower Austria', value: 'Lower Austria', iso: 'AT-3' }
                 {name: 'Salzburg', value: 'Salzburg', iso: 'AT-5' }
                 {name: 'Styria', value: 'Styria', iso: 'AT-6' }
                 {name: 'Tyrol',  value: 'Tyrol', iso: 'AT-7' }
                 {name: 'Upper Austria',  value: 'Upper Austria', iso: 'AT-4' }
                 {name: 'Vienna',  value: 'Vienna', iso: 'AT-9' }
                 {name: 'Vorarlberg',  value: 'Vorarlberg', iso: 'AT-8' }
             ]
        switch type
            when 'federal'
                federalStates
            when 'findOneFederalState'
                result = null
                for federalState in federalStates
                    if federalState.iso is data
                        result = federalState
                result


app = angular.module 'mean.transparency'
app.service 'TPAService', ["$http", TPAService]