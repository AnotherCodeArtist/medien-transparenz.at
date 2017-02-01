'use strict'
app = angular.module 'mean.transparency'

app.controller 'GroupingController', ['$scope', 'TPAService', 'gettextCatalog','$q','$state', ($scope, TPAService, gettextCatalog, $q, $state) ->
    countGroupings = ->
        if mode is 'public'
            p = TPAService.countGroupings {}
            p.then((result) -> $scope.count = parseInt result.data.count)
            .catch ((err) ->$scope.error = err)
            p
         else
            deferred = $q.defer()
            $scope.count = TPAService.getLocalGroups('org').concat(TPAService.getLocalGroups('media')).length
            deferred.resolve($scope.count)
            deferred.promise
    $scope.allMedia = []
    $scope.allOrganisations = []
    mode = if $state.current.name is 'gouping' then 'global' else 'local'
    #mode = if $state.params.mode is 'local' then 'local' else 'global'
    #mode = 'local'
    orgList = []
    $scope.loadOptions = (name) ->
        if name.length >= 3
            if orgList.length == 0
                orgList = getAll($scope.group.type).filter((m)-> m.name.toLowerCase().indexOf(name.toLowerCase()) > -1)
        else
            orgList = []
        orgList

    loadAllNames = () ->
        deferred = $q.defer()
        TPAService.search({name: ' '})
        .then (res) ->
            $scope.mediaLabel = gettextCatalog.getString('Media')
            $scope.organisationLabel = gettextCatalog.getString('Organisation')
            $scope.organisationGroupLabel = gettextCatalog.getString('Organisation Group')
            $scope.mediaGroupLabel = gettextCatalog.getString('Media Group')
            $scope.allOrganisations = res.data.org
            $scope.allMedia = res.data.media
            deferred.resolve()
        deferred.promise

    allGroups = []
    loadAllStoredGroups = ->
        deferred = $q.defer()
        if mode is 'global'
            TPAService.getGroupings({page: 0, size: 100000})
                .then((res)->allGroups = res.data;deferred.resolve())
                .catch((err)->deferred.reject(err))
        else
            allGroups = TPAService.getLocalGroups('org').concat(TPAService.getLocalGroups('media'))
            deferred.resolve()
        deferred.promise

    loadStoredGroups = ->
        $q.all([loadAllStoredGroups(),
            if mode is 'global'
                TPAService.getGroupings {page: parseInt($scope.page - 1), size: parseInt($scope.size)}
            else
                page = parseInt($scope.page)
                size = parseInt($scope.size)
                deferred = $q.defer()
                deferred.resolve(
                    data: TPAService.getLocalGroups('org').concat(TPAService.getLocalGroups('media')).slice((page-1)*size,(page-1)*size+size)
                )
                deferred.promise
        ]).then((r)->r[1])

    #list groupings
    listGroupings = ->
        prepareGrouping = (grouping) ->
            if grouping.type is 'org'
                grouping.typeText = gettextCatalog.getString('Organisation')
            else
                grouping.typeText = gettextCatalog.getString('Media')
            if grouping.isActive
                grouping.isActiveText = gettextCatalog.getString('Yes')
            else
                grouping.isActiveText = gettextCatalog.getString('No')
                grouping.isActive = false
            grouping.regionText = gettextCatalog.getString(TPAService.staticData('findOneFederalState', grouping.region).name)
            grouping
        deferred = $q.defer()
        loadStoredGroups()
        .then(
            (res) ->
                $scope.groupings = (prepareGrouping data for data in res.data)
                deferred.resolve()
        )
        .catch (
            (err) ->
                $scope.error = err
                deferred.reject(err)
        )
        deferred.promise
    translate = ->
        $scope.translate_GroupTypeOrg = gettextCatalog.getString("Group for organisations")
        $scope.translate_GroupTypeMedia = gettextCatalog.getString("Group for media")
        $scope.translate_selectionOwnerPlaceholder = gettextCatalog.getString("Group owner")
        $scope.translate_selectionMember = gettextCatalog.getString("Add member to group")
        $scope.translate_Nationwide = gettextCatalog.getString("Nationwide")
        $scope.translate_withinFederalState = gettextCatalog.getString("Within federal state")
        $scope.translate_EnableGroup = gettextCatalog.getString("Enable Group")
        $scope.translate_DisableGroup = gettextCatalog.getString("Disable Group")


    resetGroup = ->
        $scope.group = {type:'media',isActive:false,scope:'national'}
        $scope.selection = {}
        $scope.group.members = []
        $scope.group.isActive = true;
        $scope.edit = false;
        $scope.editId = null;
        $scope.error = ""
    ###
    getPossibleGroupMembers = ->
         # clear selections and previous values
        $scope.selection = []
        if not $scope.edit
            $scope.group.members = []
            $scope.group.selectedGroupOwner = {}
            $scope.group.selectedMember = ""
        # load the selection
        TPAService.getPossibleGroupMembers
            orgType: $scope.group.type
        .then (res) ->
            $scope.selection = res.data
        .catch (err) -> $scope.error = "Could not load selection!"
    ###

    # saves the member in array
    addToGroup = (newValue,oldValue)->
        return if newValue is oldValue or not newValue?
        if $scope.group.selectedMember.name
            membernames = (member.name for member in $scope.group.members )
            $scope.group.members.push $scope.group.selectedMember if $scope.group.selectedMember.name not in membernames

    # Pre select region based on member selection
    checkGroupRegion = (newValue,oldValue)->
        return if newValue == oldValue
        $scope.enableFederalSelection = false;
        #if not $scope.edit
        federalStates = $scope.group.members.map((m)->m.federalState)
            .reduce(((a,b)->
                a.push(b) if b not in a
                a),
            [])
        if federalStates.length > 1 or $scope.group.type is 'media'
            $scope.group.region = 'AT'
            $scope.group.scope = 'national'
            $scope.enableFederalSelection = false;
        else if federalStates.length is 1
            $scope.group.region = federalStates[0]
            $scope.enableFederalSelection = true;
        else
            $scope.group.scope = null
            $scope.group.region = "AT"
            $scope.group.scope = "national"
    $scope.group2Federalstate = (group) ->
        if group?
            console.log "group2Federalstate: #{group}"
            gettextCatalog.getString(TPAService.staticData('findOneFederalState', group).name)
        else ""

    groupToGrouping = (formGroup) ->
        newGrouping = {}
        newGrouping.name = formGroup.name
        newGrouping.type = formGroup.type
        newGrouping.region = formGroup.region
        newGrouping.members = (member.name for member in formGroup.members)
        newGrouping.isActive = formGroup.isActive
        if formGroup.selectedGroupOwner
            newGrouping.owner = formGroup.selectedGroupOwner.name
        if $scope.edit && $scope.groupingID
            newGrouping._id = $scope.groupingID;
        #console.log("Group to be saved:  " + JSON.stringify(newGrouping))
        newGrouping

    $scope.resetOwner = ->
        $scope.group.selectedGroupOwner = {}

    # Remove selection from grop based on index of array
    $scope.removeGroupMember = (index) ->
        $scope.group.members.splice(index, 1)
        $scope.group.selectedMember = ""

    $scope.cancel = ->
        resetGroup()

    $scope.newGroup = resetGroup

    #save group
    $scope.createGroup = ->
        if mode is 'global'
            TPAService.createGrouping groupToGrouping($scope.group)
            .then(
                (saved) ->
                    resetGroup()
                    countGroupings()
                    listGroupings()
            )
            .catch (err) -> $scope.error = err
        else
            TPAService.saveLocalGroup(groupToGrouping($scope.group))
            resetGroup()
            countGroupings()
            listGroupings()
        TPAService.clearState()

    getAll = (type) ->
        switch type
            when 'org' then $scope.allOrganisations
            when 'media' then $scope.allMedia
            else []

    $scope.organisations = () -> if $scope.edit then [] else allGroups.filter((v)-> v.type is $scope.group.type)

    # edit grouping
    $scope.editGrouping = (currentGroup) ->
        $scope.edit = true
        $scope.groupingID = currentGroup.id
        $scope.group.members = getAll(currentGroup.type).filter((m)->m.name in currentGroup.members)
        $scope.group.name = currentGroup.name
        $scope.group.type = currentGroup.type
        $scope.group.isActive = currentGroup.isActive
        $scope.group.region = currentGroup.region
        $scope.group.scope = if currentGroup.region is "AT" then "national" else "federal"
        if currentGroup.owner?
            $scope.group.selectedGroupOwner = getAll(currentGroup.type).filter((m)->m.name is currentGroup.owner)[0]


    #Remove grouping
    $scope.removeGrouping = (group) ->
        deleteString = gettextCatalog.getString("Delete")
        if confirm(deleteString + "? " + group.name)
            if mode is "global"
                TPAService.deleteGroupings {id: group.id}
                .then(
                    (removed) ->
                        countGroupings()
                        listGroupings()
                )
                .catch (err) -> $scope.error = err
            else
                TPAService.removeLocalGroup(group)
                countGroupings()
                listGroupings()
            TPAService.clearState()



    # update grouping
    $scope.updateGrouping = ->
        if mode is 'global'
            TPAService.updateGrouping groupToGrouping($scope.group)
            .then(
                (updated) ->
                    resetGroup()
                    listGroupings()
            )
            .catch (err) -> $scope.error = err
        else
            TPAService.updateLocalGroup(groupToGrouping($scope.group))
            resetGroup()
            listGroupings()
        TPAService.clearState()


    $scope.page =  1
    $scope.size =  5
    $scope.sizes = [5, 10, 20, 50, 100]
    $scope.count = 0

    $scope.groupings = []
    translate()
    resetGroup()
    init = -> $q.all([loadAllNames(),listGroupings(),countGroupings()])
    init()

    groupTypeChanged = (newType,oldType) ->
        return if newType is oldType
        if not $scope.edit
            $scope.group.members = []
            $scope.group.selectedGroupOwner = []

    changeOwner = (newValue,oldValue)->
        return if newValue is oldValue or not newValue?
        if newValue.name? and newValue.name not in $scope.group.members.map((g)->g.name)
            $scope.group.members = $scope.group.members.splice(0).concat([newValue])

    $scope.$on 'gettextLanguageChanged', translate
    $scope.$watch('group.type', groupTypeChanged, true)
    $scope.$watch('group.selectedMember', addToGroup, true)
    $scope.$watch('group.members', checkGroupRegion, true)
    $scope.$watch('group.selectedGroupOwner', changeOwner)
    $scope.$watch('size', listGroupings, true)
    $scope.$watch('page', listGroupings, true)
]