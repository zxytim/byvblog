#= require jquery-1.8.2
#= require chosen/chosen/chosen.jquery.min
$ = jQuery
$ ->
  $("#postTagsSelect").chosen()
  $("#addTag").on "click", () ->
    tag = $("#postTagsAdd").val()
    $("#postTagsSelect").append "<option value=#{tag} selected>#{tag}</option>"
    $("#postTagsSelect_chzn").remove()
    $("#postTagsSelect").removeClass("chzn-done")
    $("#postTagsSelect").chosen()
