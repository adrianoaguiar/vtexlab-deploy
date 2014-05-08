// Generated by CoffeeScript 1.7.1

/*
Module dependencies.
 */

(function() {
  var S3Deleter, S3Deployer, S3Lister, app, buildSite, cleanS3Bucket, client, cloneRepository, config, createDeleter, deployer, express, globule, http, knox, lister, prepareEnviroment, pullRepository, uploadToS3, validateHookSource, _;

  express = require('express');

  require('shelljs/global');

  http = require('http');

  knox = require('knox');

  _ = require('underscore');

  globule = require('globule');

  S3Deleter = require('s3-deleter');

  S3Deployer = require('deploy-s3');

  S3Lister = require('s3-lister');

  app = express();

  app.use(express.json());

  app.use(express.urlencoded());

  app.set("port", process.env.PORT || 3000);

  config = {
    port: process.env.PORT || 1338,
    env: process.env.NODE_ENV || 'development'
  };

  client = knox.createClient({
    key: process.env.S3_KEY,
    secret: process.env.S3_SECRET,
    bucket: process.env.S3_BUCKETNAME
  });

  deployer = new S3Deployer({}, client);

  lister = new S3Lister(client);

  validateHookSource = function(req, res, next) {
    var repo, _ref;
    try {
      repo = req.body.repository;
      if ((_ref = repo.name) !== 'vtexlab' && _ref !== 'vtexlab-docs' && _ref !== 'vtexlab-guide') {
        return res.send(401, "Unauthorized");
      } else {
        return next();
      }
    } catch (_error) {
      return res.send(401, "Unauthorized");
    }
  };

  cloneRepository = function(req, res, next) {
    var repo;
    repo = req.body.repository;
    if (!test('-e', repo.name)) {
      return exec("git clone https://github.com/vtex/" + repo.name + ".git", function(code, output) {
        if (code !== 0) {
          res.send(500, output);
        }
        return next();
      });
    } else {
      return next();
    }
  };

  pullRepository = function(req, res, next) {
    var repo;
    repo = req.body.repository;
    return exec("pushd " + repo.name + " && git fetch --all && popd", function(code, output) {
      if (code !== 0) {
        res.send(500, output);
      }
      return exec("pushd " + repo.name + " && git reset --hard origin/master && popd", function(code, output) {
        if (code !== 0) {
          res.send(500, output);
        }
        return next();
      });
    });
  };

  prepareEnviroment = function(req, res, next) {
    return exec('grunt', function(code, output) {
      if (code !== 0) {
        res.send(500, output);
      }
      return next();
    });
  };

  buildSite = function(req, res, next) {
    return exec("cd vtexlab/ && jekyll build && cd ..", function(code, output) {
      if (code !== 0) {
        return res.send(500, output);
      } else {
        return next();
      }
    });
  };

  cleanS3Bucket = function(req, res, next) {
    var deleter;
    deleter = createDeleter();
    deleter.on('error', function(err) {
      console.log('DELETE \'vtexlab-site\' FILES FAILED', err);
      return res.send(500, err);
    });
    deleter.on('finish', function() {
      console.log('CLEANUP \'vtexlab-site\' SUCCESSFULL');
      return next();
    });
    return lister.pipe(deleter);
  };

  uploadToS3 = function(req, res, next) {
    var deployPath, done, error, fail, fileArray, files, filteredFiles;
    deployPath = "vtexlab/_site/";
    files = globule.find(deployPath + "**");
    if (files.length === 0) {
      error = "No files sent: " + files;
      console.error(error);
      return res.send(400, error);
    }
    filteredFiles = _.filter(files, function(file) {
      if (test('-f', file)) {
        return file;
      }
    });
    fileArray = _.map(filteredFiles, function(f) {
      return {
        src: f,
        dest: f.replace(deployPath, "")
      };
    });
    console.log(fileArray);
    done = function() {
      console.log("UPLOAD SUCCESSFULL");
      return res.send(200, "Upload complete at vtexlab.s3.amazonaws.com");
    };
    fail = function(reason) {
      console.log("UPLOAD FAILED", reason);
      return res.send(500, reason.toString());
    };
    console.log("STARTING UPLOAD TO S3");
    return deployer.batchUploadFileArray(fileArray).then(done, fail, console.log);
  };

  createDeleter = function() {
    return new S3Deleter(client, {
      batchSize: 100
    });
  };

  app.get('/', function(req, res) {
    return res.send("<h1>Works!</h1>");
  });

  app.post("/hooks", validateHookSource, cloneRepository, pullRepository, prepareEnviroment, buildSite, cleanS3Bucket, uploadToS3);

  http.createServer(app).listen(app.get("port"), function() {
    console.log("Express server listening on port " + app.get("port"));
  });

}).call(this);
