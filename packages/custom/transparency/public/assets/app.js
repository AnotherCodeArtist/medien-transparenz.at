'use strict';

/*
 * Defining the Package
 */
var Module = require('meanio').Module;

var Transparency = new Module('transparency');
console.log("========== SETTING UP Transparency ===========")
/*
 * All MEAN packages require registration
 * Dependency injection is used to define required modules
 */
Transparency.register(function(app, auth, database) {
  console.log("========== REGISTER Transparency ===========")
  //We enable routing. By default the Package Object is passed to the routes
  Transparency.routes(app, auth, database);

  //We are adding a link to the main menu for all authenticated users



  Transparency.menus.add({
    title: 'Overview',
    link: 'overview',
    menu: 'main'
  });


  Transparency.aggregateAsset('css','transparency.css');
  /*
   Transparency.aggregateAsset('css', '/packages/transparency/public/assets/lib/datatables/media/css/jquery.dataTables.css', {
   absolute: true
   });
   Transparency.aggregateAsset('css', '/packages/transparency/public/assets/lib/angular-datatables/dist/dataTables.bootstrap.css', {
   absolute: true
   });
   */
  /*
   Transparency.aggregateAsset('js', '/packages/transparency/public/assets/lib/d3/d3.js', {
   absolute: true
   });
   Transparency.aggregateAsset('js', '/packages/transparency/public/assets/lib/nvd3/nv.d3.js', {
   absolute: true
   });

   Transparency.aggregateAsset('css', '/packages/transparency/public/assets/lib/nvd3/nv.d3.css', {
   absolute: true
   });
   Transparency.aggregateAsset('js', '/packages/transparency/public/assets/lib/angularjs-nvd3-directives/dist/angularjs-nvd3-directives.js', {
   absolute: true
   });
   */
  Transparency.aggregateAsset('js', '../lib/ng-file-upload/angular-file-upload.js', {
    absolute: true
  });
  /*
   Transparency.aggregateAsset('js', '/packages/transparency/public/assets/lib/datatables/media/js/jquery.dataTables.js', {
   absolute: true
   });
   Transparency.aggregateAsset('js', '/packages/transparency/public/assets/lib/angular-datatables/dist/angular-datatables.js', {
   absolute: true
   });
   */
  Transparency.angularDependencies(['angularFileUpload','datatables','nvd3ChartDirectives']);

  /**
   //Uncomment to use. Requires meanio@0.3.7 or above
   // Save settings with callback
   // Use this for saving data from administration pages
   Transparency.settings({
        'someSetting': 'some value'
    }, function(err, settings) {
        //you now have the settings object
    });

   // Another save settings example this time with no callback
   // This writes over the last settings.
   Transparency.settings({
        'anotherSettings': 'some value'
    });

   // Get settings. Retrieves latest saved settigns
   Transparency.settings(function(err, settings) {
        //you now have the settings object
    });
   */
  console.log("========== DONE SETTING UP Transparency ===========")
  return Transparency;
});
