fs = require('fs')
path = require('path')

module.exports = (app, options = {}) ->
	options.strict ?= true
	options.overwriteRender ?= true
	options.log ?= false
	options.root ?= app.set('controllers') || process.cwd() + '/controllers'
	options.sharedFolder ?= 'shared'
	
	new Controllers app, options

class Controllers
	constructor: (app, @options) ->
		self = this
		@_controllers = {}
		
		# Pre-load all the controllers... one time hit so done sync
		this.executeOnDirectory @options.root, (file) ->
			ext = path.extname file
			if ext == '.js' || ext == '.coffee'
				reduced = file.replace ext, ''
				controller = path.basename reduced
				self._controllers[controller] = require reduced
				if self.options.log
					console.log "Controller '#{controller}' has been loaded"
				
		# We are off to hijack the req.app.routes._route
		# which is the point of contact of all our get/post/pull/etc methods.
		# We will let the usual chain occur till the very last
		# callback, and then we will make sure the controller and action
		# are both defined, and then load up that controller/action.
		# We have already cached the controllers to reduce require calls
		originalRoute = app.routes._route
		app.routes._route = (method, path, defaults, callbacks...) ->
			# We might not have defaults
			if 'function' == typeof defaults
				callbacks.push defaults
				defaults = null
				
			if callbacks.length == 0
				callbacks.push (req, res) ->
			
			defaults ?= { }
			holder = { }	
			
			# overwrite the callbacks to use this info
			newCallbacks = (self.overwriteCallback c, holder) for c in callbacks
			result = originalRoute.call app.routes, method, path, newCallbacks
			
			# Extend the routing by adding defaults
			holder.route = newRoute = result.routes[method][result.routes[method].length - 1]
			for defkey, defvalue of defaults
				key = self.getKeyInRoute defkey, newRoute
				if key?
					key.default = defvalue
				else
					# controller/action is a special case and we need to save it
					if defkey == 'controller' or defkey == 'action'
						newRoute[defkey] = defvalue	
			
			# If we have a key for controller/action that means they could be anything
			for key in newRoute.keys when key.name == 'controller' or key.name == 'action'
				newRoute[key.name] = '*'
			
			return result
		
		# Add all the corresponding helpers
		this.addHelpers app
	
	addReqHelpers: (req, res) ->
		self = this
		req.executeController = (controller, action, next) ->
			if not controller? or not action?
				throw new Error("executeController needs the controller and action specified")
				
			# If we pass a next switch the controller/action back to our current one
			if next?
				currentC = req.controller
				currentA = req.action
				nextFunc = next
				next = ->
					req.controller = currentC
					req.action = currentA
					nextFunc.apply this, arguments
			
			req.controller = controller
			req.action = action
			self._controllers[controller][action] req, res, next
		
	addHelpers: (app) ->
		self = this
		
		app.dynamicHelpers {
			controller: (req, res) ->
				req.controller
				
			action: (req, res) ->
				req.action
		
			getUrl: (req, res) ->
				(controller, action, other, query) ->
					if not action? or 'object' == typeof action
						query = other
						other = action
						action = controller
						controller = null
						
					controller ?= req.controller
					other ?= {}
					other.controller = controller
					other.action = action
					query ?= {}
						
					if not action? or not controller?
						throw new Error("getUrl needs at minimum an action defined, but also takes a controller")
				
					for route in app.routes.routes.get 
						if self.isMatchingPath other, route
							# We have found a route that matches
							# We are stepping through the keys backwards so that if
							# any keys are found the rest MUST be displayed
							# (that is... optional keys cannot be blank)
							hasReplaced = false
							result = route.path
							for i in [route.keys.length-1..0]
								key = route.keys[i]
								def = key.default ? ''
								replacement = other[key.name] ? def
								if hasReplaced and replacement == ''
									throw new Error("The optional parameter '#{key.name}' is required for this getUrl call as an parameter further down the path has been specified")
								else
									if not hasReplaced
							  		if (not key.optional or replacement != def) and 
							  			hasReplaced = true
							  		else
							  			replacement = ''
								
								# Do the replacement
								regExp = new RegExp ":#{key.name}(\\?)?"
								result = result.replace regExp, replacement
								
							# Remove multiple slashes
							result = result.replace /\/+/g, '/'
								
							# Remove trailing slash... unless we are at root
							if result != '/'
								result = result.replace /\/+$/, ''
							
							# Add in query strings
							first = true
							for key, value of query
								if first
									first = false
									result = result + '?' + key
									if value? and value != ''
										result = result + '=' + value
								else
									result = result + '&' + key
									if value? and value != ''
										result = result + '=' + value
								
							return result
								
					throw new Error("Route could not be found that matches getUrl parameters, make sure to specify a valid controller, action and required parameters")
		}
			
	getKeyInRoute: (name, route) ->
		for key in route.keys when key.name == name
			return key
		return null
		
	isMatchingPath: (object, route) ->
		# First check the controller and action
		if route.controller != '*' and route.controller != object.controller
			return false
			
		if route.action != '*' and route.action != object.action
			return false
	
		# This is checking that all items in the object match with a key
		for key, value of object when key != 'controller' and key != 'action'
			if not (@getKeyInRoute key, route)?
				return false
				
		# This is checking all (required) keys have an object value
		for key in route.keys when key.name != 'controller' and key.name != 'action'
			if not key.optional and not object[key]?
				return false
		
		return true
		
	overwriteCallback: (callback, routeHolder) ->
		self = this
		options = @options
		(req, resp, next) ->
			# Call the normal callback
			callback req, resp, next
	
			# Add helpers
			self.addReqHelpers req, resp
			
			# set the current route
			route = routeHolder.route
			
			# Go through our keys and if they have a default and the param value
			# is not set make sure it is
			for key in route.keys when not req.params[key.name]? and key.default?
				req.params[key.name] = key.default
			
			# Grab our current controller/action either from the route or use defaults
			req.controller = req.params.controller ? route.controller
			req.action = req.params.action ? route.action
			
			if options.log
				console.log 'Controller: ' + req.controller
				console.log 'Action: ' + req.action
			
			if options.strict
				if not req.controller?
					throw new Error("Is in strict mode and no controller specified")
				if not req.action?
					throw new Error("Is in strict mode and no action specified")
				
			if req.controller? and req.action?
				# We have a controller and an action - lets overwrite the res.render
				# command so that we do not have to specify view names
				if options.overwriteRender
					self.overwriteRender req, resp
			
				# Find the controller
				controller = self._controllers[req.controller]
				if not controller?
					if options.log
						console.log "Controller '#{req.controller}' could not be found"
					next 'route'
					return
				
				# Execute the action
				action = controller[req.action]
				if not action?
					if options.log
						console.log "Action '#{req.action}' could not be found on controller '#{req.controller}' "
					next 'route'
					return
					
				# Execute the controller with a nothing followup action
				action req, resp, next
			else
				if options.log
					console.log 'Controller or action was not specified, no action was called'
	
	overwriteRender: (req, resp) ->
		self = this
		original = resp.render
		# This is the root dir the render method uses
		root = resp.app.set('views') || process.cwd() + '/views'

		resp.render = (view, opts, fn, parent, sub) ->
			# Allow for view to be empty
			if 'object' == typeof view || 'function' == typeof view
				sub = parent
				parent = fn
				fn = opts
				opts = view
				view = null
				
			# The view defaults to the action
			view ?= req.action
				
			# Set the root directory as the controller directory
			# if that doesnt work, try the shared directory
			# disable hints because it comes up funny like
			hasHints = resp.app.enabled 'hints'
			resp.app.disable 'hints'
				
			result = null
			secondResult = null
			
			reset = ->
				if hasHints
					resp.app.enable 'hints'
			
			finalPass = (err, err2, str) ->
				reset()
					
				if err?
					err = err + '\r\n\r\n' + err2
				
				if fn?
					fn err, str
				else
					if err?
						req.next err
					else
						resp.send str
			
			secondRender = (err, str) ->
				if err?
					# If the first render failed failed try getting view from 'shared'
					secondResult = original.call resp, self.options.sharedFolder + '/' + view, opts, ((err2, str2) -> finalPass(err2, err, str2)), parent, sub
				else
					reset()
				
					if fn?
						fn err, str
					else
						resp.send str
				
			result = original.call resp, req.controller + '/' + view, opts, secondRender, parent, sub
			if secondResult?
				result = secondResult

			reset()
			return result
			
	executeOnDirectory: (dir, action) ->
		fs.readdirSync(dir).forEach (file) ->
			localpath = dir + '/' + file
			stat = fs.statSync localpath
			if stat and stat.isDirectory()
				self.executeOnDirectory localpath, action
			else
				action localpath
