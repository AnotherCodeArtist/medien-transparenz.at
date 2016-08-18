'use strict'
app = angular.module 'mean.transparency'

app.controller 'GroupingController', ['$scope', 'TPAService', 'gettextCatalog', ($scope, TPAService, gettextCatalog) ->
    countGroupings = ->
        TPAService.countGroupings {}
        .then(
            (result) ->
                $scope.count = parseInt result.data.count
        )
        .catch (
            (err) ->
                $scope.error = err
        )
    #list groupings
    listGroupings = ->
        prepareGrouping = (grouping) ->
            if grouping.type is 'org'
                grouping.type = gettextCatalog.getString('Organisation')
            else
                grouping.type = gettextCatalog.getString('Media')
            if grouping.isActive
                grouping.isActive = gettextCatalog.getString('Yes')
            else
                grouping.isActive = gettextCatalog.getString('No')

            grouping.region = gettextCatalog.getString(TPAService.staticData('findOneFederalState', grouping.region).name)
            $scope.groupings.push grouping


        TPAService.getGroupings {page: parseInt($scope.page - 1), size: parseInt($scope.size)}
        .then(
            (res) ->
                $scope.groupings = []
                prepareGrouping data for data in res.data
        )
        .catch (
            (err) ->
                $scope.error = err
        )
    translate = ->
        $scope.translate_GroupTypeOrg = gettextCatalog.getString("Group for organisations")
        $scope.translate_GroupTypeMedia = gettextCatalog.getString("Group for media")
        $scope.translate_selectionOwnerPlaceholder = gettextCatalog.getString("Group owner")
        $scope.translate_selectionMember = gettextCatalog.getString("Add member to group")
        $scope.translate_Nationwide = gettextCatalog.getString("Nationwide")
        $scope.translate_withinFederalState = gettextCatalog.getString("Within federal state")
        $scope.translate_EnableGroup = gettextCatalog.getString("Enable Group")
        $scope.translate_DisableGroup = gettextCatalog.getString("Disable Group")
        listGroupings()

    resetGroup = ->
        $scope.group = {}
        $scope.selection = {}
        $scope.group.members = []
        $scope.group.isActive = true;
        $scope.edit = false;
        $scope.editId = null;
        $scope.error = ""

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

    # saves the member in array
    addToGroup = ->
        if $scope.group.selectedMember.name
            membernames = (member.name for member in $scope.group.members )
            $scope.group.members.push $scope.group.selectedMember if $scope.group.selectedMember.name not in membernames

    # Pre select region based on member selection
    checkGroupRegion = ->
        uniqueArray = (array) ->
            unique = []
            unique.push value for value in array when value not in unique
            unique
        $scope.enableFederalSelection = false;
        if not $scope.edit
            federalStatesOfGroup = (member.federalState for member in $scope.group.members)
            uniqueFederalStatesOfGroup = uniqueArray(federalStatesOfGroup)
            if uniqueFederalStatesOfGroup.length > 1 or $scope.group.type is 'media'
                $scope.group.region = 'AT'
            else if uniqueFederalStatesOfGroup.length is 1
                $scope.group.region = uniqueFederalStatesOfGroup[0]
                if uniqueFederalStatesOfGroup[0] is 'AT-9' #Vienna - federal or nationwide?
                    $scope.enableFederalSelection = true;
            else
                $scope.group.region = ""


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

    #save group
    $scope.createGroup = ->
        TPAService.createGrouping groupToGrouping($scope.group)
        .then(
            (saved) ->
                resetGroup()
                countGroupings()
                listGroupings()
        )
        .catch (err) -> $scope.error = err
    # edit grouping
    $scope.editGrouping = (id) ->
        TPAService.getGroupings {id: id, page: $scope.page - 1, size: $scope.size}
        .then (
            (result) ->
                foundGrouping = result.data[0]
                $scope.edit = true
                $scope.groupingID = id
                $scope.group.members = []
                $scope.group.name = foundGrouping.name
                $scope.group.type = foundGrouping.type
                $scope.group.isActive = foundGrouping.isActive
                if foundGrouping.region is 'AT'
                    $scope.group.region = 'AT'
                else
                    $scope.group.region = foundGrouping.region
                if foundGrouping.owner?
                    $scope.group.selectedGroupOwner.name = foundGrouping.owner
                for member in foundGrouping.members
                    $scope.group.members.push {name: member}
        )
        .catch (
            (err) ->
                $scope.error = err
        )

    #Remove grouping
    $scope.removeGrouping = (id, name) ->
        deleteString = gettextCatalog.getString("Delete")
        if confirm(deleteString + "? " + name)
            TPAService.deleteGroupings {id: id}
            .then(
                (removed) ->
                    countGroupings()
                    listGroupings()
            )
            .catch (err) -> $scope.error = err

    # update grouping
    $scope.updateGrouping = ->
        TPAService.updateGrouping groupToGrouping($scope.group)
        .then(
            (updated) ->
                resetGroup()
                listGroupings()
        )
        .catch (err) -> $scope.error = err

    $scope.page =  1
    $scope.size =  5
    $scope.sizes = [5, 10, 20, 50, 100]
    $scope.count = 0

    $scope.groupings = []
    countGroupings()
    translate()
    resetGroup()


    $scope.$on 'gettextLanguageChanged', translate
    $scope.$watch('group.type', getPossibleGroupMembers, true)
    $scope.$watch('group.selectedMember', addToGroup, true)
    $scope.$watch('group.members', checkGroupRegion, true)
    $scope.$watch('size', listGroupings, true)
    $scope.$watch('page', listGroupings, true)
]