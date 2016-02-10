'use strict';

/*
 * Defining the Package
 */
var Module = require('meanio').Module;

var Transparency = new Module('transparency');

/*
 * All MEAN packages require registration
 * Dependency injection is used to define required modules
 */
Transparency.register(function(app, auth, database) {

  //We enable routing. By default the Package Object is passed to the routes
  Transparency.routes(app, auth, database);

  //We are adding a link to the main menu for all authenticated users

  Transparency.menus.add({
    title: 'Upload Report',
    link: 'add_report',
    roles: ['authenticated'],
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Overview',
    link: 'overview',
    //roles: ['authenticated'],
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Top Player',
    link: 'top',
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Money Flow',
    link: 'showflow',
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Organisations',
    link: 'listOrgs',
    menu: 'main'
  });

  Transparency.menus.add({
    title: 'Media',
    link: 'listMedia',
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Impress',
    link: 'impress',
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Search',
    link: 'search',
    menu: 'main'
  });


  Transparency.aggregateAsset('css', 'transparency.css');
  Transparency.aggregateAsset('css', '../lib/datatables/media/css/jquery.dataTables.css');
  Transparency.aggregateAsset('css', '../lib/nvd3/nv.d3.css');
  Transparency.aggregateAsset('js', '../lib/ng-file-upload/ng-file-upload.js',{weight:-5});
  Transparency.aggregateAsset('js', '../lib/d3/d3.js',{weight:-4});
  Transparency.aggregateAsset('js', '../lib/nvd3/nv.d3.js',{weight:-3});
  Transparency.aggregateAsset('js', '../lib/datatables/media/js/jquery.dataTables.js',{weight:-3});
  Transparency.aggregateAsset('js', '../lib/d3-plugins-sankey/sankey.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angular-datatables/dist/angular-datatables.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angular-datatables/dist/plugins/buttons/angular-datatables.buttons.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angularjs-nvd3-directives/dist/angularjs-nvd3-directives.js',{weight:-1});

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
  //Transparency.angularDependencies(['angularFileUpload','datatables','gettext']);
  Transparency.angularDependencies(['gettext','ngFileUpload','legendDirectives',
    'nvd3ChartDirectives','datatables','ui.bootstrap','datatables.buttons']);
  return Transparency;
});
