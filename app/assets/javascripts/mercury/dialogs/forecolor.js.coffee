@Mercury.dialogHandlers.foreColor = ->
  @element.find('.picker, .last-picked').on 'click', (event) =>
    color = jQuery(event.target).css('background-color').toHex()
    @element.find('.last-picked').css({background: color})
    @button.css({backgroundColor: color})
    Mercury.trigger('action', {action: 'foreColor', value: color})
