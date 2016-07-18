'use strict';

#* jshint -W098 *#
angular.module 'mean.transparency'
.controller 'TransparencyController', ($scope, Global, Transparency, TPAService, gettextCatalog, $state) ->
     $scope.global = Global
     $scope.package =
          name: 'transparency'

     $scope.$on 'isoChanged', (event, data) ->
          $scope.federalState = gettextCatalog.getString(TPAService.staticData('findOneFederalState', data.iso)
          .name)
          $scope.sum = d3.format(",.0f")(data.sum) + " €"
          $scope.percent = d3.format(",.2f")(data.percent) + "%"
          $scope.$digest()
          return
     
     $scope.$on 'federalStateClicked', (event, data) ->
          window.scrollTo 0, 0
          $state.go 'showflow',
               {
                    from: $scope.periods[$scope.slider.from/5].period
                    to: $scope.periods[$scope.slider.to/5].period
                    fedState: data
                    pTypes: $scope.typesText.filter((t) -> t.checked).map (t) -> t.type
               },
               location: true
               inherit: false
               reload: true

     change = (oldValue,newValue) ->
          console.log "Change: " + Date.now()
          update() if (oldValue isnt newValue)


     parameters = ->
          params = {}
          params.from = $scope.periods[$scope.slider.from/5].period
          params.to = $scope.periods[$scope.slider.to/5].period
          types = (v.type for v in $scope.typesText when v.checked)
          (params.pType = types) if types.length > 0
          params

     update = () ->
          TPAService.federalstates parameters()
          .then (res) ->
               $scope.mapData = res.data

     $scope.mapData = {}

     $scope.slider =
          from: 0
          to: 0
          options:
               step:5
               floor:0
               onEnd: -> change(1,2)

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
          $scope.$watch('typesText',change,true)
          update()
