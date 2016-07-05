'use strict';

#* jshint -W098 *#
angular.module 'mean.transparency'
.controller 'TransparencyController', ($scope, Global, Transparency, TPAService) ->
     $scope.global = Global
     $scope.package =
          name: 'transparency'

     change = (oldValue,newValue) ->
          console.log "Change: " + Date.now()
          update() if (oldValue isnt newValue)

     update = () ->
          console.log "udpate"

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
