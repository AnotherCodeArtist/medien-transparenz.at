'use strict'

app = angular.module 'mean.transparency'

app.controller 'FlowDetailCtrl',['$scope','TPAService','$q','$interval','$state','gettextCatalog', '$filter','DTOptionsBuilder'
($scope,TPAService,$q,$interval,$state,gettextCatalog, $filter,DTOptionsBuilder) ->
    $scope.mediaLabel = gettextCatalog.getString('Media')
    $scope.organisationLabel = gettextCatalog.getString('Organisation')
    $scope.transferTypeLabel = gettextCatalog.getString('Payment Type')
    $scope.amountLabel = gettextCatalog.getString('Amount')
    $scope.maxNodes = 800
    $scope.maxExceeded = 0
    $scope.data = {}
    $scope.filter =''
    $scope.loading = true
    $scope.progress = 20
    $scope.showSettings = true
    $scope.org = null
    $scope.slider =
        from: 0
        to: 0
        options:
            step:5
            floor:0
            #showTicks: true
    window.scrollTo 0, 0

    $scope.goToSource = ->
        $state.go 'showflow',
             {
                 name: $scope.source
                 orgType: 'org'
                 pTypes: [2,4,31]
             }
    $scope.goToTarget = ->
        $state.go 'showflow',
            {
                name: $scope.target
                orgType: 'media'
                pTypes: [2,4,31]
            }
    $scope.clearDetails = ->
        $scope.org = null
        update()
    stopLoading = ->
        $scope.loading = false
    pP = TPAService.periods()
    pP.then (res) ->
        $scope.periods = res.data.reverse()
        $scope.slider.options.ceil = ($scope.periods.length - 1)*5
        $scope.slider.from = $scope.slider.options.ceil
        $scope.slider.to = $scope.slider.options.ceil
        $scope.slider.options.translate = (value) -> $scope.periods.map((p) -> "#{p.year}/Q#{p.quarter}")[value/5]
    types = [2,4,31]
    $scope.typesText = (type:type,text: gettextCatalog.getString(TPAService.decodeType(type)),checked:false for type in types)
    $scope.typesText[0].checked = true
    $scope.flows =
        nodes: []
        links: []
    parameters = ->
        params = {}
        params.source = $scope.source
        params.target = $scope.target
        params

    $scope.dtOptions = DTOptionsBuilder.newOptions().withButtons(
        [
            'colvis',
            'excel',
            'print'
        ]
    )

    $scope.updateEvents = () ->
        $scope.$broadcast 'updateEvents'

    TPAService.getEvents().then (res)->
        $scope.events = res.data
        $scope.regions = []
        addedregions = []
        for event in $scope.events
            if addedregions.indexOf(event.region) is -1
                $scope.regions.push {
                    name: event.region
                    selected: false
                }
                addedregions.push event.region

    $scope.toggleRegion = (region) ->
        for event in $scope.events
            if event.region is region.name
                event.selected = region.selected
        $scope.updateEvents()

    $scope.toggleTag = (tag) ->
        for event in $scope.events
            if event.tags.indexOf(tag.name) isnt -1
                event.selected = tag.selected


    TPAService.getEventTags().then (res) ->
        tags = []
        for tag in res.data
            tags.push {
                name: tag,
                selected: false
            }
        $scope.tags = tags


    angular.extend $scope.dtOptions,
        paginationType: 'simple'
        paging:   true
        ordering: true
        info:     true
        searching: false
        language:
            paginate:
                previous: gettextCatalog.getString('previous')
                next: gettextCatalog.getString('next')
            info: gettextCatalog.getString('Showing page _PAGE_ of _PAGES_')
            lengthMenu: gettextCatalog.getString "Display _MENU_ records"


    #check for parameters in the URL so that this view can be bookmarked
    checkForStateParams = ->
        $scope.source = $state.params.source
        $scope.target = $state.params.target

    translate = ->
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type

    $scope.$on 'gettextLanguageChanged', translate
        
    $scope.showFlowDetails = (node) ->
        $state.go('top');

    $scope.getCurrentLanguage = gettextCatalog.getCurrentLanguage

    update = ->
        TPAService.flowdetail(parameters())
        .then (res) ->
            data = res.data
            $scope.data = data
            TPAService.annualcomparison parameters()
            .then (res2) ->
                data2 = res2.data
                $scope.annualComparisonData = data2
                stopLoading()

        $scope.maxExceeded = 0

    $q.all([pP]).then (res) ->
        checkForStateParams()
        update()

]