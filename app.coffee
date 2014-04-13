
###
Module dependencies.
###

express = require 'express'
require 'shelljs/global'
http = require 'http'
knox = require 'knox'
_ = require 'underscore'
globule = require 'globule'

S3Deployer = require 'deploy-s3'

app = express()
app.use(express.json())
app.use(express.urlencoded())

# all environments
app.set "port", process.env.PORT or 3000

# Default configurations
config =
	port: process.env.PORT or 1338
	env: process.env.NODE_ENV or 'development'

client = knox.createClient
	key: process.env.S3_KEY
	secret: process.env.S3_SECRET
	bucket: process.env.S3_BUCKETNAME

deployer = new S3Deployer({}, client)

# Appilication
validateHookSource = (req, res, next) ->
	try
		repo = JSON.parse(req.body.payload).repository
		res.send 401, "Unauthorized" if repo.name not in ['vtexlab', 'vtexlab-docs', 'vtexlab-guide']
	catch
		res.send 401, "Unauthorized"

	next()

cloneRepository = (req, res, next) ->
	repo = JSON.parse(req.body.payload).repository
	if !test('-e', repo.name)
		exec "git clone https://github.com/vtex/#{repo.name}.git", (code, output) ->
			 res.send 500, output if code isnt 0
			 next()
	else
		next()

pullRepository = (req, res, next) ->
	repo = JSON.parse(req.body.payload).repository
	exec "cd #{repo.name} && git fetch --all", (code, output) ->
		res.send 500, output if code isnt 0

		exec "cd #{repo.name} && git reset --hard origin/master", (code, output) ->
			res.send 500, output if code isnt 0
			next()

buildSite = (req, res, next) ->
	exec 'grunt', (code, output) ->
		res.send 500, output if code isnt 0
		next()

uploadToS3 = (req, res, next) ->
	deployPath = "deploy/"
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
	deployer.batchUploadFileArray(fileArray).then done, fail, console.log

app.get '/', (req, res) ->
  res.send """
	<h1>Works!</h1>
    """

app.post "/hooks",
	validateHookSource,
	cloneRepository,
	pullRepository,
	buildSite,
	uploadToS3

http.createServer(app).listen app.get("port"), ->
	console.log "Express server listening on port " + app.get("port")
	return