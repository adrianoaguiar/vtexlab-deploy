module.exports = (grunt) ->
  pkg = grunt.file.readJSON 'package.json'
  branch = grunt.option 'branch'

  # Project configuration.
  grunt.initConfig
      exec:
        install:
          command: 'bundle install'
        move:
          command: "cp  #{branch}/vtexlab/Gemfile Gemfile"
      
      copy:
        guides:
          files: [
            expand: true
            cwd: 'vtexlab-guide/'
            src: '**'
            dest: "#{branch}/vtexlab/docs/"
          ]
        docs:
          files: [
            expand: true
            cwd: 'vtexlab-docs/'
            src: '**'
            dest: "#{branch}/vtexlab-docs/"
          ]
        assets:
          expand: true
          cwd: "#{branch}/vtexlab/_assets/javascripts/"
          src: '**'
          dest: "#{branch}/vtexlab/assets/javascripts/"

      sass:
        dist:
          options:
            style: 'expanded'
            debugInfo: true
          files: [
            expand: true
            cwd: "#{branch}/vtexlab/_assets/stylesheets"
            src: ['main.scss', 'post-list.scss', 'product.scss', 'post.scss', 'docs.scss']
            dest: "#{branch}/vtexlab/assets/stylesheets"
            ext: '.css'
          ]

  grunt.loadNpmTasks name for name of pkg.devDependencies when name[0..5] is 'grunt-'
  grunt.registerTask 'default', ['exec:move', 'exec:install', 'copy:guides', 'copy:docs', 'copy:assets', 'sass']
