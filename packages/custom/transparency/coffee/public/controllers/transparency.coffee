'use strict';

#* jshint -W098 *#
angular.module 'mean.transparency'
.controller 'TransparencyController', ($scope, Global, Transparency, TPAService, gettextCatalog, $state, $rootScope, $q, $uibModal, $timeout ) ->
     $scope.global = Global
     $scope.package =
          name: 'transparency'
     $scope.typesText = []

     stateName = "index"
     fieldsToStore = ['slider','periods','typesText', 'orgTypes', 'orgTypeSelection']

     $scope.showSettings = false

     $scope.$on 'isoChanged', (event, data) ->
          $scope.federalState = gettextCatalog.getString(TPAService.staticData('findOneFederalState', data.iso)
          .name)
          $scope.sum = data.sum.toLocaleString($rootScope.language,{minimumFractionDigits:0,maximumFractionDigits:0})+" €"
          $scope.percent = d3.format(",.2f")(data.percent) + "%"
          $scope.$digest()
          return

     $scope.$on 'federalStateClicked', (event, data) ->
          $scope.selectedFederalState = {iso: data}
          $scope.orgType = 'org'

          dummyScope = {rank: 10}
          TPAService.restoreState 'topState', ['slider','periods','typesText', 'selectedFederalState', 'orgType', 'rank'], dummyScope
          dummyScope.slider = $scope.slider
          dummyScope.periods = $scope.periods
          dummyScope.typesText = $scope.typesText
          dummyScope.selectedFederalState = $scope.selectedFederalState
          dummyScope.orgType = $scope.orgType
          TPAService.saveState 'topState', ['slider','periods','typesText', 'selectedFederalState', 'orgType','rank'], dummyScope
          window.scrollTo 0, 0
          $state.go 'top',
               {
               },
               location: true
               inherit: false
               reload: true

     $scope.showSettingsDialog = ->
         parent = $scope
         $uibModal.open(
              templateUrl: 'transparency/views/mapSettingsDialog.html'
              scope: $scope
              size: 'lg'
              controller: ($scope, $uibModalInstance) ->
                   $scope.close = ->
                        $scope.$parent.orgTypeSelection = $scope.orgTypeSelection
                        $uibModalInstance.close()
                   current = $scope.slider.options.draggableRangeOnly
                   $timeout (-> $scope.slider.options.draggableRangeOnly = !current), 100
                   $timeout (-> $scope.slider.options.draggableRangeOnly = current), 120
         )

     $scope.getTotal = ->
          $scope.mapData.reduce(((acc,val)->acc+val.amount), 0).toLocaleString()

     $scope.getFrom = ->
         if $scope.periods && $scope.periods.length > 0
              "Q#{$scope.periods[$scope.slider.from/5].quarter}/#{$scope.periods[$scope.slider.from/5].year}"
         else ""
     $scope.getTo = ->
         if $scope.periods && $scope.periods.length > 0
              "Q#{$scope.periods[$scope.slider.to/5].quarter}/#{$scope.periods[$scope.slider.to/5].year}"
         else ""

     change = (oldValue,newValue) ->
          console.log "Change: " + Date.now()
          update() if (oldValue isnt newValue)


     parameters = ->
          params = {}
          params.from = $scope.periods[$scope.slider.from/5].period
          params.to = $scope.periods[$scope.slider.to/5].period
          types = (v.type for v in $scope.typesText when v.checked)
          (params.pType = types) if types.length > 0
          params.orgTypes = (o.value for o in $scope.orgTypes when o.value in $scope.orgTypeSelection)
          #TEST #params.orgTypes = ["city", "chamber"]
          params

     update = () ->
          TPAService.federalstates parameters()
          .then (res) ->
               $scope.mapData = res.data

     $scope.orgTypes = []
     $scope.orgTypeSelection = []
     $scope.mapData = []
     $scope.periods = []
     $scope.slider =
          from: 0
          to: 0
          options:
               step:5
               floor:0
               onEnd: -> change(1,2)
               translate: (value) -> $scope.periods.map((p) -> "#{p.year}/Q#{p.quarter}")[value/5]
               draggableRangeOnly: false

     translate = ->
          $scope.typesText.forEach (t) -> t.text = gettextCatalog.getString TPAService.decodeType t.type
          $scope.orgTypes.forEach (o) -> o.name = gettextCatalog.getString(o.value)

     $scope.$on 'gettextLanguageChanged', translate

     $rootScope.$on '$stateChangeStart', (event,toState) ->
          if toState.name isnt 'map'
               TPAService.saveState stateName,fieldsToStore,$scope

     registerWatchers = () ->
          $scope.$watch('typesText',change,true)
          $scope.$watch('orgTypes',change,true)
          $scope.$watch('orgTypeSelection',change,true)

     $scope.selectedTypes = -> $scope.typesText.filter((t) -> t.checked).map (t) -> t.type


     savedState = sessionStorage.getItem stateName

     if savedState
          TPAService.restoreState stateName, fieldsToStore, $scope
          registerWatchers()
          update()
     else
          $scope.slider =
               from: 0
               to: 0
               options:
                    step:5
                    floor:0
                    onEnd: -> change(1,2)
          orgTypePromise = TPAService.organisationTypes()
          .then (res) ->
               for orgTypeObject in res.data
                    $scope.orgTypes.push(name: gettextCatalog.getString(orgTypeObject.type), value: orgTypeObject.type)
                    $scope.orgTypeSelection.push(orgTypeObject.type)

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
               registerWatchers()
          $q.all([pP,orgTypePromise])
               .then => update()
