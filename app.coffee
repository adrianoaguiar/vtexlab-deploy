express = require 'express'
require 'shelljs/global'
http = require 'http'
globule = require 'globule'

app = express()
app.use(express.json())
app.use(express.urlencoded())

# all environments
app.set "port", process.env.PORT or 3000

# Default configurations
config =
	port: process.env.PORT or 1338
	env: process.env.NODE_ENV or 'development'

# Appilication
validateHookSource = (req, res, next) ->
	try
		repo = req.body.repository
		if repo.name not in ['vtexlab', 'vtexlab-docs']
			res.send 401, "Unauthorized"
		else
			next()
	catch
		res.send 401, "Unauthorized"

validateHookBranch = (req, res, next) ->
	try
		branch = getBranch req
		if branch not in ['stable', 'development']
			res.send 202, "Branch is not \'master\' or \'development\'"
		else
			next()
	catch
		res.send 401, "Some error occur when try to verify branch-ref"

cloneRepository = (req, res, next) ->
	repo = req.body.repository
	branch = getBranch req

	if !test('-e', "#{branch}/#{repo.name}/")
		exec "pushd #{branch}/ && git clone https://github.com/vtex/#{repo.name}.git && popd", (code, output) ->
			 res.send 500, output if code isnt 0

			if branch is 'development'
				exec "pushd #{branch}/#{repo.name}/ && git checkout development && popd", (code, output) ->
					res.send 500, output if code isnt 0
					next()
			else
				next()
	else
		next()

pullRepository = (req, res, next) ->
	repo = req.body.repository
	branch = "#{getBranch(req)}/#{repo.name}/"

	exec "pushd #{branch} && git fetch --all && popd", (code, output) ->
		res.send 500, output if code isnt 0

		exec "pushd #{branch} && git reset --hard origin/master && popd", (code, output) ->
			res.send 500, output if code isnt 0
			next()

prepareEnviroment = (req, res, next) ->
	branch = getBranch req
	exec "sudo grunt --branch=#{branch}", (code, output) ->
		res.send 500, output if code isnt 0
		next()

buildSite = (req, res, next) ->
	repo = req.body.repository
	branch = "#{getBranch(req)}/vtexlab/"

	exec "pushd #{branch} && jekyll build && popd", (code, output) ->
		if code isnt 0
	      res.send 500, output
	    else
	      next()

uploadToS3 = (req, res, next) ->
	repo = req.body.repository
	branch = getBranch(req)
	deployPath = "#{branch}/vtexlab/_site/"
	bucket = getBucketName branch

	exec "s3cmd sync --delete-removed #{deployPath} s3://#{bucket}", (code, output) ->
		if code isnt 0
			res.send 500, output
		else
			res.send 200, output

getBucketName = (branch) ->
	if branch is 'development' then return process.env.S3_BUCKET_DEV
	if branch is 'stable' then return process.env.S3_BUCKET_STABLE

getBranch = (req) ->
	if req.body.ref is "refs/heads/develop" then return "development"
	if req.body.ref is "refs/heads/master" then return "stable"

app.get '/', (req, res) ->
  res.send """
	<h1>Works!</h1>
    """

app.post "/hooks",
	validateHookSource,
	validateHookBranch,
	cloneRepository,
	pullRepository,
	prepareEnviroment,
	buildSite,
	uploadToS3

http.createServer(app).listen app.get("port"), ->
	console.log "Express server listening on port " + app.get("port")
	return