// Generated by CoffeeScript 1.9.0
(function() {
  var app, buildSite, cloneRepository, config, express, getBranch, getBucketName, globule, http, prepareEnviroment, pullRepository, uploadToS3, validateHookBranch, validateHookSource;

  express = require('express');

  require('shelljs/global');

  http = require('http');

  globule = require('globule');

  app = express();

  app.use(express.json());

  app.use(express.urlencoded());

  app.set("port", 80);

  config = {
    port: process.env.PORT || 1338,
    env: process.env.NODE_ENV || 'development'
  };

  validateHookSource = function(req, res, next) {
    var repo, _ref;
    try {
      repo = req.body.repository;
      if ((_ref = repo.name) !== 'vtexlab' && _ref !== 'vtexlab-docs') {
        return res.send(401, "Unauthorized");
      } else {
        return next();
      }
    } catch (_error) {
      return res.send(401, "Unauthorized");
    }
  };

  validateHookBranch = function(req, res, next) {
    var branch;
    try {
      branch = getBranch(req);
      if (branch !== 'stable' && branch !== 'development') {
        return res.send(202, "Branch is not \'master\' or \'development\'");
      } else {
        return next();
      }
    } catch (_error) {
      return res.send(401, "Some error occur when try to verify branch-ref");
    }
  };

  cloneRepository = function(req, res, next) {
    var branch, repo;
    repo = req.body.repository;
    branch = getBranch(req);
    if (!test('-e', branch + "/" + repo.name + "/")) {
      exec("pushd " + branch + "/ && git clone https://github.com/vtex/" + repo.name + ".git && popd", function(code, output) {
        if (code !== 0) {
          return res.send(500, output);
        }
      });
      if (branch === 'development') {
        return exec("pushd " + branch + "/" + repo.name + "/ && git checkout development && popd", function(code, output) {
          if (code !== 0) {
            res.send(500, output);
          }
          return next();
        });
      } else {
        return next();
      }
    } else {
      return next();
    }
  };

  pullRepository = function(req, res, next) {
    var branch, repo;
    repo = req.body.repository;
    branch = (getBranch(req)) + "/" + repo.name + "/";
    return exec("pushd " + branch + " && git fetch --all && popd", function(code, output) {
      if (code !== 0) {
        res.send(500, output);
      }
      return exec("pushd " + branch + " && git reset --hard origin/master && popd", function(code, output) {
        if (code !== 0) {
          res.send(500, output);
        }
        return next();
      });
    });
  };

  prepareEnviroment = function(req, res, next) {
    var branch;
    branch = getBranch(req);
    console.log("cheguei");
    return exec("grunt --branch=" + branch, function(code, output) {
      if (code !== 0) {
        res.send(500, output);
      }
      return next();
    });
  };

  buildSite = function(req, res, next) {
    var branch, repo;
    repo = req.body.repository;
    branch = (getBranch(req)) + "/vtexlab/";
    return exec("pushd " + branch + " && jekyll build && popd", function(code, output) {
      if (code !== 0) {
        res.send(500, output);
      } else {

      }
      return res.send(200);
    });
  };

  uploadToS3 = function(req, res, next) {
    var branch, bucket, deployPath, repo;
    repo = req.body.repository;
    branch = getBranch(req);
    deployPath = branch + "/vtexlab/_site/";
    bucket = getBucketName(branch);
    return exec("s3cmd sync --delete-removed " + deployPath + " s3://" + bucket, function(code, output) {
      if (code !== 0) {
        return res.send(500, output);
      } else {
        return res.send(200, output);
      }
    });
  };

  getBucketName = function(branch) {
    if (branch === 'development') {
      return process.env.S3_BUCKET_DEV;
    }
    if (branch === 'stable') {
      return process.env.S3_BUCKET_STABLE;
    }
  };

  getBranch = function(req) {
    if (req.body.ref === "refs/heads/develop") {
      return "development";
    }
    if (req.body.ref === "refs/heads/master") {
      return "stable";
    }
  };

  app.get('/', function(req, res) {
    return res.send("<h1>Works!</h1>");
  });

  app.post("/hooks", validateHookSource, validateHookBranch, cloneRepository, pullRepository, prepareEnviroment, buildSite);

  http.createServer(app).listen(app.get("port"), function() {
    console.log("Express server listening on port " + app.get("port"));
  });

}).call(this);
