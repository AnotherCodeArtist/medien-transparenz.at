'use strict'

app = angular.module 'mean.transparency'

app.filter('searchFilter', ['$sce', 'gettextCatalog', ($sce, gettextCatalog) ->
    (label, query, item, options, element) ->
        #console.log "searchFilter"+item.name
        html = """<span class="label #{if item.groupType is 'public' then 'label-danger' else 'label-primary'}">
            #{gettextCatalog.getString(item.groupType)}</span>#{item.name}
            <span class="close select-search-list-item_selection-remove">&times;</span>"""
        $sce.trustAsHtml(html)
])

app.filter('dropdownFilter', ['$sce', 'gettextCatalog', ($sce, gettextCatalog) ->
    (label, query, item, options, element) ->
        #console.log "dropdownFilter"+item.name
        html = """<span class="label #{if item.groupType is 'public' then 'label-danger' else 'label-primary'}">
            #{gettextCatalog.getString(item.groupType)}</span>&nbsp;#{item.name}<span class="close select-search-list-item_selection-remove">&times;</span>"""
        ###
        if not item.region?
            html = '<span class="label label-primary">' + gettextCatalog.getString('custom') + '</span> ' + label
        else
            html = '<span class="label label-danger">' + gettextCatalog.getString('public') + '</span> ' + item.name
        ###
        $sce.trustAsHtml(html)
])


app.filter('groupFilter', ['$sce', 'gettextCatalog', ($sce, gettextCatalog) ->
    (label, query, item, options, element) ->
        #console.log "groupFilter"+item.name
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
    forcedChange = false
    gettextCatalog.getString("custom")
    gettextCatalog.getString("public")
    stateName = "flowState"
    fieldsToStore = ['slider','periods','typesText', 'allOrganisations', 'allMedia', 'selectedOrganisationGroups',
        'selectedMediaGroups', 'selectedOrganisations','selectedMedia',
        'allOrganisationGroups','allMediaGroups','events','tags','regions']
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

    $scope.showTable = false
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


    $scope.timelineOpened = ->
        $timeout((-> $rootScope.$broadcast "updateTimeline"), 100)

    $scope.flowOpened = ->
        $timeout((-> $rootScope.$broadcast "updateFlow"), 100)

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
    $scope.showSettings = false
    $scope.selectionSettings = false
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

    loadEvents = () ->
        deferred = $q.defer();
        TPAService.getEvents().then (res)->
            $scope.events = res.data.map((event) -> event.selected=true;event)
            $scope.regions = []
            addedregions = []
            for event in $scope.events
                #event.selected = true;
                if addedregions.indexOf(event.region) is -1
                    $scope.regions.push {
                        name: event.region
                        selected: true
                    }
                    addedregions.push event.region
            deferred.resolve(res)
        deferred

    loadEventTags = () ->
        deferred = $q.defer();
        TPAService.getEventTags().then (res) ->
            $scope.tags = res.data.map((tag)-> {name: tag, selected:true} )
            deferred.resolve(res)
        deferred

    $scope.updateEvents = () ->
    $scope.$broadcast 'updateEvents'

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


    parametersTimeline = ->
        params = {}
        params.source = $scope.selectedOrganisations.map (org) -> org.name
        params.target = $scope.selectedMedia.map (media) -> media.name
        types = (v.type for v in $scope.typesText when v.checked)
        (params.pType = types) if types.length > 0
        params


    # init the introOptions and call the method
    $scope.IntroOptions = null;
    setIntroOptions()

    toArray = (value) ->
        if typeof value is 'string'
            value.split ','
        else
            value

    compareWith = (param) ->
        (value) ->
            if typeIsArray param then normalizeGrpName(value) in param else normalizeGrpName(value) is param

    #check for parameters in the URL so that this view can be bookmarked
    checkForStateParams = ->
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
    updateURL = (reload = false)->
        $state.transitionTo('showflow',{
            from: $scope.periods[$scope.slider.from/5].period
            to: $scope.periods[$scope.slider.to/5].period
            media: $scope.selectedMedia.map((m)->m.name)
            organisations: $scope.selectedOrganisations.map((o)->o.name)
            mediaGrp: $scope.selectedMediaGroups.map(normalizeGrpName)
            orgGrp: $scope.selectedOrganisationGroups.map(normalizeGrpName)
            pTypes: (v.type for v in $scope.typesText when v.checked)
        },{notify:reload, reload: reload})

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
        updateURL(true)
        window.scrollTo 0,0

    $scope.showFlowDetails = (link) ->
        params = pTypes: (v.type for v in $scope.typesText when v.checked)
        params.targeType = link.target.type
        params.sourceType = link.source.type
        if link.source.type is "o"
            params.source = link.source.name
        if link.source.type is "og"
            params.source = $scope.selectedOrganisationGroups.filter((g)->g.name is link.source.name)[0].members
        if link.source.type in ["og","mg"]
            params.sourceGrp = link.source.name
        if link.target.type in ["og","mg"]
            params.targetGrp = link.target.name
        switch link.target.type
            when 'm'
                params.target = link.target.name
            when 'mg'
                params.target = $scope.selectedMediaGroups.filter((g)->g.name is link.target.name)[0].members
        $state.go('showflowdetail',params)


    filterData = (data) ->
        if $scope.filter.trim().length > 2
            r = new RegExp ".*#{$scope.filter}.*","i"
            data.filter (d) -> r.test(d.organisation) or r.test(d.media)
        else
            data

    $scope.editLocalGroups = () -> $state.go('groupingLocal')
    $rootScope.$on('groupsChanged', -> loadGroups())

    loadFlowData = ->
        TPAService.filteredflows(parameters())
        .then (res) ->
            stopLoading()
            #console.log "Got result from Server: " + Date.now()
            $scope.error = null
            flowData = res.data
            for flowDatum in flowData
                if flowDatum.organisation is 'Other organisations'
                    flowDatum.organisation = gettextCatalog.getString flowDatum.organisation
                    flowDatum.otherOrgs = "oo"
                if flowDatum.media is 'Other media'
                    flowDatum.media = gettextCatalog.getString flowDatum.media
                    flowDatum.otherMedia = "om"
            $scope.flowData = flowData
            if dataPromise.promise.$$state.status == 1
                dataPromise = $q.defer()
                if $scope.dtInstance.reloadData
                    $scope.dtInstance.reloadData()
            dataPromise.resolve()
            $scope.flows = buildNodes filterData flowData
            #checkMaxLength(data)
        .catch (res) ->
            stopLoading()
            $scope.flowData = []
            $scope.flows = nodes:[],links:[]
            $scope.error = res.data
            #console.log "resolve dataPromise after exception"
            dataPromise.resolve()

    loadTimeLineDataAbsolute = ->
        deferred = $q.defer()
        TPAService.flowdetail(parametersTimeline())
        .then (res) ->
            $scope.data = res.data


    loadTimeLineDataRelative = ->
        TPAService.annualcomparison parametersTimeline()
        .then (res) ->
            $scope.annualComparisonData = res.data

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
            $q.all([loadFlowData(),loadTimeLineDataAbsolute(),loadTimeLineDataRelative()])
            .then stopLoading
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
        nodes = {}
        links = []
        sum = 0
        getNode = (name,nodeType) ->
            key = "#{name}-#{nodeType}"
            if not nodes[key]
                nodes[key] = {name: name, type: nodeType, index: Object.keys(nodes).length}
            nodes[key]
        addLink = (source,target,transfer) ->
            link = links.filter(
                (l)-> l.source is source.index and l.target is target.index)
            if link.length > 0
                link[0].value+= transfer.amount
                link[0].details[transfer.transferType]+=transfer.amount
            else
                newLink =
                    source: source.index
                    target: target.index
                    value: transfer.amount,
                    details:
                        2:0
                        4:0
                        31:0
                if source.type in ["oo","om"] or target.type in ["oo","om"]
                    newLink.linkType = "others"
                newLink.details[transfer.transferType]+=transfer.amount
                links.push(newLink)
        data.forEach (entry) ->
            sum+=entry.amount
            org = getNode(entry.organisation, entry.otherOrgs or "o")
            media = getNode(entry.media, entry.otherMedia or "m")
            orgGroups = $scope.selectedOrganisationGroups.filter((v)->org.name in v.members)
            mediaGroups = $scope.selectedMediaGroups.filter((v)->media.name in v.members)
            orgGroup = if orgGroups.length > 0 then getNode(orgGroups[0].name,"og")
            mediaGroup = if mediaGroups.length > 0 then getNode(mediaGroups[0].name,"mg")
            if orgGroup then addLink(org,orgGroup,entry)
            if mediaGroup then addLink(mediaGroup,media,entry)
            if orgGroup and mediaGroup then addLink(orgGroup,mediaGroup,entry)
            else if orgGroup then addLink(orgGroup,media,entry)
            else if mediaGroup then addLink(org,mediaGroup,entry)
            else addLink(org,media,entry)
        nodes = Object.keys(nodes).map((k)->nodes[k])
        links.forEach (l) ->
            l.type = Object.keys(l.details).filter((k)->l.details[k]>0).reduce(((a,b)->a+b),"")
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
            if $scope.dtInstance.reloadData
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
            $scope.allOrganisationGroups = res.data.map((g)->g.groupType='public';g)
                .concat(TPAService.getLocalGroups("org").map((g)->g.groupType='custom';g))
        mediaGroupsPromise = TPAService.getGroupings {type: 'media'}
        mediaGroupsPromise.then (res, err) ->
            if (err)
                console.error err
                return
            $scope.allMediaGroups = res.data.map((g)->g.groupType='public';g)
                .concat(TPAService.getLocalGroups("media").map((g)->g.groupType='custom';g))
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
            $scope.allOrganisations.forEach((o)->o.group="";o.groupType="")
            $scope.allMedia.forEach((o)->o.group="";o.groupType="")
            initSlider()
            stopLoading()
            deferred.resolve()
        else
            startLoading()
            $q.all([loadPeriods(),loadAllNames(),loadGroups(),loadEvents(),loadEventTags()])
            .then () ->
                stopLoading()
                if not stateParamsExist()
                    #no defined state so start loading default data
                    update()
                deferred.resolve()
        deferred.promise

    $scope.toggleRegion = (region) ->
        for event in $scope.events
            if event.region is region.name
                event.selected = region.selected
        $scope.updateEvents()

    $scope.toggleTag = (tag) ->
        for event in $scope.events
            if event.tags.indexOf(tag.name) isnt -1
                event.selected = tag.selected


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
                                <i class="fa fa-exclamation-triangle" aria-hidden="true"></i>&nbsp;Info
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

    selectionChanged = (config) -> (newValue, oldValue) ->
        return if newValue is oldValue
        if newValue.length < oldValue.length
            removedElement = oldValue.filter((o) -> o.name not in newValue.map((v)->v.name))[0]
            if removedElement.name in config.selectedGroups().map((g)->g.members).reduce(((a,b) -> a.concat(b)),[])
                config.setSelected(oldValue)
                showDialog config.removeMsg
                return
        if not $scope.isDetails
            updateURL()
            update()
        $scope.isDetails = false;


    #Since it is possible to have local and public groups with the same name
    #we need to be able to distinguish them
    normalizeGrpName = (v)->"#{if v.serverside then "S:" else ""}#{v.name}"

    handleRemovingGroup = (config) -> (newValue,oldValue) ->
        return if newValue is oldValue
        remainingGroupNames = newValue.map(normalizeGrpName)
        removedGroup = oldValue.filter((v)->normalizeGrpName(v) not in remainingGroupNames)[0]
        config.selected().filter((v)->v.name in removedGroup.members)
            .forEach((v)->v.group="";v.groupType="")
        config.setSelected(config.selected().filter((v)->
            v.name not in removedGroup.members
        ))
        #TODO remove if refactored everywhere
        $scope.organisationsInSelectedGroups =
            $scope.selectedOrganisationGroups.map((g)->g.members).reduce(((a,b) -> a.concat(b)),[])


    #config access to properties
    properties =
        org:
            all: ()->$scope.allOrganisations
            allGroups: ()->$scope.allOrganisationGroups
            selected: ()->$scope.selectedOrganisations
            selectedGroups: ()->$scope.selectedOrganisationGroups
            setSelected: (s) -> $scope.selectedOrganisations = s
            setSelectedGroups: (s) -> $scope.selectedOrganisationGroups = s
            localGroupName: () -> $scope.localOrgGroupName
            setLocalGroupName: (s)->$scope.localOrgGroupName=s
            type:'org'
            removeMsg: gettextCatalog.getString "You cannot remove this Organisation since it belongs to a selected group. Remove the group instead."
        media:
            all: ()->$scope.allMedia
            allGroups: ()->$scope.allMediaGroups
            selected: ()->$scope.selectedMedia
            selectedGroups: ()->$scope.selectedMediaGroups
            setSelected: (s) -> $scope.selectedMedia = s
            setSelectedGroups: (s) -> $scope.selectedMediaGroups = s
            localGroupName: ()-> $scope.localMediaGroupName
            setLocalGroupName: (s)->$scope.localMediaGroupName=s
            type:'media'
            removeMsg: gettextCatalog.getString "You cannot remove this Media since it belongs to a selected group. Remove the group instead"

    handleAddingGroup = (config) -> (newValue, oldValue) ->
        selectedMembers = oldValue.map((v)->v.members).reduce(((a,b)->a.concat(b)),[])
        oldGroupNames = oldValue.map(normalizeGrpName)
        newGroup = newValue.filter((v)->normalizeGrpName(v) not in oldGroupNames)[0]
        if newGroup.members.filter((v)->v in selectedMembers).length > 0
            showDialog gettextCatalog.getString """
                You cannot add this group, since some of its members are also members of already selected
                groups. This is not allowed. So please remove the other group first
            """
            config.setSelectedGroups(oldValue)
            forcedChange = true
            return
        membersToAdd = newGroup.members
            .map((m)->{name:m,group:newGroup.name,groupType:if newGroup.serverside then 'public' else 'custom'})
        membersOutsideNewGroup = config.selected().filter((v)->v.name not in newGroup.members)
        config.setSelected(membersOutsideNewGroup.concat(membersToAdd))

    selectedGroupsChanged = (config) -> (newValue, oldValue) ->
            return if newValue is oldValue
            if forcedChange
                forcedChange = false
                return
            newLength = if (typeof newValue isnt 'undefined') then newValue.length else 0
            oldLength = if (typeof oldValue isnt 'undefined') then oldValue.length else 0
            if newLength < oldLength
                handleRemovingGroup(config)(newValue, oldValue)
            else
                handleAddingGroup(config)(newValue, oldValue)

    createLocalGroup = (config) -> () ->
        if config.localGroupName in TPAService.getLocalGroups(config.type).map((g)->g.name)
            showDialog gettextCatalog.getString "Custom group could not be created since an local group with an equal name already exists"
            return
        groupedOrganisations = config.selectedGroups().map((g)->g.members).reduce(((a,b)->a.concat(b)),[])
        newMembers = config.selected().filter((o)->o.name not in groupedOrganisations)
        if newMembers.length is 0
            showDialog gettextCatalog.getString "Custom group could not be created because there are no ungrouped entries."
            return
        group = {
            type: config.type
            members: newMembers.map((m)->m.name)
            name: config.localGroupName()
            region: 'AT'
        }
        TPAService.saveLocalGroup group
        group.groupType = 'custom'
        config.allGroups().push group
        config.setSelectedGroups(config.selectedGroups().concat [group])
        newMembers.forEach((m)->m.group=group.name;m.groupType='custom')
        TPAService.saveState stateName,fieldsToStore, $scope
        config.setLocalGroupName("")


    $scope.createLocalOrgGroup = createLocalGroup(properties.org)

    $scope.createLocalMediaGroup = createLocalGroup(properties.media)

    $scope.organisationsInSelectedGroups = []
    $scope.mediaInSelectedGroups = []
    $scope.$watch 'selectedOrganisationGroups', selectedGroupsChanged(properties.org), true
    $scope.$watch 'selectedMediaGroups', selectedGroupsChanged(properties.media), true
    $scope.$watch 'selectedMedia', selectionChanged(properties.media), true
    $scope.$watch 'selectedOrganisations', selectionChanged(properties.org), true
    $scope.$watch('typesText',change,true)
]