post = require('./post')
feed = require('./feed')
admin = require('./admin')
test = require './test'
applet = require './applet'

routes = [
  {
    path: /^\/((.{2,3})|)$/
    GET: post.displayPostList
  }, {
    path: /^\/((.{2,3})\/|)(page\/(\d{1,4})|)$/
    GET: post.displayPostList
  }, {
    path: /^\/((.{2,3})\/|)feed$/
    GET: feed.feed
  }, {
    path: /^\/((.{2,3})\/|)blog\/tag$/
    GET: post.tagList
  }, {
    path: /^\/((.{2,3})\/|)blog\/tag\/(.+?)(\/page\/(\d{1,4})|)$/
    GET: post.displayTag
  }, {
    path: /^\/((.{2,3})\/|)blog\/archive\/(\d{4})\/(\d{1,2})(\/page\/(\d{1,4})|)$/
    GET: post.archive
  }, {
    path: /^\/admin$/
    GET: admin.index
  }, {
    path: /^\/admin\/all-tags$/
    POST: admin.allTags
  }, {
    path: /^\/admin\/login$/
    GET: admin.loginPage
    POST: admin.login
  }, {
    path: /^\/admin\/logout$/
    GET: admin.logout
  }, {
    path: /^\/admin\/new$/
    GET: admin.newPostPage
    POST: admin.newPost
  }, {
    path: /^\/admin\/edit\/(.+)$/
    GET: admin.editPostPage
    POST: admin.editPost
  }, {
    path: /^\/test$/
    GET: test.index
  }, {
    path: /^\/((.{2,3})\/|)(.+?)(\/|)$/
    GET: post.displayPost
  }, {
    path: /^\/(\%.*)/
    GET: post.displayPost
  }, {
    path: /^\/applet\/(.+)/
    GET: applet.index
  }
]

module.exports = (app) ->
  for route in routes
    for method, handler of route
      if method isnt 'path'
        app[method.toLowerCase()] route.path, handler
