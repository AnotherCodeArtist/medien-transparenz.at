'use strict'

app = angular.module 'mean.transparency'

app.filter('searchFilter', ['$sce', 'gettextCatalog', ($sce, gettextCatalog) ->
    (label, query, item, options, element) ->
        if typeof item.region is "undefined"
            html = '<span class="label label-primary">' + gettextCatalog.getString('custom') + '</span> ' + label + '<span class="close select-search-list-item_selection-remove">&times;</span>'
        else
            html = '<span class="label label-danger">' + gettextCatalog.getString('public') + '</span> ' + item.name + '<span class="close select-search-list-item_selection-remove">&times;</span>'
        $sce.trustAsHtml(html)
])

app.filter('dropdownFilter', ['$sce', 'gettextCatalog', ($sce, gettextCatalog) ->
    (label, query, item, options, element) ->
        if typeof item.region is "undefined"
            html = '<span class="label label-primary">' + gettextCatalog.getString('custom') + '</span> ' + label
        else
            html = '<span class="label label-danger">' + gettextCatalog.getString('public') + '</span> ' + item.name
        $sce.trustAsHtml(html)
])


app.filter('groupFilter', ['$sce', 'gettextCatalog', ($sce, gettextCatalog) ->
    (label, query, item, options, element) ->
        #console.log item
        if typeof item.group is "undefined" or item.group is ""
            html = label + '<span class="close select-search-list-item_selection-remove">&times;</span>'
        else
            labelClass = "label-danger"
            if item.groupType is "custom"
                labelClass = "label-primary"
            html = '<span class="label ' + labelClass + '">' + item.group + '</span> ' + label + '<span class="close select-search-list-item_selection-remove">&times;</span>'
        $sce.trustAsHtml(html)
])

app.controller 'FlowCtrl',['$scope','TPAService','$q','$interval','$state','gettextCatalog', '$filter','DTOptionsBuilder','DTColumnBuilder', '$rootScope', '$timeout','$uibModal'
($scope,TPAService,$q,$interval,$state,gettextCatalog, $filter,DTOptionsBuilder,DTColumnBuilder,$rootScope, $timeout,$uibModal) ->
    #console.log "initialize dataPromise"
    dataPromise = $q.defer()
    stateName = "flowState"
    fieldsToStore = ['slider','periods','typesText', 'allOrganisations', 'allMedia', 'selectedOrganisationGroups',
        'selectedMediaGroups', 'selectedOrganisations','selectedMedia',
        'allOrganisationGroups','allMediaGroups']
    $scope.init = 'init'
    typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
    $scope.mediaLabel = gettextCatalog.getString('Media')
    $scope.organisationLabel = gettextCatalog.getString('Organisation')
    $scope.organisationGroupLabel = gettextCatalog.getString('Organisation Group')
    $scope.mediaGroupLabel = gettextCatalog.getString('Media Group')
    clearFields = ->
        $scope.selectedOrganisations = []
        $scope.selectedMedia = []
        $scope.selectedMediaGroups = []
        $scope.selectedOrganisationGroups = []
    clearFields()
    # Method for setting the intro-options (e.g. after translations)
    setIntroOptions = ->
        $scope.IntroOptions =
            steps: [
                {
                    element: document.querySelector('#flowSettings')
                    intro: gettextCatalog.getString 'It is possible to customize the pie chart. To do so, use the settings.'
                },
                {
                    element: document.querySelector('#flowSlider')
                    intro: gettextCatalog.getString 'Move the sliders to define a range.'
                }, {
                    element: document.querySelector('#fixSliderRange')
                    intro: gettextCatalog.getString 'Fix slider range. With that it is possible to keep the range constant.'
                },
                {
                    element: document.querySelector('#paymentTypes')
                    intro: gettextCatalog.getString 'Transfers are divided in different payment types. Select the types to display.'
                },
                {
                    element: document.querySelector('#multiselectOrg')
                    intro: gettextCatalog.getString 'You can add organisations to the flow. Go into detail by clicking on the rectangular box.'
                },
                {
                    element: document.querySelector('#multiselectMedia')
                    intro: gettextCatalog.getString 'You can add media to the flow too. Click on the rectangular box for details.'
                },
                {
                    element: document.querySelector('#multiselectOrgGroup')
                    intro: gettextCatalog.getString 'It is possible to select predefined groups for organisations. The entries of the group will be loaded and displayed automatically.'
                },
                {
                    element: document.querySelector('#multiselectMediaGroup')
                    intro: gettextCatalog.getString 'It is possible to select predefined groups for media. The entries of the group will be loaded and displayed automatically.'
                },
                {
                    element: document.querySelector('#customGroups')
                    intro: gettextCatalog.getString 'Based on your selection, you can create custom groups for all non-grouped organisations or media.'
                },
                {
                    element: document.querySelector('#sankeyRow')
                    intro: gettextCatalog.getString 'Per default the top spender based on your chosen payment types and period is selected.'
                },
                {
                    element: document.querySelector('#sankeyRow')
                    intro: gettextCatalog.getString 'To discover the flow in detail just click on the flow between an organisation and a media entry.'
                }
            ]
            showStepNumbers: false
            exitOnOverlayClick: true
            exitOnEsc: true
            nextLabel: gettextCatalog.getString 'Next info'
            prevLabel: gettextCatalog.getString 'Previous info'
            skipLabel: gettextCatalog.getString 'Skip info'
            doneLabel: gettextCatalog.getString 'End tour'


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
    initSlider = ->
        if not $scope.slider? then $scope.slider = {}
        $scope.slider.options =
            ceil: ($scope.periods.length - 1)*5
            step:5
            floor:0
            onEnd: -> change(1,2)
            translate: (value) -> $scope.periods.map((p) -> "#{p.year}/Q#{p.quarter}")[value/5]
            draggableRangeOnly: false
        $scope.slider.from =  ($scope.periods.length - 1)*5 if (not $scope.slider.from?) or isNaN($scope.slider.from)
        $scope.slider.to = ($scope.periods.length - 1)*5 if not $scope.slider.to?
        if not $scope.fixedRange? then $scope.fixedRange = false
    #Load all available periods
    loadPeriods = () =>
        deferred = $q.defer()
        TPAService.periods()
        .then (res) ->
            $scope.periods = res.data.reverse()
            initSlider()
            deferred.resolve()
        deferred.promise
    #(Pre-)load all organisation and media names
    loadAllNames = () ->
        deferred = $q.defer();
        TPAService.search({name: ' '})
        .then (res) ->
            $scope.mediaLabel = gettextCatalog.getString('Media')
            $scope.organisationLabel = gettextCatalog.getString('Organisation')
            $scope.organisationGroupLabel = gettextCatalog.getString('Organisation Group')
            $scope.mediaGroupLabel = gettextCatalog.getString('Media Group')
            if typeof $scope.allOrganisations is 'undefined' or $scope.allOrganisations.length is 0
                $scope.allOrganisations = res.data.org.map (o) ->
                    {
                        name: o.name,
                    }
            if typeof $scope.allMedia is 'undefined' or $scope.allMedia.length is 0
                $scope.allMedia = res.data.media.map (m) ->
                    {
                        name: m.name,
                    }
            deferred.resolve()
        deferred.promise

    types = [2,4,31]
    $scope.typesText = (type:type,text: gettextCatalog.getString(TPAService.decodeType(type)),checked:false for type in types)
    $scope.typesText[0].checked = true
    $scope.flows =
        nodes: []
        links: []

    $scope.mediaLabel = gettextCatalog.getString 'Media'
    $scope.organisationsLabel = gettextCatalog.getString 'Organisations'
    $scope.organisationGroupLabel = gettextCatalog.getString('Organisation Group')
    $scope.mediaGroupLabel = gettextCatalog.getString('Media Group')

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


    # init the introOptions and call the method
    $scope.IntroOptions = null;
    setIntroOptions()

    toArray = (value) ->
        if typeof value is 'string'
            value.split ','
        else
            value

    #check for parameters in the URL so that this view can be bookmarked
    checkForStateParams = ->
        compareWith = (param) ->
            (value) ->
                if typeIsArray param then value.name in param else value.name is param
        $scope.slider.from = $scope.periods.map((p) -> p.period).indexOf(parseInt $state.params.from)*5 if $state.params.from
        $scope.slider.to = $scope.periods.map((p) -> p.period).indexOf(parseInt $state.params.to)*5 if $state.params.to
        if $state.params.media?
            $scope.selectedMedia = $scope.allMedia.filter(compareWith($state.params.media))
        if $state.params.organisations?
            $scope.selectedOrganisations = $scope.allOrganisations.filter(compareWith($state.params.organisations))
        if $state.params.orgGrp?
            $scope.selectedOrganisationGroups = $scope.allOrganisationGroups.filter(compareWith($state.params.orgGrp))
            members = $scope.selectedOrganisationGroups.map((g)->g.members.map((m)->{name:m,group:g.name,groupType:if g.serverside then 'public' else 'custom'})).reduce(((a,b)->a.concat(b)),[])
            memberNames = members.map((o)->o.name)
            $scope.selectedOrganisations = $scope.selectedOrganisations.filter((o)->o.name not in memberNames)
            .concat(members)
        if $state.params.mediaGrp?
            $scope.selectedMediaGroups = $scope.allMediaGroups.filter(compareWith($state.params.mediaGrp))
            members = $scope.selectedMediaGroups.map((g)->g.members.map((m)->{name:m,group:g.name,groupType:if g.serverside then 'public' else 'custom'})).reduce(((a,b)->a.concat(b)),[])
            memberNames = members.map((o)->o.name)
            $scope.selectedMedia = $scope.selectedMedia.filter((o)->o.name not in memberNames)
                .concat(members)
        if $state.params.pTypes?
            pTypes = toArray($state.params.pTypes).map (v) -> parseInt v
            t.checked = t.type in pTypes for t in $scope.typesText
        #$scope.org = {} if $state.params.name or $state.params.orgType
        if $state.params.name
            if $state.params.orgType is 'org'
                $scope.selectedOrganisations = [{name: $state.params.name}]
            else if $state.params.orgType is 'media'
                $scope.selectedMedia = [{name: $state.params.name}]
         # Load grouping
        else if  $state.params.grouping
             # Load grouping by name
             mediaGroup = $scope.allMediaGroups.filter((g)->g.name is $state.params.grouping)
             orgGroup = $scope.allOrganisationGroups.filter((g)->g.name is $state.params.grouping)
             if mediaGroup.length > 0
                 $scope.selectedMediaGroup = mediaGroup[0]
                 $scope.selectedMedia = mediaGroup.members.map((m) -> m.name)
             else if orgGroup.length > 0
                 $scope.selectedOrganisations = orgGroup.members.map((m) -> m.name)
                 $scope.selectedOrganionsationGroups = orgGroup[0]



    translate = ->
        $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type
        $scope.mediaLabel = gettextCatalog.getString 'Media'
        $scope.organisationsLabel = gettextCatalog.getString 'Organisations'
        $scope.organisationGroupLabel = gettextCatalog.getString 'Organisation Group'
        $scope.mediaGroupLabel = gettextCatalog.getString 'Media Group'
        setIntroOptions()


    $scope.$on 'gettextLanguageChanged', translate

    #Updates the browser's address bar without causing the controller to be reloaded
    #this allows to bookmark the page in every state
    updateURL = ->
        $state.transitionTo('showflow',{
            from: $scope.periods[$scope.slider.from/5].period
            to: $scope.periods[$scope.slider.to/5].period
            media: $scope.selectedMedia.map((m)->m.name)
            organisations: $scope.selectedOrganisations.map((o)->o.name)
            mediaGrp: $scope.selectedMediaGroups.map((g)->g.name)
            orgGrp: $scope.selectedOrganisationGroups.map((g)->g.name)
            pTypes: (v.type for v in $scope.typesText when v.checked)
        },{notify:false})

    $scope.showDetails = (node) ->
        selectionTypes =
            o: 'org'
            m: 'media'
            mg: 'mediaGrp'
            og: 'orgGrp'
        $scope.isDetails = true;
        $scope.selectedMediaGroups = []
        $scope.selectedOrganisationGroups = []
        $scope.selectedMedia = []
        $scope.selectedOrganisations = []
        switch node.type
            when 'o'
                $scope.selectedOrganisations = [{name: node.name}]
            when 'm'
                $scope.selectedMedia = [{name: node.name}]
            when 'og'
                $scope.selectedOrganisationGroups = $scope.allOrganisationGroups.filter((g)->g.name is node.name.substring(4))
                $scope.selectedOrganisations = $scope.selectedOrganisationGroups
                .map((g)->g.members).reduce(((a,b) -> a.concat(b)),[])
            when 'mg'
                $scope.selectedMediaGroups = $scope.allMediaGroups.filter((g)->g.name is node.name.substring(4))
                $scope.selectedMedia = $scope.selectedMediaGroups
                .map((g)->g.members).reduce(((a,b) -> a.concat(b)),[])
        updateURL()
        window.scrollTo 0,0

    $scope.showFlowDetails = (node) ->
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
        if (!$scope.selectedOrganisations or $scope.selectedOrganisations.length is 0) and (!$scope.selectedMedia or $scope.selectedMedia.length is 0) and !$state.params.grouping and  $scope.init is 'init'
            $scope.init = 'preselected'
            TPAService.top parameters()
            .then (res) ->
                $scope.selectedOrganisations = [{name: res.data.top[0].organisation}]
            return

        #console.log "Starting update: " + Date.now()
        startLoading()
        if ($scope.selectedOrganisations and $scope.selectedOrganisations.length > 0) or ($scope.selectedMedia and $scope.selectedMedia.length > 0)
            TPAService.filteredflows(parameters())
            .then (res) ->
                stopLoading()
                #console.log "Got result from Server: " + Date.now()
                $scope.error = null
                flowData = res.data
                for flowDatum in flowData
                    if flowDatum.organisation is 'Other organisations'
                        flowDatum.organisation = gettextCatalog.getString flowDatum.organisation
                    if flowDatum.media is 'Other media'
                        flowDatum.media = gettextCatalog.getString flowDatum.media
                $scope.flowData = flowData
                if dataPromise.promise.$$state.status == 1
                    dataPromise = $q.defer()
                    if $scope.dtInstance.reloadData
                        $scope.dtInstance.reloadData()
                dataPromise.resolve()
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
                #console.log "resolve dataPromise after exception"
                dataPromise.resolve()
        else
            stopLoading()
            $scope.error = "nothing selected"

    checkMaxLength = (data) ->
        ###if data.nodes.length > $scope.maxNodes
            $scope.maxExceeded = data.nodes.length
            $scope.flows = {}
        else
        ###
        $scope.maxExceeded = 0
        $scope.flows = data

    createLink = (source, target, value, type) ->
        {
            source: source
            target: target
            value: value
            type: type
        }


    buildNodes = (data) ->
        nodes = []
        links = []
        nodesNum = 0
        nodeMap = {}

        sum = 0

        data.forEach (entry) ->
            entryOrgGroup = ""
            entryMediaGroup = ""

            if $scope.selectedOrganisationGroups
                for orgGroup in $scope.selectedOrganisationGroups
                    if orgGroup.members.indexOf(entry.organisation) isnt -1
                        entryOrgGroup = orgGroup.name

            if $scope.selectedMediaGroups
                for mediaGroup in $scope.selectedMediaGroups
                    if mediaGroup.members.indexOf(entry.media) isnt -1
                        entryMediaGroup = mediaGroup.name

            if entryOrgGroup isnt "" and not nodeMap["OG: " + entryOrgGroup]
                nodeMap["OG: " + entryOrgGroup] =
                    index: nodesNum
                    type: 'og'
                nodesNum++

            if entryMediaGroup isnt "" and not nodeMap["MG: " + entryMediaGroup]
                nodeMap["MG: " + entryMediaGroup] =
                    index: nodesNum
                    type: 'mg'
                nodesNum++

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
            if entryOrgGroup is "" and entryMediaGroup is ""
                links.push(createLink(nodeMap[entry.organisation].index, nodeMap[entry.media].index, entry.amount, entry.transferType))
            else if entryOrgGroup isnt "" and entryMediaGroup is ""
                link1 = null
                link2 = null
                for link in links
                    if link.source is nodeMap[entry.organisation].index and link.target is nodeMap["OG: " + entryOrgGroup].index
                        link1 = link
                    else if link.source is nodeMap["OG: " + entryOrgGroup].index and link.target is nodeMap[entry.media].index
                        link2 = link
                    if link1 isnt null and link2 isnt null
                        break
                if link1 isnt null
                    link1.value += entry.amount
                else
                    links.push(createLink(nodeMap[entry.organisation].index, nodeMap["OG: " + entryOrgGroup].index, entry.amount, entry.transferType))
                if link2 isnt null
                    link2.value += entry.amount
                else
                    links.push(createLink(nodeMap["OG: " + entryOrgGroup].index, nodeMap[entry.media].index, entry.amount, entry.transferType))
            else if entryOrgGroup is "" and entryMediaGroup isnt ""
                link1 = null
                link2 = null
                for link in links
                    if link.source is nodeMap[entry.organisation].index and link.target is nodeMap["MG: " + entryMediaGroup].index
                        link1 = link
                    else if link.source is nodeMap["MG: " + entryMediaGroup].index and link.target is nodeMap[entry.media].index
                        link2 = link
                    if link1 isnt null and link2 isnt null
                        break
                if link1 isnt null
                    link1.value += entry.amount
                else
                    links.push(createLink(nodeMap[entry.organisation].index, nodeMap["MG: " + entryMediaGroup].index, entry.amount, entry.transferType))
                if link2 isnt null
                    link2.value += entry.amount
                else
                    links.push(createLink(nodeMap["MG: " + entryMediaGroup].index, nodeMap[entry.media].index, entry.amount, entry.transferType))
            else
                link1 = null
                link2 = null
                link3 = null
                for link in links
                    if link.source is nodeMap[entry.organisation].index and link.target is nodeMap["OG: " + entryOrgGroup].index
                        link1 = link
                    else if link.source is nodeMap["OG: " + entryOrgGroup].index and link.target is nodeMap["MG: " + entryMediaGroup].index
                        link2 = link
                    else if link.source is nodeMap["MG: " + entryMediaGroup].index and link.target is nodeMap[entry.media].index
                        link3 = link
                    if link1 isnt null and link2 isnt null and link3 isnt null
                        break
                if link1 isnt null
                    link1.value += entry.amount
                else
                    links.push(createLink(nodeMap[entry.organisation].index, nodeMap["OG: " + entryOrgGroup].index, entry.amount, entry.transferType))
                if link2 isnt null
                    link2.value += entry.amount
                else
                    links.push(createLink(nodeMap["OG: " + entryOrgGroup].index, nodeMap["MG: " + entryMediaGroup].index, entry.amount, entry.transferType))
                if link3 isnt null
                    link3.value += entry.amount
                else
                    links.push(createLink(nodeMap["MG: " + entryMediaGroup].index, nodeMap[entry.media].index, entry.amount, entry.transferType))

            sum += entry.amount
        nodes = Object.keys(nodeMap).map (k) -> name: k, type: nodeMap[k].type, addressData: nodeMap[k].addressData
        {nodes: nodes,links: links, sum: sum}

    $scope.dtOptions = {}
    $scope.dtOptions = DTOptionsBuilder.fromFnPromise( ->
        defer = $q.defer()
        dataPromise.promise.then (result) ->
            defer.resolve($scope.flowData);
        defer.promise
    )
    .withPaginationType('full_numbers')
    .withButtons(['copy','csv','excel'])
    .withBootstrap()

    angular.extend $scope.dtOptions,
        language:
            paginate:
                previous: gettextCatalog.getString('previous')
                next: gettextCatalog.getString('next')
                first: gettextCatalog.getString('first')
                last: gettextCatalog.getString('last')
            search: gettextCatalog.getString('search')
            info: gettextCatalog.getString('Showing page _PAGE_ of _PAGES_')
            lengthMenu: gettextCatalog.getString "Display _MENU_ records"

    getExplanation = (paymentType) -> switch paymentType
        when 2 then gettextCatalog.getString('§2 MedKF-TG (Media Cooperations)')
        when 4 then gettextCatalog.getString('§4 MedKF-TG (Funding)')
        when 31 then gettextCatalog.getString('§31 ORF-G (Charges)')

    $scope.dtColumns = [
        DTColumnBuilder.newColumn('organisation').withTitle(gettextCatalog.getString('Payer'))
        DTColumnBuilder.newColumn('media').withTitle(gettextCatalog.getString('Recipient')),
        DTColumnBuilder.newColumn('transferType').withTitle(gettextCatalog.getString('Type'))
        .renderWith((paragraph,type)->
            if type is 'display'
                getExplanation(paragraph)
            else
                paragraph
        )
        DTColumnBuilder.newColumn('amount').withTitle(gettextCatalog.getString('Amount'))
        .renderWith((amount,type) ->
            if type is 'display'
                amount.toLocaleString($rootScope.language,{currency: "EUR", maximumFractionDigits:2,minimumFractionDigits:2})
            else
                amount)
        .withClass('text-right')
    ]

    $scope.dtInstance = {}



    change = (oldValue,newValue) ->
        #console.log "Change: " + Date.now()
        if (oldValue isnt newValue)
            dataPromise = $q.defer()
            $scope.dtInstance.reloadData()
            updateURL()
            update()


    $rootScope.$on '$stateChangeStart', (event, toState)->
        if toState.name isnt 'home'
            TPAService.saveState stateName,fieldsToStore, $scope

    loadGroups = () ->
        orgGroupsPromise = TPAService.getGroupings {type: 'org'}
        orgGroupsPromise.then (res, err) ->
            if (err)
                console.error err
                return
            $scope.allOrganisationGroups = res.data.concat(TPAService.getLocalGroups("org"))
        mediaGroupsPromise = TPAService.getGroupings {type: 'media'}
        mediaGroupsPromise.then (res, err) ->
            if (err)
                console.error err
                return
            $scope.allMediaGroups = res.data.concat(TPAService.getLocalGroups("media"))
        $q.all([orgGroupsPromise,mediaGroupsPromise])

    #start initialization


    savedState = sessionStorage.getItem stateName

    stateParamsExist = () ->
        if $state.params
            for k,v of $state.params
                if typeof v isnt 'undefined'
                    return true
        return false

    #Lazy loading of media for multi selection box

    mediaList = []
    $scope.loadMedia = (name) ->
        if name.length >= 3
            if mediaList.length == 0
                mediaList = $scope.allMedia.filter((m)-> m.name.toLowerCase().indexOf(name.toLowerCase()) > -1)
        else
            mediaList = []
        mediaList

    organisationList = []
    #Lazy loading of organisation for multi selection box
    $scope.loadOrganisations = (name) ->
        if name.length >= 3
            if organisationList.length == 0
                organisationList = $scope.allOrganisations.filter((m)-> m.name.toLowerCase().indexOf(name.toLowerCase()) > -1)
        else organisationList = []
        organisationList

    #Initialize form data either by loading a saved state or by fetching data from the server
    initialize = ->
        deferred = $q.defer()
        if savedState
            TPAService.restoreState stateName, fieldsToStore, $scope
            initSlider()
            stopLoading()
            deferred.resolve()
        else
            startLoading()
            $q.all([loadPeriods(),loadAllNames(),loadGroups()])
            .then () ->
                stopLoading()
                if not stateParamsExist()
                    #no defined state so start loading default data
                    update()
                deferred.resolve()
        deferred.promise


    initialize()
    .then ->
        if stateParamsExist()
            clearFields()
            checkForStateParams()
        update()


    dialogText =

    showDialog = (text) ->
        $uibModal.open(
            {
                template: """
                    <div class="source-list-modal">
                        <div class="modal-header">
                            <h3 class="modal-title">
                                Info
                            </h3>

                        </div>
                        <div class="modal-body">
                            <p>#{text}</p>
                        </div>
                        <div class="modal-footer">
                            <div class="controls">
                                <button class="btn btn-primary" type="button" ng-click="close()">OK</button>
                            </div>
                        </div>
                    </div>
                """
                controller: ($scope, $uibModalInstance) ->
                    $scope.close = -> $uibModalInstance.close()
                size: 'sm'
            })

    selectedOrganisationsChanged = (newValue, oldValue) ->
        return if newValue is oldValue
        if newValue.length < oldValue.length
            removedElement = oldValue.filter((o) -> o.name not in newValue.map((v)->v.name))[0]
            if removedElement.name in $scope.selectedOrganisationGroups.map((g)->g.members).reduce(((a,b) -> a.concat(b)),[])
                $scope.selectedOrganisations = oldValue
                $scope.deselectionNotAllowed = oldValue.name
                showDialog gettextCatalog.getString "You cannot remove this Organisation since it belongs to a selected group. Remove the group first"
                return
        if not $scope.isDetails
            updateURL()
            update()
        $scope.isDetails = false;

    selectedMediaChanged = (newValue, oldValue) ->
        if newValue == oldValue then return
        if newValue.length < oldValue.length
            removedElement = oldValue.filter((o) -> o.name not in newValue.map((v)->v.name))[0]
            if removedElement.name in $scope.selectedMediaGroups.map((g)->g.members).reduce(((a,b) -> a.concat(b)),[])
                $scope.selectedMedia = oldValue
                $scope.deselectionNotAllowed = oldValue.name
                showDialog gettextCatalog.getString "You cannot remove this Media since it belongs to a selected group. Remove the group first"
                return
        if not $scope.isDetails
            updateURL()
            update()
        $scope.isDetails = false;


    handleRemovingOrgGroup = (newValue) ->
        newOrganisationsInSelectedGroups = []
        for orgGroup in newValue
            newOrganisationsInSelectedGroups = newOrganisationsInSelectedGroups.concat orgGroup.members
        for org in $scope.allOrganisations
            if newOrganisationsInSelectedGroups.indexOf(org.name) is -1
                org.group = ""
                org.groupType = ""
        $scope.organisationsInSelectedGroups = newOrganisationsInSelectedGroups

    handleAddingOrgGroup = (newValue, oldValue) ->
        $scope.badMembers = []
        if $scope.organisationsInSelectedGroups.length > 0
            for member in newValue[newValue.length - 1].members
                if $scope.organisationsInSelectedGroups.indexOf(member) isnt -1
                    $scope.badMembers.push member

        if $scope.badMembers.length isnt 0
            $scope.selectedOrganisationGroups = oldValue
            return

        selectedOrganisations = $scope.selectedOrganisations.map (org) ->
            org.name
        newSelectedOrganisations = $scope.selectedOrganisations.slice()
        for member in newValue[newValue.length - 1].members
            $scope.organisationsInSelectedGroups.push member
            for organisation in $scope.allOrganisations
                if organisation.name is member
                    organisation.group = newValue[newValue.length - 1].name
                    if (typeof newValue[newValue.length - 1].region is 'undefined')
                        organisation.groupType = "custom"
                    else
                        organisation.groupType = "public"
                    if selectedOrganisations.indexOf(member) is -1
                        newSelectedOrganisations.push organisation
        $scope.selectedOrganisations = newSelectedOrganisations
        return

    selectedOrganisationGroupsChanged = (newValue, oldValue) ->
        return if newValue is oldValue
        newLength = if (typeof newValue isnt 'undefined') then newValue.length else 0
        oldLength = if (typeof oldValue isnt 'undefined') then oldValue.length else 0
        if newLength < oldLength
            handleRemovingOrgGroup(newValue)
        else
            handleAddingOrgGroup(newValue, oldValue)
        change(2,1)

    handleRemovingMediaGroup = (newValue, oldValue) ->
        return if newValue is oldValue
        newMediaInSelectedGroups = []
        for mediaGroup in newValue
            newMediaInSelectedGroups = newMediaInSelectedGroups.concat mediaGroup.members
        for media in $scope.allMedia
            if newMediaInSelectedGroups.indexOf(media.name) is -1
                media.group = ""
                media.groupType = ""
        $scope.mediaInSelectedGroups = newMediaInSelectedGroups

    handleAddingMediaGroups = (newValue, oldValue) ->
        return if newValue is oldValue
        $scope.badMembers = []
        if $scope.mediaInSelectedGroups.length > 0
            for member in newValue[newValue.length - 1].members
                if $scope.mediaInSelectedGroups.indexOf(member) isnt -1
                    $scope.badMembers.push member
        if $scope.badMembers.length isnt 0
            $scope.selectedMediaGroups = oldValue
            return

        selectedMedia = $scope.selectedMedia.map (media) ->
            media.name
        newSelectedMedia = $scope.selectedMedia.slice()
        for member in newValue[newValue.length - 1].members
            $scope.mediaInSelectedGroups.push member
            for media in $scope.allMedia
                if media.name is member
                    media.group = newValue[newValue.length - 1].name
                    if (typeof newValue[newValue.length - 1].region is 'undefined')
                        media.groupType = "custom"
                    else
                        media.groupType = "public"
                    if selectedMedia.indexOf(member) is -1
                        newSelectedMedia.push media
        $scope.selectedMedia = newSelectedMedia
        return

    selectedMediaGroupsChanged = (newValue, oldValue) ->
        return if newValue is oldValue
        newLength = if (typeof newValue isnt 'undefined') then newValue.length else 0
        oldLength = if (typeof oldValue isnt 'undefined') then oldValue.length else 0
        if newLength < oldLength
            handleRemovingMediaGroup(newValue)
        else
            handleAddingMediaGroups(newValue, oldValue)
        change(2,1)

    $scope.createLocalOrgGroup = () ->
        members = []
        for localgroup in TPAService.getLocalGroups "org"
            if localgroup.name is $scope.localOrgGroupName
                $scope.localGroupError = gettextCatalog.getString "Custom group could not be created since an local group with an equal name already exists"
                break
                return
        for org in $scope.selectedOrganisations
            if $scope.organisationsInSelectedGroups.indexOf(org.name) is -1
                members.push org.name
        if members.length is 0
            $scope.localGroupError = gettextCatalog.getString "Custom group could not be created because there are no ungrouped entries."
            return
        $scope.localGroupError = ""
        group = {
            type: "org"
            members: members
            name: $scope.localOrgGroupName
        }
        TPAService.saveLocalGroup group
        $scope.allOrganisationGroups.push group
        $scope.selectedOrganisationGroups = $scope.selectedOrganisationGroups.concat [group]
        $scope.localOrgGroupName = ""

    $scope.createLocalMediaGroup = () ->
        members = []
        for localgroup in TPAService.getLocalGroups "media"
            if localgroup.name is $scope.localMediaGroupName
                $scope.localGroupError = gettextCatalog.getString "Custom group could not be created since an local group with an equal name already exists"
                break
                return
        for media in $scope.selectedMedia
            if $scope.mediaInSelectedGroups.indexOf(media.name) is -1
                members.push media.name
        if members.length is 0
            $scope.localGroupError = gettextCatalog.getString "Custom group could not be created because there are no ungrouped entries."
            return
        $scope.localGroupError = ""
        group = {
            type: "media"
            members: members
            name: $scope.localMediaGroupName
        }
        TPAService.saveLocalGroup group
        $scope.allMediaGroups.push group
        $scope.selectedMediaGroups = $scope.selectedMediaGroups.concat [group]
        $scope.localMediaGroupName = ""

    $scope.organisationsInSelectedGroups = []
    $scope.mediaInSelectedGroups = []
    ###
    $scope.$watch 'selectedOrganisations', (newValue, oldValue) ->
        return if newValue is oldValue
        if typeof $scope.allOrganisations isnt 'undefined' and $scope.allOrganisations.length > 0
            $scope.selectedOrganisations = $scope.allOrganisations.filter((o) -> o.name in $scope.selectedOrganisations)
    , true
    $scope.$watch 'selectedMedia', (newValue, oldValue) ->
        return if newValue is oldValue
            $scope.selectedMedia = $scope.allMedia.filter((m) -> m.name in $scope.selectedMedia)
    , true
    ###
    $scope.$watch 'selectedOrganisationGroups', selectedOrganisationGroupsChanged, true
    $scope.$watch 'selectedMediaGroups', selectedMediaGroupsChanged, true
    $scope.$watch 'selectedMedia', selectedMediaChanged, true
    $scope.$watch 'selectedOrganisations', selectedOrganisationsChanged, true


    #$scope.$watch('slider.from',change,true)
    #$scope.$watch('slider.to',change,true)
    $scope.$watch('typesText',change,true)
]