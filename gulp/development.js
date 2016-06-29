'use strict';

var gulp = require('gulp'),
  gulpLoadPlugins = require('gulp-load-plugins'),
  through = require('through'),
  gutil = require('gulp-util'),
  plugins = gulpLoadPlugins(),
  coffee = require('gulp-coffee'),
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

gulp.task('translations', function () {
  return gulp.src('packages/core/system/public/po/**/*.po')
      .pipe(gettext.compile({
        // options to pass to angular-gettext-tools...
        format: 'json'
      }))
      .pipe(gulp.dest('packages/core/system/public/gettext'));
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
  gulp.src(['packages/custom/transparency/node_modules/isteven-angular-multiselect/**/*']).pipe(gulp.dest('packages/custom/transparency/public/assets/lib/isteven-angular-multiselect'));
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
    nodeArgs: ['--debug'],
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
