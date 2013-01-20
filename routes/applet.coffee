'use continuation'
config = require '../config'
helper = require '../lib/helper'

$ = require 'jquery'

reversi = exports.reversi = (req, res, next) ->
  ret = {}
  next null, ret

applets =
  reversi: reversi

exports.index = (req, res, next) ->
  applet = req.params[0]
  appletList = Object.keys applets
  resources = {}
  if applet in appletList
    applets[applet] req, res, obtain resources
  helper.defaultResponseParam obtain(defaultResources)
  resources = $.extend({}, resources, defaultResources, {
    title: applet + " - " + config.site.title
  })
  res.render "applet/#{req.params[0]}", resources
