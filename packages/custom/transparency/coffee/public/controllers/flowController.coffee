'use strict'

app = angular.module 'mean.transparency'

app.controller 'FlowCtrl',['$scope','TPAService','$q','$interval','$state','gettextCatalog', '$filter','DTOptionsBuilder', '$rootScope', '$timeout',
($scope,TPAService,$q,$interval,$state,gettextCatalog, $filter,DTOptionsBuilder,$rootScope, $timeout) ->

    stateName = "flowState"
    fieldsToStore = ['slider','periods','typesText','selectedOrganisations','selectedMedia', 'allOrganisations', 'allMedia']
    startLoading = ->
        try
            $interval.cancel timer if timer isnt null
        catch error
        $scope.loading = true
        $scope.progress = 20
    stopLoading = ->
        $scope.loading = false

    $scope.transferTypeLabel = gettextCatalog.getString('Payment Type')
    $scope.amountLabel = gettextCatalog.getString('Amount')
    $scope.maxNodes = 800
    $scope.maxExceeded = 0
    $scope.data = {}
    $scope.filter =''
    $scope.loading = true
    $scope.progress = 20
    $scope.showSettings = true
    #$scope.org = null
    $scope.isDetails = false
    window.scrollTo 0, 0
    $scope.clearDetails = ->
        #$scope.org = null
        update()
    timer = null
    makeProgress = ->
        $scope.progress = ($scope.progress + 10) % 101
        console.log "Progress: " + $scope.progress
    flowData = []
    nodeMap = {}
    pP = TPAService.periods()
    pP.then (res) ->
        $scope.periods = res.data.reverse()
        $scope.slider =
            from: ($scope.periods.length - 1)*5
            to: ($scope.periods.length - 1)*5
            options:
                ceil: ($scope.periods.length - 1)*5
                step:5
                floor:0
                onEnd: -> change(1,2)
                translate: (value) -> $scope.periods.map((p) -> "#{p.year}/Q#{p.quarter}")[value/5]
                draggableRangeOnly: false
        $scope.fixedRange = false
    types = [2,4,31]
    $scope.typesText = (type:type,text: gettextCatalog.getString(TPAService.decodeType(type)),checked:false for type in types)
    $scope.typesText[0].checked = true
    $scope.flows =
        nodes: []
        links: []

    $scope.mediaLabel = gettextCatalog.getString 'Media'
    $scope.organisationsLabel = gettextCatalog.getString 'Organisations'

    parameters = ->
        params = {}
        params.maxLength = $scope.maxNodes
        params.from = $scope.periods[$scope.slider.from/5].period
        (params.to = $scope.periods[$scope.slider.to/5].period) if $scope.periods
        types = (v.type for v in $scope.typesText when v.checked)
        (params.pType = types) if types.length > 0
        (params.filter = $scope.filter) if $scope.filter.length >= 3
        if $scope.selectedMedia and $scope.selectedMedia.length > 0
            params.media = $scope.selectedMedia.map (media) -> media.name
        if $scope.selectedOrganisations and $scope.selectedOrganisations.length > 0
            params.organisations = $scope.selectedOrganisations.map (org) -> org.name
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
        #$scope.org = {} if $state.params.name or $state.params.orgType
         if $state.params.name
            if $state.params.orgType is 'org'
                $scope.selectedOrganisations = [{name: $state.params.name}]
            else if $state.params.orgType is 'media'
                $scope.selectedMedia = [{name: $state.params.name}]
         # Load grouping
         else if  $state.params.grouping
             groupingMembers = []
             # Load grouping by name
             TPAService.getGroupingMembers({name: $state.params.grouping})
             .then (res) ->
                 if res.data[0].members
                     for member in res.data[0].members
                         #create entry used by controller
                         groupingMembers.push {name: member}
                     #save group members for selection
                     if res.data[0].type is 'org'
                        $scope.selectedOrganisations = groupingMembers
                     else if res.data[0].type is 'media'
                         $scope.selectedMedia = groupingMembers
             .catch (err) ->
                 console.log err

         #$scope.org.orgType = $state.params.orgType if $state.params.orgType
         $scope.slider.from = $scope.periods.map((p) -> p.period).indexOf(parseInt $state.params.from)*5 if $state.params.from
         $scope.slider.to = $scope.periods.map((p) -> p.period).indexOf(parseInt $state.params.to)*5 if $state.params.to
         if $state.params.pTypes?
            pTypes = toArray($state.params.pTypes).map (v) -> parseInt v
            t.checked = t.type in pTypes for t in $scope.typesText

    translate = ->
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type
        $scope.mediaLabel = gettextCatalog.getString 'Media'
        $scope.organisationsLabel = gettextCatalog.getString 'Organisations'


    $scope.$on 'gettextLanguageChanged', translate


    $scope.showDetails = (node) ->
        $scope.isDetails = true;
        if node.type is 'o'
            $scope.selectedOrganisations = [{name: node.name}]
            $scope.selectedMedia = []
        else
            $scope.selectedMedia = [{name: node.name}]
            $scope.selectedOrganisations = []
        ###
        $scope.org = {}
        $scope.org.name = node.name
        $scope.org.orgType = if node.type is 'o' then 'org' else 'media'
        ###
        update()
        window.scrollTo 0,0
        
    $scope.showFlowDetails = (node) ->
        console.log(node);
        if (node.source.type is "o" and node.target.type is "m")
            $state.go(
                'showflowdetail'
                {
                  source: node.source.name
                  target: node.target.name
                })

    filterData = (data) ->
        if $scope.filter.trim().length > 2
            r = new RegExp ".*#{$scope.filter}.*","i"
            data.filter (d) -> r.test(d.organisation) or r.test(d.media)
        else
            data


    update = ->
        if (!$scope.selectedOrganisations or $scope.selectedOrganisations.length is 0) and (!$scope.selectedMedia or $scope.selectedMedia.length is 0) and !$state.params.grouping
            TPAService.top parameters()
            .then (res) ->
                $scope.selectedOrganisations = [{name: res.data.top[0].organisation}]
                return
            return

        console.log "Starting update: " + Date.now()
        startLoading()
        if $scope.selectedOrganisations or $scope.selectedMedia
            TPAService.filteredflows(parameters())
            .then (res) ->
                stopLoading()
                #console.log "Got result from Server: " + Date.now()
                $scope.error = null
                init = true
                flowData = res.data
                for flowDatum in flowData
                    if flowDatum.organisation is 'Other organisations'
                        flowDatum.organisation = gettextCatalog.getString flowDatum.organisation
                    if flowDatum.media is 'Other media'
                        flowDatum.media = gettextCatalog.getString flowDatum.media
                $scope.flowData = flowData
                $scope.flows = buildNodes filterData flowData
                #checkMaxLength(data)
                #console.log "Updated Data Model: " + Date.now()
                ###
                if $scope.selectedOrganisations.length is 1 and $scope.selectedMedia.length is 0
                    $scope.org = {
                        name: $scope.selectedOrganisations[0].name
                        orgType: 'org'
                    }
                else if $scope.selectedOrganisations.length is 0 and $scope.selectedMedia.length is 1
                    $scope.org = {
                        name: $scope.selectedMedia[0].name
                        orgType: 'media'
                    }
                else
                    $scope.org = null
                ###
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

        sum = 0

        data.forEach (entry) ->
            if not nodeMap[entry.organisation]?
                nodeMap[entry.organisation] =
                    index: nodesNum
                    type: 'o'
                    addressData: entry.organisationReference
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
            sum += entry.amount
        nodes = Object.keys(nodeMap).map (k) -> name: k, type: nodeMap[k].type, addressData: nodeMap[k].addressData
        {nodes: nodes,links: links, sum: sum}


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

    $rootScope.$on '$stateChangeStart', (event, toState)->
        if toState.name isnt 'home'
            TPAService.saveState stateName,fieldsToStore, $scope

    $q.all([pP]).then (res) ->
        stateParamsExist = false
        if $state.params
            for k,v of $state.params
                if typeof v isnt 'undefined'
                    stateParamsExist = true

        savedState = sessionStorage.getItem stateName
        if stateParamsExist
            checkForStateParams()
        else if savedState
            TPAService.restoreState stateName, fieldsToStore, $scope
        else
            startLoading()
            $scope.selectedOrganisations = [];
            $scope.selectedMedia = [];
            stopLoading()
        TPAService.search({name: '   '})
        .then (res) ->
            $scope.mediaLabel = gettextCatalog.getString('Media')
            $scope.organisationLabel = gettextCatalog.getString('Organisation')
            $scope.allOrganisations = res.data.org.map (o) ->
                {
                    name: o.name,
                }
            $scope.allMedia = res.data.media.map (m) ->
                {
                    name: m.name,
                }


        $scope.$watchGroup ['selectedOrganisations', 'selectedMedia' ], (newValue, oldValue) ->
            update() if not $scope.isDetails
            $scope.isDetails = false;

        #$scope.$watch('slider.from',change,true)
        #$scope.$watch('slider.to',change,true)
        $scope.$watch('typesText',change,true)
]