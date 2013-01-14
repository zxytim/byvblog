'use continuation'
User = require '../models/user'
Post = require '../models/post'

exports.index = (req, res, next) ->
  if not req.session.user?
    return res.redirect '/admin/login'
  Post.find().sort('-postTime').exec obtain posts
  res.render 'admin/postslist',
    posts: posts

exports.loginPage = (req, res, next) ->
  if req.session.user?
    return res.redirect '/admin'
  res.render 'admin/login'

exports.login = (req, res, next) ->
  User.authenticate req.body.user, cont(err, user)
  if err
    req.session.error = err.toString()
    res.render 'admin/login'
  else
    req.session.user = user
    res.redirect '/admin'

exports.logout = (req, res, next) ->
  req.session.user = undefined
  res.redirect '/admin'

exports.newPostPage = (req, res, next) ->
  console.log "newPostPage"
  if not req.session.user?
    return res.redirect '/admin/login'
  Post.allTags obtain(allTags)
  res.render 'admin/editpost',
    post: null
    allTags: allTags

exports.newPost = (req, res, next) ->
  if not req.session.user?
    return res.redirect '/admin/login'
  author = req.session.user.name
  Post.newPost req.body.post, author, cont(err, post)
  if err
    req.session.error = err.toString()
    return res.redirect '/admin/new'
  req.session.success = 'Post saved'
  res.redirect '/admin/edit/' + post.guid

exports.editPostPage = (req, res, next) ->
  console.log "editPostPage"
  if not req.session.user?
    return res.redirect '/admin/login'
  postGuid = req.params[0]
  Post.findOne {guid: postGuid}, cont(err, post)
  return next err if err
  return next new Error('Invalid post id') if not post?

  #Organize by languages
  post = post.toObject()
  post.contents ?= []
  languages = {}
  for contents in post.contents
    languages[contents.language] = contents
  post.contents = languages
    
  Post.allTags obtain(allTags)
  res.render 'admin/editpost',
    post: post
    allTags: allTags
  
exports.editPost = (req, res, next) ->
  console.log "editPost"
  if not req.session.user?
    return res.redirect '/admin/login'
  postGuid = req.params[0]
  try
    Post.findOne {guid: postGuid}, obtain(post)
    throw new Error('Invalid post id') if not post?
    post.modify req.body.post, obtain(savedPost)
    req.session.success = 'Post saved'
    res.redirect '/admin/edit/' + savedPost.guid
  catch err
    req.session.error = err.toString()
    Post.allTags obtain allTags
    res.render 'admin/editpost',
      post: post
      allTags: allTags

exports.allTags = (req, res, next) ->
  Post.allTags obtain tags
  res.json tags
