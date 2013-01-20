'use continuation'
config = require '../config'
Post = require '../models/post'
exports.defaultResponseParam = (next) ->
  Post.getPopularPosts config.options.popularPosts, obtain popularPosts
  Post.getArchive obtain archives
  Post.getRecentPosts config.options.recentPosts, obtain recentPosts
  next null, {
    popularPosts: popularPosts
    archives: archives
    recentPosts: recentPosts
  }
