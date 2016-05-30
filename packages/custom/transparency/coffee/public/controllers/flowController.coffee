'use strict'

app = angular.module 'mean.transparency'

app.controller 'FlowCtrl',['$scope','TPAService','$q','$interval','$state','gettextCatalog', '$filter','DTOptionsBuilder'
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
            onEnd: -> change(1,2)
    window.scrollTo 0, 0
    $scope.clearDetails = ->
        $scope.org = null
        update()
    timer = null
    makeProgress = ->
        $scope.progress = ($scope.progress + 10) % 101
        console.log "Progress: " + $scope.progress
    startLoading = ->
        try
            $interval.cancel timer if timer isnt null
        catch error
        $scope.loading = true
        $scope.progress = 20
        #timer = $interval makeProgress, 100
    stopLoading = ->
        #$interval.cancel timer
        $scope.loading = false
    flowData = []
    nodeMap = {}
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
    #Variables for the selection of federalState
    $scope.selectedFederalState = '-'
    $scope.federalState = {}
    $scope.federalStates = [{name: 'Burgenland', iso: '1'}, {name: 'Kärnten', iso: '2'}, {name: 'Niederösterreich', iso: '3'}, {name: 'Oberösterreich', iso: '4'}, {name: 'Salzburg', iso: '5'}, {name: 'Steiermark', iso: '6'}, {name: 'Tirol', iso: '7'}, {name: 'Vorarlberg', iso: '8'}, {name: 'Wien', iso: '9'}]
    $scope.flows =
        nodes: []
        links: []
    parameters = ->
        params = {}
        params.maxLength = $scope.maxNodes
        params.from = $scope.periods[$scope.slider.from/5].period
        params.to = $scope.periods[$scope.slider.to/5].period
        (params.federalState = $scope.selectedFederalState.name) if $scope.selectedFederalState
        types = (v.type for v in $scope.typesText when v.checked)
        (params.pType = types) if types.length > 0
        (params.filter = $scope.filter) if $scope.filter.length >= 3
        if $scope.org
            params.name = $scope.org.name
            params.orgType = $scope.org.orgType
        params

    $scope.dtOptions = DTOptionsBuilder.newOptions().withButtons(
        [
            'colvis',
            'excel',
            'print'
        ]
    )


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

    toArray = (value) ->
        if typeof value is 'string'
            value.split ','
        else
            value

    #check for parameters in the URL so that this view can be bookmarked
    checkForStateParams = ->
        $scope.org = {} if $state.params.name or $state.params.orgType
        $scope.org.name = $state.params.name if $state.params.name
        $scope.org.orgType = $state.params.orgType if $state.params.orgType
        $scope.selectedFederalState = $state.selectedFederalState if $state.selectedFederalState
        $scope.slider.from = $scope.periods.map((p) -> p.period).indexOf(parseInt $state.params.from)*5 if $state.params.from
        $scope.slider.to = $scope.periods.map((p) -> p.period).indexOf(parseInt $state.params.to)*5 if $state.params.to
        if $state.params.pTypes?
            pTypes = toArray($state.params.pTypes).map (v) -> parseInt v
            t.checked = t.type in pTypes for t in $scope.typesText

    translate = ->
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type

    $scope.$on 'gettextLanguageChanged', translate


    $scope.showDetails = (node) ->
        $scope.org = {}
        $scope.org.name = node.name
        if node.type is 'o'
            $scope.org.street = node.addressData.street
            $scope.org.zipCode = node.addressData.zipCode
            $scope.org.city = node.addressData.city_de
            $scope.org.country = node.addressData.country_de
        #console.log node.addressData
        $scope.org.orgType = if node.type is 'o' then 'org' else 'media'
        update()
        window.scrollTo 0,0

    filterData = (data) ->
        if $scope.filter.trim().length > 2
            r = new RegExp ".*#{$scope.filter}.*","i"
            data.filter (d) -> r.test(d.organisation) or r.test(d.media)
        else
            data


    update = ->
        console.log "Starting update: " + Date.now()
        startLoading()
        TPAService.flows(parameters())
        .then (res) ->
            stopLoading()
            #console.log "Got result from Server: " + Date.now()
            $scope.error = null
            init = true
            flowData = res.data
            $scope.flowData = flowData
            $scope.flows = buildNodes filterData flowData
            #checkMaxLength(data)
            #console.log "Updated Data Model: " + Date.now()
        .catch (res) ->
            stopLoading()
            $scope.flowData = []
            $scope.flows = nodes:[],links:[]
            $scope.error = res.data


    checkMaxLength = (data) ->
        ###if data.nodes.length > $scope.maxNodes
            $scope.maxExceeded = data.nodes.length
            $scope.flows = {}
        else
        ###
        $scope.maxExceeded = 0
        $scope.flows = data

    buildNodes = (data) ->
        nodes = []
        links = []
        nodesNum = 0
        nodeMap = {}
        data.forEach (entry) ->
            if not nodeMap[entry.organisation]?
                nodeMap[entry.organisation] =
                    index: nodesNum
                    type: 'o'
                    addressData: entry.organisationAddressData[0]
                nodesNum++
            if not nodeMap[entry.media]?
                nodeMap[entry.media] =
                    index: nodesNum
                    type: 'm'
                nodesNum++
            links.push(
                source: nodeMap[entry.organisation].index
                target: nodeMap[entry.media].index
                value: entry.amount
                type: entry.transferType
            )

        nodes = Object.keys(nodeMap).map (k) -> name: k, type: nodeMap[k].type, addressData: nodeMap[k].addressData
        {nodes: nodes,links: links}


    change = (oldValue,newValue) ->
        console.log "Change: " + Date.now()
        update() if (oldValue isnt newValue)

    filterThreshold = "NoValue"
    $scope.$watch 'filter', (newValue,oldValue) ->
        return if newValue is oldValue
        if $scope.error and newValue.length >= 3
            $scope.error = null
            update()
            filterThreshold = newValue
        else
            if newValue.indexOf(filterThreshold) is 0
                $scope.flows = (buildNodes filterData flowData)
            else if newValue.length >= 3 or (newValue.length < 3 and oldValue.length >= 3)
                update()
                filterThreshold = newValue

    $q.all([pP]).then (res) ->
        checkForStateParams()
        update()
        #$scope.$watch('slider.from',change,true)
        #$scope.$watch('slider.to',change,true)
        $scope.$watch('typesText',change,true)
        $scope.$watch('selectedFederalState',change,true)
]