Plugin = Mercury.registerPlugin 'color',
  description: 'Provides interface for selecting colors.'
  version: '1.0.0'

  prependButtonAction: 'insert'

  actions:
    color: 'insert'
    html: 'insert'
    text: 'insert'

  config:
    colors: 'ffffff 000000 eeece1 1f497d 4f81bd c0504d 9bbb59 8064a2 4bacc6 f79646 ffff00 f2f2f2 7f7f7f ddd9c3 c6d9f0 ' +
            'dbe5f1 f2dcdb ebf1dd e5e0ec dbeef3 fdeada fff2ca d8d8d8 595959 c4bd97 8db3e2 b8cce4 e5b9b7 d7e3bc ccc1d9 ' +
            'b7dde8 fbd5b5 ffe694 bfbfbf 3f3f3f 938953 548dd4 95b3d7 d99694 c3d69b b2a2c7 b7dde8 fac08f f2c314 a5a5a5 ' +
            '262626 494429 17365d 366092 953734 76923c 5f497a 92cddc e36c09 c09100 7f7f7f 0c0c0c 1d1b10 0f243e 244061 ' +
            '632423 4f6128 3f3151 31859b 974806 7f6000'

  registerButton: ->
    @button.set(type: 'color', subview: @bindTo(new Plugin.Palette()))


  bindTo: (view) ->
    view.on 'color:picked', (value) =>
      @triggerAction(value)
      @button.css(color: "##{value}")


  regionContext: ->
    @button.css(color: color) if color = @region.hasContext(@context, true) || @region.hasContext('color', true)


  insert: (name, value) ->
    Mercury.trigger('action', name, "##{value}")


class Plugin.Palette extends Mercury.ToolbarPalette
  template:  'color'
  className: 'mercury-color-palette'
  events:    'click li': (e) ->
    value = $(e.target).data('value')
    @$('.last-picked').data(value: value).css(background: "##{value}")
    @trigger('color:picked', value)


JST['/mercury/templates/color'] = ->
  """
  <ul>
    #{("<li data-value='#{color}' style='background:##{color}'></li>" for color in Plugin.config('colors').split(' ')).join('')}
    <li class="last-picked">Last Color Picked</li>
    <li class="no-color">None - Default Color</li>  
  </ul>
  """
