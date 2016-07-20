'use strict'
app = angular.module 'mean.transparency'

app.controller 'GroupingController', ['$scope', 'TPAService', 'gettextCatalog', ($scope, TPAService, gettextCatalog) ->

    uniqueArray = (array) ->
        unique = []
        unique.push value for value in array when value not in unique
        unique


    resetGroup = ->
        $scope.group = {}
        $scope.selection = {}
        $scope.group.members = []
        $scope.group.isActive = true;

    translate = ->
        $scope.translate_GroupTypeOrg = gettextCatalog.getString("Group for organisations")
        $scope.translate_GroupTypeMedia = gettextCatalog.getString("Group for media")
        $scope.translate_selectionOwnerPlaceholder = gettextCatalog.getString("Group owner")
        $scope.translate_selectionMember = gettextCatalog.getString("Add member to group")
        $scope.translate_Nationwide = gettextCatalog.getString("Nationwide")
        $scope.translate_withinFederalState = gettextCatalog.getString("Within federal state")
        $scope.translate_EnableGroup = gettextCatalog.getString("Enable Group")
        $scope.translate_DisableGroup = gettextCatalog.getString("Disable Group")

    getPossibleGroupMembers = ->
    # clear selections and previous values
        $scope.selection = []
        $scope.group.members = []
        $scope.group.selectedGroupOwner = ""
        $scope.group.selectedMember = ""
    # load the selection
        TPAService.getPossibleGroupMembers
            orgType: $scope.group.type
        .then (res) ->
            $scope.selection = res.data
        .catch (err) -> $scope.error = "Could not load selection!"

    # saves the member in array
    addToGroup =  ->
            if $scope.group.selectedMember.name
                $scope.group.members.push $scope.group.selectedMember

    # Pre select region based on member selection
    checkGroupRegion = ->
        $scope.enableFederalSelection = false;
        federalStatesOfGroup = (member.federalState for member in $scope.group.members)
        uniqueFederalStatesOfGroup = uniqueArray(federalStatesOfGroup)
        if uniqueFederalStatesOfGroup.length > 1
            $scope.group.region = 'AT'
        else if uniqueFederalStatesOfGroup.length is 1
            $scope.group.region = uniqueFederalStatesOfGroup[0]
            if uniqueFederalStatesOfGroup[0] is 'AT-9' #Vienna - federal or nationwide?
                $scope.enableFederalSelection = true;
        else
            $scope.group.region = ""

    # Remove selection from grop based on index of array
    $scope.removeGroupMember = (index) ->
        $scope.group.members.splice(index,1)
        $scope.group.selectedMember = ""

    $scope.cancel = ->
        resetGroup()

    #save group
    $scope.createGroup = ->
        # remove not needed data
        $scope.group.members = (member.name for member in $scope.group.members)
        console.log("Group to save: " + JSON.stringify($scope.group))


    resetGroup()

    translate()

    $scope.$on 'gettextLanguageChanged', translate
    $scope.$watch('group.type', getPossibleGroupMembers, true)
    $scope.$watch('group.selectedMember', addToGroup, true)
    $scope.$watch('group.members', checkGroupRegion, true)
]