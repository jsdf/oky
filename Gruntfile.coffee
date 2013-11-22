path = require('path')
exec = require('child_process').exec

libPath = (pathSuffix) -> path.join('applib', pathSuffix)
srcPath = (pathSuffix) -> path.join('appsrc', pathSuffix)
appPath = (pathSuffix) -> path.join('dist', pathSuffix)


module.exports = (grunt) -> 
  gruntConfig = 
    pkg: grunt.file.readJSON('package.json')
    coffee: 
      compile: 
        options: 
          join: true # concat then compile into single file
          sourceMap: true # create sourcemaps
          bare: true  # don't add global wrapper
        files: [
          dest: appPath('js/app.js')
          # order matters
          # should really be using a module loader instead
          src: [
            'oky',
            'okyviews',
          ].map((filename) -> srcPath('coffeescripts/'+filename+'.coffee'))
        ]
    handlebars: 
      compile: 
        options: 
          processName: (name) -> path.basename(name, '.hbs') #template func names from filenames 
          namespace: 'JST'
        files: [
            src: srcPath('templates/*.hbs')
            dest: appPath('js/templates.js')
        ]
    less: 
      compile: 
        files: [
            src: srcPath('less/*.less')
            dest: appPath('css/oky.css')
        ]
    concat:
      jslibs: 
        files: [
          dest: appPath('js/libs.js')
          # order matters
          src: [
            'modernizr.custom.15848',
            'zepto.1.0.1',
            'zepto.fx_methods',
            'zepto.data',
            'zepto-jquery',
            'lodash',
            # 'lodash.custom',
            'underscore.string',
            'backbone',
            # 'backbone_super',
            'handlebars',
            # 'junior',
            # 'cordova-2.5.0',
            'jslider',
          ].map((filename) -> libPath('js/'+filename+'.js'))
        ]
      ratchet: 
        files: [
          # build ratchet css
          src: srcPath('css/ratchet/*.css')
          dest: appPath('css/ratchet.custom.css')
        ]
  

  # Project configuration.
  grunt.initConfig(gruntConfig)

  # Load plugins for handlebars, coffeescript and concat tasks.
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-handlebars')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-contrib-concat')

  # Default task(s).
  grunt.registerTask('default', [
    'coffee',
    'handlebars',
    'less',
    'concat'
  ])

  # build app resources
  grunt.registerTask('build', [
    'coffee:compile',
    'handlebars:compile',
    'less:compile',
    'concat:ratchet',
    'concat:jslibs',
  ])
