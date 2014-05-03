module.exports = (grunt) ->
  pkg = grunt.file.readJSON 'package.json'

  # Project configuration.
  grunt.initConfig
      exec:
        install:
          command: 'bundle install'
        move:
          command: 'cp vtexlab/Gemfile Gemfile'
      clean:
        main: ['build', 'deploy']

      jekyll:
        build:
          options:
            src: "build/"
            dest: "deploy/"

      copy:
        main:
          files: [
            expand: true
            cwd: 'vtexlab/'
            src: ['**', '!Gruntfile.coffee']
            dest: 'build/'
          ]
        media:
          files: [
            expand: true
            cwd: 'vtexlab/'
            src: ['images/*.*']
            dest: 'build/'
          ]
        guides:
          files: [
            expand: true
            cwd: 'vtexlab-guide/'
            src: '**'
            dest: 'build/docs/'
          ]
        assets:
          expand: true
          cwd: 'build/_assets/javascripts/'
          src: '**'
          dest: 'build/assets/javascripts/'

      sass:
        dist:
          options:
            style: 'expanded'
            debugInfo: true
          files: [
            expand: true
            cwd: 'build/_assets/stylesheets'
            src: ['main.scss', 'post-list.scss', 'product.scss', 'post.scss', 'docs.scss']
            dest: 'build/assets/stylesheets'
            ext: '.css'
          ]

  grunt.loadNpmTasks name for name of pkg.devDependencies when name[0..5] is 'grunt-'
  grunt.registerTask 'default', ['clean', 'exec:move', 'exec:install', 'copy:main', 'copy:media', 'copy:guides', 'copy:assets', 'sass','jekyll']
