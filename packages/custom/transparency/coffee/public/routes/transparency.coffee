'use strict';
angular.module 'mean.transparency'
.config ($stateProvider) ->

    checkLoggedIn = ($q, $timeout, $http, $location) ->
        deferred = $q.defer()
        $http.get('/api/loggedin').success(
            (user) ->
                if user isnt '0'
                    $timeout deferred.resolve
                else
                    $timeout deferred.reject
                    $location.url('login')
        )
        deferred.promise

    $stateProvider.state 'transparency example page',
        url: '/transparency/example'
        templateUrl: 'transparency/views/index.html'
    $stateProvider.state 'overview',
        url: '/overview?name&orgType&years&quarters&pTypes'
        templateUrl: 'transparency/views/overview.html'
    $stateProvider.state 'add_report',
        url: '/transparency/add'
        templateUrl: 'transparency/views/upload.html'
        resolve:
            loggedin: checkLoggedIn
    $stateProvider.state 'events',
        url: '/transparency/events'
        templateUrl: 'transparency/views/events.html'
        resolve:
            loggedin: checkLoggedIn
    #State for the upload of the organisation-address-data
    $stateProvider.state 'add_organisation',
        url: '/transparency/addOrganisation'
        templateUrl: 'transparency/views/uploadOrganisation.html'
        resolve:
            loggedin: checkLoggedIn
    #State for the upload of the zipCode
    $stateProvider.state 'add_zipCode',
        url: '/transparency/addZipCode'
        templateUrl: 'transparency/views/uploadZipCode.html'
        resolve:
            loggedin: checkLoggedIn
    $stateProvider.state 'top',
        url: "/top"
        templateUrl: 'transparency/views/top.html'
    $stateProvider.state 'showflow',
        url: "/showflow?name&orgType&from&to&pTypes&fedState"
        templateUrl: 'transparency/views/flow.html'
        #controller: 'FlowCtrl'
    $stateProvider.state 'impress',
        url: "/impress"
        templateUrl: 'transparency/views/impress.html'
    $stateProvider.state 'search',
        url: '/search'
        templateUrl: 'transparency/views/search.html'
        controller: 'SearchCtrl'
    $stateProvider.state 'listOrgs',
        url: '/organisations?orgType&page&size'
        templateUrl: 'transparency/views/list.html'
        controller: 'ListOrgCtrl'
    $stateProvider.state 'listMedia',
        url: '/medialist?orgType&page&size'
        templateUrl: 'transparency/views/list.html'
        controller: 'ListMediaCtrl'
    $stateProvider.state 'map',
        url: '/map'
        templateUrl: 'transparency/views/map.html'
        controller: 'MapCtrl'
