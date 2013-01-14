#= require jquery-1.8.2
#= require chosen/chosen/chosen.jquery.min
$ = jQuery
$ ->

  curTagList = () ->
    tags = []
    $("#postTagsSelect option[selected]").each (index, tag) ->
      tags.push $(tag).val()
    tags

  updateTagsValue = () ->
    tags = curTagList()
    $("#postTagsHidden").val(tags)
    
  arrayRemoveByIndex = (arr, index) ->
    ret = []
    for i in [0..index - 1] by 1
      ret.push arr[i]
    for i in [index + 1..arr.length - 1] by 1
      ret.push arr[i]
    ret

  $("#postTagsSelect").chosen().change () ->
    oper = arguments[1]
    tags = curTagList()
    if oper.hasOwnProperty 'selected'
      tags.push oper.selected
    else if oper.hasOwnProperty 'deselected'
      index = tags.indexOf(oper.deselected)
      if index >= 0 and index < tags.length
        tags = arrayRemoveByIndex(tags, index)
    console.log tags
    repaintSelect(tags)

  origAllTags = () ->
    $("#postTagsHidden").data("alltags")

  dedupMerge = (a0, a1) ->
    tmp = (a0.concat a1).sort()
    ret = []
    for i in [0..tmp.length - 1]
      appeared = () ->
        for j in [i + 1..tmp.length - 1] by 1
          if tmp[i] is tmp[j]
            return true
        return false
      ret.push tmp[i] if not appeared()
    ret

  rechosenPostTagSelect = () ->
    $("#postTagsSelect").chosen()

  repaintSelect = (selectedTags) ->
    curAllTags = dedupMerge(selectedTags, origAllTags())
    options = ("<option value=#{tag} #{if tag in selectedTags then 'selected' else ''}>#{tag}</option>" for tag in curAllTags).join ''
    $("#postTagsSelect option").remove()
    $("#postTagsSelect").append(options)
    $("#postTagsSelect").removeClass("chzn-done")
    $("#postTagsSelect_chzn").remove()
    rechosenPostTagSelect()
    updateTagsValue()

  $("#addTag").on "click", () ->
    tagList = curTagList()
    tagList.push $("#postTagsAdd").val()
    repaintSelect(tagList)
