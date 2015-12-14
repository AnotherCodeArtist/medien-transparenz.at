'use strict';

#* jshint -W098 *#
angular.module 'mean.transparency'
.controller 'TransparencyController', ($scope, Global, Transparency) ->
    $scope.global = Global
    $scope.package =
      name: 'transparency'
