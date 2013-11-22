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
          sourceMap: false # create sourcemaps
          bare: true  # don't add global wrapper
        files: [
          dest: appPath('js/oky.js')
          # order matters
          # should really be using a module loader instead
          src: [
            'oky',
            'okyviews',
          ].map (filename) -> srcPath('coffeescripts/'+filename+'.coffee')
        ] 
      compileExamples: 
        options: 
          join: false # concat then compile into single file
          sourceMap: false # create sourcemaps
          bare: true  # don't add global wrapper
        expand: true,
        flatten: true,
        cwd: 'examples',
        src: ['*.coffee'],
        dest: 'examples/',
        ext: '.js'
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
            'underscore.string',
            'backbone',
            'handlebars',
            'jslider',
          ].map (filename) -> libPath('js/'+filename+'.js')
        ]
      ratchet: 
        files: [
          # build ratchet css
          src: srcPath('css/ratchet/*.css')
          dest: appPath('css/ratchet.custom.css')
        ]
    watch: 
      coffee: 
        files: [srcPath('coffeescripts/*.coffee')]
        tasks: ['coffee:compile']
        options: spawn: false
      less: 
        files: [srcPath('less/*.less')]
        tasks: ['less:compile']
        options: spawn: false
      handlebars: 
        files: [srcPath('templates/*.hbs')]
        tasks: ['handlebars:compile']
        options: spawn: false
      examples: 
        files: ['examples/*.coffee']
        tasks: ['coffee:compileExamples']
        options: spawn: false
    'http-server': 
      dev:
        port: 8080,
        host: 'localhost',

        showDir : true,
        autoIndex: true,
        defaultExt: 'html',

        # wait or not for the process to finish
        runInBAckground: false  

  # Project configuration.
  grunt.initConfig(gruntConfig)

  # Load plugins for handlebars, coffeescript and concat tasks.
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-handlebars')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-contrib-concat')
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-http-server')

  # Default task(s).
  grunt.registerTask 'default', [
    'coffee',
    'handlebars',
    'less',
    'concat'
  ]

  # run server
  grunt.registerTask 'run', ['http-server:dev']

  # examples
  grunt.registerTask 'examples', ['coffee:compileExamples','run']

  # build frameowrk
  grunt.registerTask 'build', [
    'coffee:compile',
    'handlebars:compile',
    'less:compile',
    'concat:ratchet',
    'concat:jslibs',
  ]
