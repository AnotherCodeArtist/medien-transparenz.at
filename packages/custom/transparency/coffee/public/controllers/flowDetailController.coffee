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
    $scope.IntroOptions = null;
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
        if $state.params.pTypes then params.pTypes = $state.params.pTypes
        params

    $scope.getExplanation = (paymentType) -> switch paymentType
        when "2" then gettextCatalog.getString('§2 MedKF-TG (Media Cooperations)')
        when "4" then gettextCatalog.getString('§4 MedKF-TG (Funding)')
        when "31" then gettextCatalog.getString('§31 ORF-G (Charges)')

    $scope.dtOptions = DTOptionsBuilder.newOptions().withButtons(
        [
            'colvis',
            'excel',
            'print'
        ]
    )

    # Method for setting the intro-options (e.g. after translations)
    setIntroOptions = ->
        $scope.IntroOptions =
            steps: [
                {
                    element: document.querySelector('#eventsSelection')
                    intro: gettextCatalog.getString 'It is possible to show specific events. Per default, all events are selected.'
                }
                {
                    element: document.querySelector('#tagSelection')
                    intro: gettextCatalog.getString 'Events can be related to tags. To select specific tags, use this option.'
                }, {
                    element: document.querySelector('#regionSelection')
                    intro: gettextCatalog.getString 'Events are connected to regions. To show events from a specific region, use this option.'
                }, {
                    element: document.querySelector('#flowDetailLegend')
                    intro: gettextCatalog.getString 'The legend describes the possible icons used for the charts.'
                }

            ]
            showStepNumbers: false
            exitOnOverlayClick: true
            exitOnEsc: true
            nextLabel: gettextCatalog.getString 'Next info'
            prevLabel: gettextCatalog.getString 'Previous info'
            skipLabel: gettextCatalog.getString 'Skip info'
            doneLabel: gettextCatalog.getString 'End tour'

    $scope.updateEvents = () ->
        $scope.$broadcast 'updateEvents'

    TPAService.getEvents().then (res)->
        $scope.events = res.data
        $scope.regions = []
        addedregions = []
        for event in $scope.events
            event.selected = true;
            if addedregions.indexOf(event.region) is -1
                $scope.regions.push {
                    name: event.region
                    selected: true
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
                selected: true
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
        $scope.source = $state.params.source or []
        $scope.target = $state.params.target or []
        $scope.pTypes = $state.params.pTypes
        $scope.source = [$scope.source] if $scope.source not instanceof Array
        $scope.target = [$scope.target] if $scope.target not instanceof Array
        $scope.sourceType = $state.params.sourceType
        $scope.targetType = $state.params.targetType
        $scope.sourceGrp = $state.params.sourceGrp
        $scope.targetGrp = $state.params.targetGrp

    translate = ->
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type
        setIntroOptions()

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
                setIntroOptions()

        $scope.maxExceeded = 0

    $q.all([pP]).then (res) ->
        checkForStateParams()
        update()

]