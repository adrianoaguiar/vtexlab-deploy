
###
Module dependencies.
###

express = require 'express'
require 'shelljs/global'
http = require 'http'
knox = require 'knox'
_ = require 'underscore'
globule = require 'globule'

S3Deleter = require 's3-deleter'
S3Deployer = require 'deploy-s3'
S3Lister  = require 's3-lister'

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
		if repo.name not in ['vtexlab', 'vtexlab-docs', 'vtexlab-guide']
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
	exec "sudo grunt --branch=#{branch}"	, (code, output) ->
		res.send 500, output if code isnt 0
		next()

buildSite = (req, res, next) ->
	repo = req.body.repository
	branch = "#{getBranch(req)}/#{repo.name}/"

	exec "pushd #{branch} && jekyll build && popd", (code, output) ->
		if code isnt 0
	      res.send 500, output
	    else
	      next()

cleanS3Bucket = (req, res, next) ->
	branch = getBranch req
	client = createClient(getBucketName(branch))
	deleter = createDeleter(client)
	lister = createListener(client)

	deleter.on 'error', (err) ->
		console.log "DELETE \'#{branch}\' FILES FAILED", err
		res.send 500, err

	deleter.on 'finish', ->
		console.log "CLEANUP \'#{branch}\' SUCCESSFULL"
		next()

	lister.pipe deleter

uploadToS3 = (req, res, next) ->
	repo = req.body.repository
	branch = getBranch(req)
	deployPath = "#{branch}/#{repo.name}/_site/"

	files = globule.find(deployPath + "**")

	if files.length is 0
		error = "No files sent: " + files
		console.error error
		return res.send 400, error

	filteredFiles = _.filter files, (file) -> return file if test '-f', file
	fileArray = _.map filteredFiles, (f) -> src: f, dest: f.replace(deployPath,"")
	console.log fileArray

	done = ->
		console.log "UPLOAD SUCCESSFULL"
		res.send 200, "Upload complete at vtexlab.s3.amazonaws.com"

	fail = (reason) ->
		console.log "UPLOAD FAILED", reason
		res.send 500, reason.toString()

	console.log "STARTING UPLOAD TO S3"
	client = createClient(getBucketName(branch))
	deployer = createDeployer(client)

	deployer.batchUploadFileArray(fileArray).then done, fail, console.log

createDeployer = (client) ->
	return new S3Deployer({}, client)

createDeleter = (client) ->
	return new S3Deleter client, {batchSize: 100}

createClient = (bucketName) ->
	knox.createClient
		key: process.env.S3_KEY
		secret: process.env.S3_SECRET
		bucket: bucketName

createListener = (client) ->
	return new S3Lister client

getBucketName = (branch) ->
	console.log "getBucketName ", branch
	if branch is 'development' then return process.env.S3_BUCKET_DEV
	if branch is 'stable' then return process.env.S3_BUCKET_STABLE

getBranch = (req) ->
	if req.body.ref is "refs/heads/development" then return "development"
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
	cleanS3Bucket,
	uploadToS3

http.createServer(app).listen app.get("port"), ->
	console.log "Express server listening on port " + app.get("port")
	return