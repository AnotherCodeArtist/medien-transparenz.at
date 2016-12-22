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

  var icons = 'transparency/assets/img/icons/';

  //We are adding a link to the main menu for all authenticated users

  Transparency.menus.add({
    title: 'UPLOAD',
    link: 'add_report',
    roles: ['admin'],
    menu: 'admin',
    icon: icons + 'hard-drive-upload.png'
  });
  //Menu item for address-upload
  Transparency.menus.add({
    title: 'ORGANISATIONS',
    link: 'add_organisation',
    roles: ['admin'],
    menu: 'admin',
    icon: icons + 'hard-drive-upload.png'
  });
  //Menu item for address-upload
  Transparency.menus.add({
    title: 'ZIP',
    link: 'add_zipCode',
    roles: ['admin'],
    menu: 'admin',
    icon: icons + 'hard-drive-upload.png'
  });
  Transparency.menus.add({
    title: 'Overview',
    link: 'overview',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Top Player',
    link: 'top',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Money Flow',
    link: 'showflow',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Organisations',
    link: 'listOrgs',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });

  Transparency.menus.add({
    title: 'Media',
    link: 'listMedia',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });
  Transparency.menus.add({
    title: 'Events',
    link: 'events',
    roles: ['can manage events'],
    menu: 'main'
  });
    Transparency.menus.add({
        title: 'Grouping',
        link: 'grouping',
        roles: ['can manage grouping'],
        menu: 'main'
    });
  /*
  Transparency.menus.add({
    title: 'Impress',
    link: 'impress',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });*/
  Transparency.menus.add({
    title: 'About Us',
    link: 'about',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });

  Transparency.menus.add({
    title: 'Search',
    link: 'search',
    roles: ['authenticated', 'anonymous'],
    menu: 'main'
  });

  Transparency.aggregateAsset('css', 'transparency.css');
  Transparency.aggregateAsset('css', '../lib/datatables.net-bs/css/dataTables.bootstrap.css');
  Transparency.aggregateAsset('css', '../lib/datatables.net-buttons-bs/css/buttons.bootstrap.css');
  //Transparency.aggregateAsset('css', '../lib/datatables.net-dt/css/jquery.dataTables.css');
  //Transparency.aggregateAsset('css', '../lib/datatables.net-buttons-dt/css/buttons.bootstrap.css');
  Transparency.aggregateAsset('css', '../lib/angular-datatables/dist/plugins/bootstrap/datatables.bootstrap.min.css');
  Transparency.aggregateAsset('css', '../lib/nvd3/build/nv.d3.css');
  Transparency.aggregateAsset('css', '../lib/angularjs-slider/dist/rzslider.css',{weight:-2});
  Transparency.aggregateAsset('css', '../lib/ng-tags-input/ng-tags-input.min.css', {weight:-5})
  Transparency.aggregateAsset('css', '../lib/ng-tags-input/ng-tags-input.bootstrap.min.css', {weight:-4});
  Transparency.aggregateAsset('css', '../lib/oi.select/dist/select.min.css');
  Transparency.aggregateAsset('css', '../lib/intro.js/minified/introjs.min.css');
  Transparency.aggregateAsset('css', '../lib/angular-directives-general/demo/multiselect/style.css');
  Transparency.aggregateAsset('js', '../lib/ng-file-upload/ng-file-upload.js',{weight:-5});
  Transparency.aggregateAsset('js', '../lib/d3/d3.js',{weight:-4});
  Transparency.aggregateAsset('js', '../lib/intro.js/intro.js',{weight:-5});
  Transparency.aggregateAsset('js', '../lib/nvd3/build/nv.d3.js',{weight:-3});
  Transparency.aggregateAsset('js', '../lib/three.js/three.js',{global:true, weight:-8});
  Transparency.aggregateAsset('js', '../lib/topojson/topojson.js',{weight:-4});
  Transparency.aggregateAsset('js', '../lib/jszip/dist/jszip.js',{weight:-4});
  Transparency.aggregateAsset('js', '../lib/pdfmake/build/pdfmake.js',{weight:-4});
  Transparency.aggregateAsset('js', '../lib/turfjs/turf.min.js',{weight:-1});
  Transparency.aggregateAsset('js', '../js/TrackballControls.js',{global:true,weight:-3});
  Transparency.aggregateAsset('js', '../js/Detector.js',{global:true,weight:-3});
  Transparency.aggregateAsset('js', '../js/Projector.js',{global:true,weight:-3});
  Transparency.aggregateAsset('js', '../js/geo.js',{global:true,weight:-2});
  Transparency.aggregateAsset('js', '../lib/datatables.net/js/jquery.dataTables.js',{weight:-3});
  Transparency.aggregateAsset('js', '../lib/datatables.net-bs/js/dataTables.bootstrap.js',{weight:-2});
  //Transparency.aggregateAsset('js', '../lib/datatables-colvis/js/dataTables.colVis.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/datatables.net-buttons/js/dataTables.buttons.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/datatables.net-buttons-bs/js/buttons.bootstrap.js',{weight:+1});
  //Transparency.aggregateAsset('js', '../lib/datatables.net-buttons/js/dataTables.buttons.js',{weight:-2});
  //Transparency.aggregateAsset('js', '../lib/datatables.net-buttons/js/buttons.bootstrap.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/datatables.net-buttons/js/buttons.html5.js',{weight:-1});
  Transparency.aggregateAsset('js', '../lib/d3-plugins-sankey/sankey.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angular-datatables/dist/angular-datatables.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angularjs-slider/dist/rzslider.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angular-datatables/dist/plugins/buttons/angular-datatables.buttons.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angular-datatables/dist/plugins/bootstrap/angular-datatables.bootstrap.js',{weight:-2});
  Transparency.aggregateAsset('js', '../lib/angular-nvd3/dist/angular-nvd3.js',{weight:-1});
  Transparency.aggregateAsset('js', '../lib/ng-tags-input/ng-tags-input.min.js', {weight:-6});
  Transparency.aggregateAsset('js', '../lib/oi.select/dist/select-tpls.js',{global:true});
  //Transparency.aggregateAsset('js', '../lib/intro.js/minified/intro.min.js',{weight:-5});
  Transparency.aggregateAsset('js', '../lib/angular-intro.js/src/angular-intro.js',{weight:-1});
  Transparency.aggregateAsset('js', '../lib/angular-animate/angular-animate.js',{global:true});
  Transparency.aggregateAsset('js', '../lib/angular-directives-general/src/multiselect.js',{global:true, weight:-10});

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
  Transparency.angularDependencies(['gettext','ngFileUpload','nvd3','datatables','ui.bootstrap','datatables.buttons','datatables.bootstrap','rzModule','ngTagsInput', 'oi.select', 'ui.select', 'ngSanitize',  'angular-intro',  'ngAnimate', 'long2know']);  return Transparency;
});
