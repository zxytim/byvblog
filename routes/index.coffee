'use continuation'
Post = require '../models/post'
admin = require './admin'

module.exports = (app) ->
  app.get '/', (req, res, next) ->
    Post.find({private:false, list:true}).limit(10).sort('-postTime').exec obtain posts
    Post.render posts
    res.render 'postslist',
      posts: posts
    
  admin app
  
  app.get /^\/(.+)$/, (req, res, next) ->
    postId = req.params[0]
    Post.findOne {id: postId}, obtain post
    if post is null
      return next()
    
    if post.private and not req.session.user?
      #Forbid guest viewing private posts
      return next()
    
    if not req.session.user?
      #Inrecrese click count
      post.clicks += 1
      post.save obtain()
    
    post.render()
    res.render 'post',
      post: post
