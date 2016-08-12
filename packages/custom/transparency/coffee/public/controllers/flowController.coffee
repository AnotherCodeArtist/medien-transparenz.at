'use strict'

app = angular.module 'mean.transparency'

app.filter('myDropdownFilter', ($sce) ->
    (label, query, item, options, element) ->
        if typeof item.region is "undefined"
            html = '<span class="label label-primary">Custom</span> ' + label
        else
            html = label
        $sce.trustAsHtml(html)
)

app.controller 'FlowCtrl',['$scope','TPAService','$q','$interval','$state','gettextCatalog', '$filter','DTOptionsBuilder', '$rootScope',
($scope,TPAService,$q,$interval,$state,gettextCatalog, $filter,DTOptionsBuilder,$rootScope) ->

    stateName = "flowState"
    fieldsToStore = ['slider','periods','typesText','selectedOrganisations','selectedMedia', 'allOrganisations', 'allMedia', 'selectedMediaGroups', 'selectedOrganisationGroups']
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

    $scope.mediaLabel = gettextCatalog.getString 'Media'
    $scope.organisationsLabel = gettextCatalog.getString 'Organisations'
    $scope.organisationGroupsLabel = gettextCatalog.getString 'Organisation groups'
    $scope.mediaGroupsLabel = gettextCatalog.getString 'Media groups'
    $scope.groupNameLabel = gettextCatalog.getString 'Group name'

    parameters = ->
        params = {}
        params.maxLength = $scope.maxNodes
        params.from = $scope.periods[$scope.slider.from/5].period
        params.to = $scope.periods[$scope.slider.to/5].period
        types = (v.type for v in $scope.typesText when v.checked)
        (params.pType = types) if types.length > 0
        (params.filter = $scope.filter) if $scope.filter.length >= 3
        ###
        if $scope.org
            params.name = $scope.org.name
            params.orgType = $scope.org.orgType
        ###
        params.media = $scope.selectedMedia.map (media) -> media.name
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
            if $state.params.orgType is 'media'
                $scope.selectedMedia = [{name: $state.params.name}]
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
        $scope.organisationGroupsLabel = gettextCatalog.getString 'Organisation groups'
        $scope.mediaGroupsLabel = gettextCatalog.getString 'Media groups'
        $scope.groupNameLabel = gettextCatalog.getString 'Group name'
        if $scope.organisationGroupError and $scope.organisationGroupError.length > 0
            $scope.organisationGroupError = gettextCatalog.getString "Group already exists. Please use another group name."
        if $scope.mediaGroupError and $scope.mediaGroupError.length > 0
            $scope.mediaGroupError = gettextCatalog.getString "Group already exists. Please use another group name."
        if $scope.organisationGroupSelectionError and $scope.organisationGroupSelectionError.length > 0
            $scope.organisationGroupSelectionError = gettextCatalog.getString "Group could not be selected because it contains an organisations, which is in an already selected group."
        if $scope.mediaGroupSelectionError and $scope.mediaGroupSelectionError.length > 0
            $scope.mediaGroupSelectionError = gettextCatalog.getString "Group could not be selected because it contains a media, which is in an already selected group."
        update()

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

    filterData = (data) ->
        if $scope.filter.trim().length > 2
            r = new RegExp ".*#{$scope.filter}.*","i"
            data.filter (d) -> r.test(d.organisation) or r.test(d.media)
        else
            data


    update = ->
        if (!$scope.selectedOrganisations or $scope.selectedOrganisations.length is 0) and (!$scope.selectedMedia or $scope.selectedMedia.length is 0)
            TPAService.top parameters()
            .then (res) ->

                $scope.selectedOrganisations = [{name: res.data.top[0].organisation}]
                return
            return

        console.log "Starting update: " + Date.now()
        startLoading()
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

    buildGroupNodes = (nodesNum) ->
        groupNodeMap = []
        organisationsInGroups = {}
        mediaInGroups = {}
        $scope.selectedOrganisationGroups.forEach (group) ->
            group.elements.forEach (org) ->
                organisationsInGroups[org] = group.groupName
            if not groupNodeMap[group.groupName]?
                groupNodeMap[group.groupName] =
                    index: nodesNum
                    type: 'og'
                nodesNum++
        $scope.selectedMediaGroups.forEach (group) ->
            group.elements.forEach (media) ->
                mediaInGroups[media] = group.groupName
            if not groupNodeMap[group.groupName]?
                groupNodeMap[group.groupName] =
                    index: nodesNum
                    type: 'mg'
                nodesNum++
        {
            groupNodeMap: groupNodeMap
            organisationsInGroups: organisationsInGroups
            mediaInGroups: mediaInGroups
        }

    buildNodes = (data) ->
        nodes = []
        links = []
        nodesNum = 0
        nodeMap = {}

        sum = 0

        groupNodes = buildGroupNodes nodesNum
        nodesNum += Object.keys(groupNodes.groupNodeMap).length
        angular.merge nodeMap, groupNodes.groupNodeMap

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

            link1 = {}
            link2 = {}
            link3 = {}
            #organisation and media are in group
            if typeof groupNodes.organisationsInGroups[entry.organisation] isnt "undefined" and typeof groupNodes.mediaInGroups[entry.media] isnt "undefined"

                for link in links
                    if Object.keys(link1).length isnt 0 and Object.keys(link2).length isnt 0 and Object.keys(link3).length isnt 0
                        break
                    if (Object.keys(link1).length is 0 and link.source is nodeMap[entry.organisation].index and link.target is nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index and link.type is entry.transferType)
                        link1 = link
                    else if (Object.keys(link2).length is 0 and link.source is nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index and link.target is nodeMap[groupNodes.mediaInGroups[entry.media]].index and link.type is entry.transferType)
                        link2 = link
                    else if (Object.keys(link3).length is 0 and link.source is nodeMap[groupNodes.mediaInGroups[entry.media]].index and link.target is nodeMap[entry.media].index and link.type is entry.transferType)
                        link3 = link

                if Object.keys(link1).length is 0
                    links.push(
                        source: nodeMap[entry.organisation].index
                        target: nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index
                        value: entry.amount
                        type: entry.transferType
                    )
                else
                    link1.value += entry.amount
                if Object.keys(link2).length is 0
                    links.push(
                        source: nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index
                        target: nodeMap[groupNodes.mediaInGroups[entry.media]].index
                        value: entry.amount
                        type: entry.transferType
                    )
                else
                    link2.value += entry.amount
                if Object.keys(link3).length is 0
                    links.push(
                        source: nodeMap[groupNodes.mediaInGroups[entry.media]].index
                        target: nodeMap[entry.media].index
                        value: entry.amount
                        type: entry.transferType
                    )
                else
                    link3.value += entry.amount
            #organisation is in group
            else if typeof groupNodes.organisationsInGroups[entry.organisation] isnt "undefined" and typeof groupNodes.mediaInGroups[entry.media] is "undefined"

                for link in links
                    if Object.keys(link1).length isnt 0 and Object.keys(link2).length isnt 0
                        break
                    if (Object.keys(link1).length is 0 and link.source is nodeMap[entry.organisation].index and link.target is nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index and link.type is entry.transferType)
                        link1 = link
                    else if (Object.keys(link2).length is 0 and link.source is nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index and link.target is nodeMap[entry.media].index and link.type is entry.transferType)
                        link2 = link
                if Object.keys(link1).length is 0
                    links.push(
                            source: nodeMap[entry.organisation].index
                            target: nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index
                            value: entry.amount
                            type: entry.transferType
                    )
                else
                    link1.value += entry.amount
                if Object.keys(link2).length is 0
                    links.push(
                            source: nodeMap[groupNodes.organisationsInGroups[entry.organisation]].index
                            target: nodeMap[entry.media].index
                            value: entry.amount
                            type: entry.transferType
                    )
                else
                    link2.value += entry.amount
            #media is in group
            else if typeof groupNodes.organisationsInGroups[entry.organisation] is "undefined" and typeof groupNodes.mediaInGroups[entry.media] isnt "undefined"
                for link in links
                    if Object.keys(link1).length isnt 0 and Object.keys(link2).length isnt 0
                        break
                    if (Object.keys(link1).length is 0 and link.source is nodeMap[entry.organisation].index and link.target is nodeMap[groupNodes.mediaInGroups[entry.media]].index and link.type is entry.transferType)
                        link1 = link
                    else if (Object.keys(link2).length is 0 and link.source is nodeMap[groupNodes.mediaInGroups[entry.media]].index and link.target is nodeMap[entry.media].index and link.type is entry.transferType)
                        link2 = link
                if Object.keys(link1).length is 0
                    links.push(
                        source: nodeMap[entry.organisation].index
                        target: nodeMap[groupNodes.mediaInGroups[entry.media]].index
                        value: entry.amount
                        type: entry.transferType
                    )
                else
                    link1.value += entry.amount
                if Object.keys(link2).length is 0
                    links.push(
                        source: nodeMap[groupNodes.mediaInGroups[entry.media]].index
                        target: nodeMap[entry.media].index
                        value: entry.amount
                        type: entry.transferType
                    )
                else
                    link2.value += entry.amount
            #nothing is in a group
            else
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

    $rootScope.$on '$stateChangeStart', ->
        TPAService.saveState stateName,fieldsToStore, $scope

    $scope.allOrganisationGroups = TPAService.getClientGroups 'OrganisationGroups'
    $scope.allMediaGroups = TPAService.getClientGroups 'MediaGroups'

    $q.all([pP]).then (res) ->
        stateParamsExist = false
        if $state.params
            for k,v of $state.params
                if typeof v isnt 'undefined'
                    stateParamsExist = true

        savedState = sessionStorage.getItem stateName
        if stateParamsExist
            checkForStateParams()
            update()
        else if savedState
            TPAService.restoreState stateName, fieldsToStore, $scope
            update()
        else
            startLoading()
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

                $scope.selectedOrganisations = [];
                $scope.selectedMedia = [];
                $scope.selectedMediaGroups = []
                $scope.selectedOrganisationGroups = []
                stopLoading()
                update()

        $scope.$watch 'selectedOrganisations', (newValue, oldValue) ->
            $scope.selectedOrganisationGroups.forEach (orgGrp) ->
                orgGrp.elements.forEach (org) ->
                    found = false
                    for organisation in $scope.selectedOrganisations
                        if organisation.name is org
                            found = true
                            break

                    if !found
                        $scope.selectedOrganisations = $scope.selectedOrganisations.concat [{name: org}]

            if not $scope.isDetails
                update()

        $scope.$watch 'selectedMedia', (newValue, oldValue) ->
            $scope.selectedMediaGroups.forEach (mediaGrp) ->
                mediaGrp.elements.forEach (med) ->
                    found = false
                    for media in $scope.selectedMedia
                        if media.name is med
                            found = true
                            break

                    if !found
                        $scope.selectedMedia = $scope.selectedMedia.concat [{name: med}]
            if not $scope.isDetails
                update()
            else
                $scope.isDetails = false;
        $scope.$watch 'selectedOrganisationGroups', (newValue, oldValue) ->
            if newValue.length > oldValue.length
                $scope.organisationGroupSelectionError = ""
                duplicateFound = false

                organisationsInGroups = []
                for grp in oldValue
                    organisationsInGroups = organisationsInGroups.concat grp.elements

                for element in newValue[newValue.length-1].elements
                    if organisationsInGroups.indexOf(element) isnt -1
                        duplicateFound = true
                        break

                if not duplicateFound
                    newValue[newValue.length-1].elements.forEach (org) ->
                        found = false
                        for organisation in $scope.selectedOrganisations
                            if organisation.name is org
                                found = true
                                break

                        if !found
                            $scope.selectedOrganisations = $scope.selectedOrganisations.concat [{name: org}]
                else
                    $scope.organisationGroupSelectionError = gettextCatalog.getString "Group could not be selected because it contains an organisations, which is in an already selected group."
                    $scope.selectedOrganisationGroups = oldValue

            update()
        $scope.$watch 'selectedMediaGroups', (newValue, oldValue) ->
            if newValue.length > oldValue.length
                $scope.mediaGroupSelectionError = ""
                duplicateFound = false

                mediaInGroups = []
                for grp in oldValue
                    mediaInGroups = mediaInGroups.concat grp.elements

                for element in newValue[newValue.length-1].elements
                    if mediaInGroups.indexOf(element) isnt -1
                        duplicateFound = true
                        break

                if not duplicateFound
                    newValue[newValue.length-1].elements.forEach (media) ->
                        found = false
                        for med in $scope.selectedMedia
                            if media.name is med
                                found = true
                                break

                        if !found
                            $scope.selectedMedia = $scope.selectedMedia.concat [{name: media}]
                else
                    $scope.mediaGroupSelectionError = gettextCatalog.getString "Group could not be selected because it contains a media, which is in an already selected group."
                    $scope.selectedMediaGroups = oldValue
            update()

        #$scope.$watch('slider.from',change,true)
        #$scope.$watch('slider.to',change,true)
        $scope.$watch('typesText',change,true)
        
    $scope.groupOrganisations = () ->
        $scope.organisationGroupError = ""
        existingGroups = TPAService.getClientGroups 'OrganisationGroups'
        groupmembers = []
        found = false
        for group in existingGroups
            if group.groupName is $scope.organisationGroupName
                found = true
                break

        organisationsInGroups = []
        for group in $scope.selectedOrganisationGroups
            organisationsInGroups = organisationsInGroups.concat group.elements

        $scope.selectedOrganisations.map((org) -> org.name).forEach (org) ->
            if organisationsInGroups.indexOf(org) is - 1
                groupmembers.push org

        if not found and groupmembers.length > 0
            groupName = $scope.organisationGroupName
            elements = groupmembers
            TPAService.saveClientGroup 'OrganisationGroups', groupName, elements
            $scope.organisationGroupName = ""
            $scope.allOrganisationGroups = TPAService.getClientGroups 'OrganisationGroups'
            array = $scope.selectedOrganisationGroups.concat [{
                groupName: groupName
                elements: elements
            }]
            $scope.selectedOrganisationGroups = array
        else
            $scope.organisationGroupError = gettextCatalog.getString "Group could not be created. Either a group with the entered group name already exists or there are no elements that are not already in groups."

    $scope.groupMedia = () ->
        $scope.mediaGroupError = ""
        existingGroups = TPAService.getClientGroups 'MediaGroups'
        found = false
        for group in existingGroups
            if group.groupName is $scope.mediaGroupName
                found = true
                break

        mediaInGroups = []
        groupMembers = []
        for group in $scope.selectedMediaGroups
            mediaInGroups = mediaInGroups.concat group.elements

        $scope.selectedMediaGroups.map((med) -> med.name).forEach (med) ->
            if mediaInGroups.indexOf(med) is - 1
                groupMembers.push med

        if not found and groupMembers.length > 0
            groupName = $scope.mediaGroupName
            elements = groupMembers
            TPAService.saveClientGroup 'MediaGroups', $scope.mediaGroupName, $scope.selectedMedia.map (media) -> media.name
            $scope.mediaGroupName = ""
            $scope.allMediaGroups = TPAService.getClientGroups 'MediaGroups'
            array = $scope.selectedMediaGroups.concat [{
                groupName: groupName
                elements: elements
            }]
            $scope.selectedMediaGroups = array
        else
            $scope.mediaGroupError = gettextCatalog.getString "Group could not be created. Either a group with the entered group name already exists or there are no elements that are not already in groups."
]