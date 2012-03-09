# Controllers

A simple mvc framework and route extender for Express.

### Installation

```bash
$ npm install controllers
```

### Usage

After setting all your middleware in Express, call the controllers method to initialise.

```
express = require 'express'
controllers = require 'controllers'

app = express.createServer()
app.use(express.static(__dirname + '/public'));

# Make sure all your app.use statements have been called
controllers app, options
```

Your folder system should now look like the following:

```
site
 |-> controllers
 |   |-> home.js (or coffee, if you have overwritten the require calls)
 |   |-> blog.js
 |-> views
		 | -> home
		 |    |-> index.jade (these are your views, use whatever renderer you want)
		 |    |-> welcome.jade
		 | -> blog
		 |    | -> index.jade
		 | -> shared
		 			| -> layout.jade
```

Controllers are called depending on your routing, and the render call is overwritten to access the folder with the same name as the controller, falling back to the shared folder if needed.

### Routing

When routing a controller and action must be defined, controllers extends the routing in Express to allow for default values

```
# app.get 'route', defaults, middleware...
app.get '/blogPage', { controller: 'blog', action: 'index' }, middleware
app.get '/:controller?/:action?/:id?', { controller: 'home', action: 'index' }, middleware
```

The above routing will route the following paths:

```
'/' -> Routes to the controller 'home' and runs the method 'index'
'/blogPage' -> Routes to the controller 'blog' and runs the method 'index'
'/home/welcome/1' -> Routes to the controller 'home' and runs the method 'welcome', with the 'id' param set to 1
```
### What does a controller look like?

The controller actions follow the normal convention of Express, taking the request, response and next arguments:

```
module.exports.index = (req, res, next) ->
	res.render()
			
module.exports.welcome = (req, res, next) ->
	id = req.param.id ?? 0
	res.partial { id: id }
```

The render does not take an argument as the view for this action is automatically searched for in at 'views/home/index' and if that fails falls back to 'views/shared/index'.

### Helpers

There are a number of useful calls available in the controllers and views.

Controllers:

```
req.controller  # stores current controller
req.action # stores current action
req.executeController 'controller', 'action', cb # Executes another controller and overwrites the next function with the cb
```

Views:

```
controller # stores current controller
action # stores current action
getUrl 'controller', 'action', defaultParams, queryParams # returns a url corresponding to the controller/action specified
getUrl 'action', defaultParams, queryParams # same as above but using the current controller
```

### Options

The default options are:

```
# If the controller/action is not defined do we throw an exception?
strict: true  

# Overwrite the render/partial calls to use the 'controller/action' breakdown of the views
overwriteRender: true

# Log when the controllers are loaded and called
log: false

# Set the root folder for the controllers
root: app.set('controllers') || process.cwd() + '/controllers'

# Set the share folder in the views, all render/partial calls will fall back to this folder
sharedFolder: 'shared'
```

### License

©2012 Felix Jorkowski and available under the [MIT license](http://www.opensource.org/licenses/mit-license.php):

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.