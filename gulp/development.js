'use strict';

var gulp = require('gulp'),
  gulpLoadPlugins = require('gulp-load-plugins'),
  through = require('through'),
  gutil = require('gulp-util'),
  plugins = gulpLoadPlugins(),
  coffee = require('gulp-coffee'),
  replace = require('gulp-replace'),
  paths = {
    js: ['./*.js', 'config/**/*.js', 'gulp/**/*.js', 'tools/**/*.js', 'packages/**/*.js', '!packages/**/node_modules/**', '!packages/**/assets/**/lib/**', '!packages/**/assets/**/js/**'],
    html: ['packages/**/*.html', '!packages/**/node_modules/**', '!packages/**/assets/**/lib/**'],
    css: ['packages/**/*.css', '!packages/**/node_modules/**', '!packages/**/assets/**/lib/**','!packages/core/**/public/assets/css/*.css'],
    less: ['packages/**/*.less', '!packages/**/_*.less', '!packages/**/node_modules/**', '!packages/**/assets/**/lib/**'],
    sass: ['packages/**/*.scss', '!packages/**/node_modules/**', '!packages/**/assets/**/lib/**'],
    coffee: ['packages/**/*.coffee', '!packages/**/node_modules/**', '!packages/**/assets/**/lib/**','!packages/custom/transparency/coffee/**/*.coffee'],
    coffee_transparency: ['!packages/**/node_modules/**','packages/custom/transparency/coffee/**/*.coffee','!packages/**/assets/**/lib/**'],
    coffee_tests: ['packages/custom/transparency/coffee/server/tests/**/*.coffee']
  };

/*var defaultTasks = ['clean', 'jshint', 'less', 'csslint', 'devServe', 'watch'];*/
var defaultTasks = ['coffee','coffee_transparency','clean', 'less', 'devServe', 'watch'];

var gettext = require('gulp-angular-gettext');

gulp.task('pot', function () {
  return gulp.src(['packages/custom/transparency/public/views**/*.html', 'packages/core/system/**/*.html',
    'packages/custom/transparency/public/**/*.js','!packages/custom/transparency/public/assets/**/*.js'])
      .pipe(gettext.extract('template.pot', {
        // options to pass to angular-gettext-tools...
      }))
      .pipe(gulp.dest('packages/core/system/public/po/'));
});
// Solution based on : https://github.com/gabegorelick/gulp-angular-gettext/issues/13#issuecomment-69728371
var extend = require('gulp-extend');
var wrap = require('gulp-wrap');
var rename = require('gulp-rename');

gulp.task('translations', function() {
  return gulp.src('packages/core/system/public/po/**/*.po') // Stream PO translation files.
      .pipe(gettext.compile({format: 'json'})) // Compile to json
      .pipe(extend('.tmp.json')) // use .json extension for gulp-wrap to load json content
      .pipe(wrap( // Build the translation module using gulp-wrap and lodash.template
          'angular.module(\'gettext\').run([\'gettextCatalog\', function (gettextCatalog) {\n' +
          '/* jshint -W100 */\n' +
          '<% var langs = Object.keys(contents); var i = langs.length; while (i--) {' +
          'var lang = langs[i]; var translations = contents[lang]; %>'+
          '  gettextCatalog.setStrings(\'<%= lang %>\', <%= JSON.stringify(translations, undefined, 2) %>);\n'+
          '<% }; %>' +
          '/* jshint +W100*/\n' +
          '}]);'))
      .pipe(rename('translations.js')) // Rename to final javascript filename
      .pipe(gulp.dest('packages/core/system/public/gettext')); // output to "src/scripts" directory
});

gulp.task('env:development', function () {
  process.env.NODE_ENV = 'development';
});

gulp.task('jshint', function () {
  return gulp.src(paths.js)
    .pipe(plugins.jshint())
    .pipe(plugins.jshint.reporter('jshint-stylish'))
    // .pipe(plugins.jshint.reporter('fail')) to avoid shutdown gulp by warnings
    .pipe(count('jshint', 'files lint free'));
});

gulp.task('csslint', function () {
  return gulp.src(paths.css)
    .pipe(plugins.csslint('.csslintrc'))
    .pipe(plugins.csslint.reporter())
    .pipe(count('csslint', 'files lint free'));
});

gulp.task('less', function() {
  return gulp.src(paths.less)
    .pipe(plugins.less())
    .pipe(gulp.dest('./packages'));
});

gulp.task('sass', function() {
  return gulp.src(paths.sass)
    .pipe(plugins.sass().on('error', plugins.sass.logError))
    .pipe(gulp.dest('./packages'));
});

gulp.task('devServe', ['env:development'], function () {
  gulp.src(['packages/custom/transparency/public/assets/lib/oi.select/dist/select.min.js'])
      .pipe(replace('templateUrl:"src/template.html"', 'templateUrl:"transparency/assets/lib/oi.select/src/template.html"'))
      .pipe(gulp.dest('packages/custom/transparency/public/assets/lib/oi.select/dist', {overwrite: true}));
  plugins.nodemon({
    script: 'server.js',
    ext: 'html js',
    env: { 'NODE_ENV': 'development' } ,
    ignore: [
      'node_modules/',
      'bower_components/',
      'logs/',
      'packages/*/*/public/assets/lib/',
      'packages/*/*/node_modules/',
      '.DS_Store', '**/.DS_Store',
      '.bower-*',
      '**/.bower-*',
      '**/tests'
    ],
    nodeArgs: ['--inspect'],
    stdout: false
  }).on('readable', function() {
    this.stdout.on('data', function(chunk) {
      if(/Mean app started/.test(chunk)) {
        setTimeout(function() { plugins.livereload.reload(); }, 500);
      }
      process.stdout.write(chunk);
    });
    this.stderr.pipe(process.stderr);
  });
});

gulp.task('coffee', function() {
  gulp.src(paths.coffee)
    .pipe(coffee({bare: true}).on('error', gutil.log))
    .pipe(gulp.dest('./packages'));
});

gulp.task('coffee_transparency', function() {
  gulp.src(paths.coffee_transparency)
      .pipe(coffee({bare: true}).on('error', gutil.log))
      .pipe(gulp.dest('./packages/custom/transparency/'));
});

gulp.task('watch', function () {
  plugins.livereload.listen({interval:500});
  gulp.watch(paths.coffee,['coffee']);
  gulp.watch(paths.coffee_tlog,['coffee_transparency']);
  gulp.watch(paths.js, ['jshint']);
  gulp.watch(paths.css, ['csslint']).on('change', plugins.livereload.changed);
  gulp.watch(paths.less, ['less']);
});

gulp.task('watch-mocha', function() {
  gulp.watch([paths.coffee_transparency,paths.coffee_tests], ['coffee_transparency','runMocha']);
});

function count(taskName, message) {
  var fileCount = 0;

  function countFiles(file) {
    fileCount++; // jshint ignore:line
  }

  function endStream() {
    gutil.log(gutil.colors.cyan(taskName + ': ') + fileCount + ' ' + message || 'files processed.');
    this.emit('end'); // jshint ignore:line
  }
  return through(countFiles, endStream);
}

gulp.task('development', defaultTasks);
