#= require mercury/core/view
#= require mercury/models/page
#= require mercury/views/modules/draggable
#= require mercury/views/modules/interface_maskable
#= require mercury/views/modules/interface_shadowed

class Mercury.BaseInterface extends Mercury.View
  @include Mercury.Module
  @include Mercury.View.Modules.Draggable

  @logPrefix: 'Mercury.BaseInterface:'
  @tag: 'mercury'

  @events:
    'mercury:save': 'save'
    'mercury:focus': 'focusActiveRegion'
    'mercury:blur': 'blurActiveRegion'
    'mercury:resize': 'onResize'
    'mercury:action': 'focusActiveRegion'
    'mercury:region:focus': 'onRegionFocus'
    'mercury:region:release': 'onRegionRelease'
    'mercury:reinitialize': 'reinitialize'
    'mercury:interface:toggle': 'toggle'
    'mousedown .mercury-drag-handle': 'startDrag'

  constructor: ->
    if parent != window && parent.Mercury
      @log(@t('Has already been defined in parent frame'))
      return

    @extend Mercury.View.Modules.InterfaceMaskable if @config('interface:maskable')
    @extend Mercury.View.Modules.InterfaceShadowed if @config('interface:shadowed')

    Mercury.interface ||= @
    @floating ||= @config('interface:floating')
    @visible = true

    super

    @page = new Mercury.Model.Page()
    @regions ||= []
    $(window).on('beforeunload', @onUnload)
    $(window).on('resize', @onResize)

    @initialize()
    @buildInterface()
    @bindDefaultEvents()
    Mercury.trigger('initialized')


  build: ->
    @el = document.createElement(@tag || @constructor.tag) unless @el
    @$el = $(@el)
    @attr(@attributes)
    @append('<div class="mercury-drag-handle"/>') if @config('interface:floatDrag')


  init: ->
    $('body').before(@$el)


  initialize: ->
    @addAllRegions()
    @bindDocumentEvents()


  load: (json) ->
    @findRegionByName(name)?.load(data) for name, data of json.contents || json


  findRegionByName: (name) ->
    for region in @regions || []
      return region if region.name == name
    null


  addAllRegions: ->
    @addRegion(el) for el in @regionElements()
    @region ||= @regions[0]


  bindDocumentEvents: ->
    $('body', @document).on('mousedown', @hideDialogs) unless @config('interface:mask')


  buildInterface: ->
    @addClasses()
    for subview in ['toolbar', 'statusbar']
      continue unless klass = @config("interface:#{subview}")
      @[subview] = @appendView(new Mercury[klass]())
    unless @config('interface:enabled')
      @previewMode = true
      @hide()
      Mercury.trigger('mode', 'preview')
    @focusDefaultRegion()
    @onResize()
    @delay(500, -> @removeClass('loading'))


  addClasses: ->
    @addClass(@className)
    @addClass('loading')
    @addClass(@config('interface:style') || 'standard')
    @addClass('mercury-floating') if @floating
    @addClass("locale-#{Mercury.I18n.detectLocale().join('-').toLowerCase()}")


  bindDefaultEvents: ->
    @delegateEvents
      'mercury:mode': (mode) -> @setMode(mode)
      'mercury:action': -> @focusActiveRegion()


  reinitialize: ->
    @addAllRegions()
    @focusDefaultRegion()


  setInterface: (type) ->
    if type == 'float'
      type = 'mercury-floating'
      @floating = true
      if $('body').hasClass('mercury-transitions')
        $('body').removeClass('mercury-transitions').addClass('mercury-no-transitions')
    @addClass(type)
    @position()
    @onResize()


  removeInterface: (type) ->
    if type == 'float'
      type = 'mercury-floating'
      @floating = false
      @placed = false
      @css(position: '')
    if $('body').hasClass('mercury-no-transitions')
      $('body').removeClass('mercury-no-transitions').addClass('mercury-transitions')
    @removeClass(type)
    @position()
    @onResize()


  focusDefaultRegion: ->
    @delay(100, @focusActiveRegion)


  regionElements: ->
    $("[#{@config('regions:attribute')}]", @document)


  addRegion: (el) ->
    return if $(el).data('region')
    region = Mercury.Region.create(el)
    @regions.push(region)


  focusActiveRegion: ->
    @region?.focus(false, true)


  blurActiveRegion: ->
    @region?.blur()


  setMode: (mode) ->
    @["#{mode}Mode"] = !@["#{mode}Mode"]
    @focusActiveRegion()
    @delay(50, -> @position()) if mode == 'preview'


  toggle: ->
    if @visible then @hide() else @show()


  show: ->
    return if @visible
    Mercury.trigger('interface:show')
    Mercury.trigger('mode', 'preview') if @previewMode
    @$el.show()
    @visible = true
    @onResize()
    @$el.stop().animate({opacity: 1}, duration: 250)
    @position()


  hide: ->
    return unless @visible
    @hiding = true
    Mercury.trigger('interface:hide')
    Mercury.trigger('mode', 'preview') unless @previewMode
    $('body').css(position: 'relative', top: 0)
    @visible = false
    @position()
    @$el.stop().animate {opacity: 0}, duration: 250, complete: =>
      @$el.hide()
      @hiding = false


  dimensions: ->
    if @floating
      toolbarHeight = 0
      statusbarHeight = 0
    else
      toolbarHeight = @toolbar?.height()
      statusbarHeight = @statusbar?.height()
    top: toolbarHeight
    left: 0
    right: 0
    bottom: statusbarHeight
    width: $(window).width()
    height: $(window).height() - toolbarHeight - statusbarHeight


  hasChanges: ->
    (return true if region.hasChanges()) for region in @regions
    false


  hideDialogs: =>
    Mercury.trigger('dialogs:hide')


  release: ->
    $(window).off('resize', @resize)
    $('body').css(position: '', top: '')
    $('body', @document).off('mousedown', @hideDialogs)
    @regions.shift().release() while @regions.length
    super


  serialize: ->
    data = {}
    for region in @regions
      data[region.name] = region.toJSON(true)
    data


  save: ->
    @page.set(content: @serialize(), location: location.pathname)
    @page.on('error', (xhr, options) => alert(@t('Unable to save to the url: %s', options.url)))
    @page.save().always = => @delay(250, -> Mercury.trigger('save:complete'))


  heightForWidth: (width) ->
    oldWidth = @$el.outerWidth()
    @css(width: width, visibility: 'hidden', height: 'auto')
    height = @$el.outerHeight()
    @css(width: oldWidth, visibility: 'visible')
    return height


  position: (animate = false) ->
    return unless @floating
    return unless @region
    return if @placed
    return if @hiding
    @addClass('mercury-no-animation')
    pos = @positionForRegion()
    @width = width = Math.max(@config('interface:floatWidth') || @region.$el.width(), 300)
    height = @heightForWidth(width)
    left = pos.left
    viewport = $(window).width()
    left -= left + width - viewport if left + width > viewport
    callback = ->
      @removeClass('mercury-no-animation') if animate
      # Make sure the floating toolbar is always visible. 
      if (@region.$el.offset().top - height) < 0
        @css(top: pos.top + @region.$el.height(), left: left, width: width)
      else
        @css(top: pos.top - height, left: left, width: width)
    if animate
      @delay(20, callback)
      @delay(300, -> Mercury.trigger('interface:resize', @dimensions()))
    else
      callback.call(@)


  positionForRegion: ->
    @region.$el.offset()


  onDragStart: ->
    Mercury.trigger('dialogs:hide')


  setPositionOnDrag: (x, y) ->
    unless @placed
      @placed = true
      @startPosition.x += window.scrollX
      @startPosition.y += window.scrollY
      x -= window.scrollX
      y -= window.scrollY
      @lastPosition = {x: x, y: y}
      @css(position: 'fixed', top: y, left: x)
    x = 0 if x < 0
    y = 0 if y < 0
    x = @viewportSize.width - 50 if x > @viewportSize.width - 50
    y = @viewportSize.height - 50 if y > @viewportSize.height - 50
    @css(top: y, left: x)
    @onResize() unless @width


  onRegionFocus: (@region) ->
    @delay(50, -> if @floating then @position(true) else @onResize())


  onRegionRelease: (region) ->
    @region = @regions[0] if region == @region
    index = @regions.indexOf(region)
    @regions.splice(index, 1) if index > -1


  onResize: =>
    dimensions = @dimensions()
    $('body').css(position: 'relative', top: dimensions.top)
    return unless @visible
    Mercury.trigger('interface:resize', dimensions)
    @position()
    dimensions


  onUnload: =>
    return if @config('interface:silent') || !@hasChanges()
    return @t('You have unsaved changes.  Are you sure you want to leave without saving them first?')

