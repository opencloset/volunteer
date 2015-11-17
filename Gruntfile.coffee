module.exports = (grunt) ->
  'use strict'

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON('package.json')

    # Task configuration.
    jekyll:
      options:
        config: '_config.yml'
      github:
        options:
          raw: 'github: true'

    htmlmin:
      dist:
        options:
          collapseWhitespace: true
          conservativeCollapse: true
          minifyCSS: true
          minifyJS: true
          removeAttributeQuotes: true
          removeComments: true
        expand: true
        cwd: '_gh_pages'
        dest: '_gh_pages'
        src: [
          '**/*.html',
          '!examples/**/*.html'
        ]

  require('load-grunt-tasks')(grunt, { scope: 'devDependencies' })
  require('time-grunt')(grunt)

  # Default task.
  grunt.registerTask('default', ['jekyll:github', 'htmlmin'])
